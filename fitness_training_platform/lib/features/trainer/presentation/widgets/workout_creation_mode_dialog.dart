/// @file workout_creation_mode_dialog.dart
/// @brief Dialog for selecting workout creation mode in the trainer dashboard
/// @details This file contains the WorkoutCreationModeDialog widget that allows trainers
/// to choose between two workout creation approaches: building from scratch or using a
/// pre-built workout template. The dialog loads available templates from the TemplateService
/// and provides an interactive interface for template selection and mode confirmation.
/// The selected mode and optional template are returned to the parent widget via a callback.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../shared/services/template_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @enum WorkoutCreationMode
/// @brief Enumerates the two available modes for creating new workouts
/// @details Used to distinguish between creating a workout from scratch with manual
/// exercise selection versus creating from a pre-built template.
enum WorkoutCreationMode {
  /// @brief Build a custom workout by manually selecting exercises
  fromScratch,

  /// @brief Create a workout based on a pre-defined template
  fromTemplate,
}

/// @class WorkoutCreationModeDialog
/// @brief Stateful dialog widget for selecting and confirming workout creation mode
/// @details Presents a modal dialog with two option cards: "Create from Scratch" and
/// "Use Workout Template". The template option displays a list of available templates
/// (both personal and public) that trainers can select from. The dialog loads templates
/// asynchronously from TemplateService and handles loading/empty states appropriately.
/// When a mode is selected, the onModeSelected callback is invoked with the selected
/// mode and optional template, then the dialog is automatically closed.
class WorkoutCreationModeDialog extends StatefulWidget {
  /// @brief Callback function invoked when a creation mode is selected
  /// @details The callback receives the selected WorkoutCreationMode and an optional
  /// WorkoutTemplate if fromTemplate mode is chosen. Called before the dialog closes.
  final Function(WorkoutCreationMode mode, {WorkoutTemplate? selectedTemplate}) onModeSelected;

  /// @brief Constructor for WorkoutCreationModeDialog
  /// @details Initializes the dialog with a required onModeSelected callback that will
  /// be invoked when the user selects a creation mode.
  /// @param onModeSelected Callback function invoked upon mode selection with mode and
  ///                       optional selectedTemplate parameter
  const WorkoutCreationModeDialog({
    super.key,
    required this.onModeSelected,
  });

  @override
  State<WorkoutCreationModeDialog> createState() => _WorkoutCreationModeDialogState();
}

/// @class _WorkoutCreationModeDialogState
/// @brief State class for WorkoutCreationModeDialog managing template loading and selection
/// @details Handles the stateful logic for loading available workout templates from both
/// personal and public sources, managing template selection state, and rendering the
/// appropriate UI based on loading, empty, and populated states. Uses TemplateService
/// via dependency injection and AuthProvider to determine the current trainer's identity.
class _WorkoutCreationModeDialogState extends State<WorkoutCreationModeDialog> {
  /// @brief Service instance for accessing workout templates
  /// @details Retrieved from the service locator (dependency injection container).
  /// Provides methods to fetch personal and public workout templates.
  final TemplateService _templateService = sl.get<TemplateService>();

  /// @brief List of available workout templates for selection
  /// @details Contains templates from both the current trainer and public library,
  /// with duplicates removed. Populated by _loadTemplates() during initialization.
  List<WorkoutTemplate> _availableTemplates = [];

  /// @brief Currently selected template by the user
  /// @details Null if no template is selected. Updated when user taps a template
  /// in the list. Used to enable/disable the "Use Selected Template" button.
  WorkoutTemplate? _selectedTemplate;

  /// @brief Loading state indicator for asynchronous template fetching
  /// @details True while templates are being loaded from TemplateService, false
  /// once loading is complete. Used to display loading spinner or template list.
  bool _isLoading = true;

  /// @brief Initializes the state and begins loading templates
  /// @details Called when the State object is inserted into the widget tree.
  /// Immediately invokes _loadTemplates() to fetch available templates.
  /// @return void
  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  /// @brief Asynchronously loads available templates from TemplateService
  /// @details Retrieves both personal templates for the current trainer and public
  /// templates accessible to all trainers. Merges the lists and removes any
  /// duplicate template IDs. Updates the UI with the loaded templates via setState().
  /// Gracefully handles exceptions by logging and setting isLoading to false,
  /// allowing the UI to display an error state or empty template list.
  /// @return Future<void> Completes when templates are loaded and state is updated
  Future<void> _loadTemplates() async {
    // Get current authenticated trainer from AuthProvider
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      try {
        // Fetch personal templates created by this trainer
        final personalTemplates = await _templateService.getTemplatesForTrainer(currentUser.id);

        // Fetch public templates available to all trainers
        final publicTemplates = await _templateService.getPublicTemplates();

        // Combine both template sources while removing duplicates by ID
        final allTemplates = <WorkoutTemplate>[];
        allTemplates.addAll(personalTemplates);
        for (final template in publicTemplates) {
          if (!allTemplates.any((t) => t.id == template.id)) {
            allTemplates.add(template);
          }
        }

        // Update UI with loaded templates and clear loading indicator
        setState(() {
          _availableTemplates = allTemplates;
          _isLoading = false;
        });
      } catch (e) {
        // Log error and clear loading indicator to show empty state
        print('Error loading templates: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// @brief Builds the complete UI for the workout creation mode selection dialog
  /// @details Renders a dialog with a header containing title and close button, followed
  /// by instructions and two main option cards. The "From Scratch" card is always available.
  /// The "Use Template" card conditionally renders a loading spinner, empty state message,
  /// or a scrollable list of available templates with selection capability. The "Use Selected
  /// Template" button is only enabled when a template is selected.
  /// @return Widget The complete dialog widget hierarchy
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header with title and close button
            Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  lang.translate('create_new_workout'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              lang.translate('choose_workout_creation'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // ========== FROM SCRATCH OPTION ==========
            // Card allowing trainer to build custom workout from ground up
            Card(
              child: InkWell(
                onTap: () {
                  // Invoke callback with fromScratch mode and close dialog
                  widget.onModeSelected(WorkoutCreationMode.fromScratch);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Green icon container for visual appeal
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                      ),
                      const SizedBox(width: 16),
                      // Title and description text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.translate('create_from_scratch'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.translate('build_custom_workout'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Arrow icon indicating navigating forward
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ========== FROM TEMPLATE OPTION ==========
            // Card allowing trainer to build workout from pre-made template
            Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Template option header with icon
                    Row(
                      children: [
                        // Blue icon container for visual appeal
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.library_books, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        // Title and description text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('use_workout_template'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lang.translate('start_with_prebuilt'),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ========== LOADING STATE ==========
                    // Show spinner while fetching templates from service
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ]
                    // ========== EMPTY STATE ==========
                    // Show informational message when no templates are available
                    else if (_availableTemplates.isEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang.translate('no_templates_available'),
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // ========== POPULATED STATE ==========
                    // Show scrollable list of templates when available
                    else ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Header with template count and action button
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Template (${_availableTemplates.length} available)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    // Button enabled only when template is selected
                                    child: ElevatedButton(
                                      onPressed: _selectedTemplate != null ? () {
                                        // Invoke callback with fromTemplate mode and selected template
                                        widget.onModeSelected(
                                          WorkoutCreationMode.fromTemplate,
                                          selectedTemplate: _selectedTemplate,
                                        );
                                        Navigator.pop(context);
                                      } : null,
                                      child: Text(lang.translate('use_selected_template')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Scrollable list of templates
                            Expanded(
                              child: ListView.builder(
                                itemCount: _availableTemplates.length,
                                itemBuilder: (context, index) {
                                  final template = _availableTemplates[index];
                                  final isSelected = _selectedTemplate?.id == template.id;
                                  return ListTile(
                                    selected: isSelected,
                                    // Circle avatar showing difficulty level (B, I, A)
                                    leading: CircleAvatar(
                                      backgroundColor: _getDifficultyColor(template.difficulty),
                                      child: Text(
                                        template.difficulty[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(template.name),
                                    // Subtitle showing description and metadata
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(template.description),
                                        Text('${lang.translate('exercises_count', params: {'count': '${template.exercises.length}'})} • ${template.estimatedDuration} min'),
                                      ],
                                    ),
                                    // Show checkmark when template is selected
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                                    // Toggle selection on tap
                                    onTap: () {
                                      setState(() {
                                        // Deselect if already selected, otherwise select
                                        _selectedTemplate = isSelected ? null : template;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Cancel button for closing dialog without selection
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.translate('cancel')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// @brief Maps difficulty level strings to corresponding material colors
  /// @details Helper method used to assign consistent color coding to workout
  /// difficulties throughout the UI. Displays these colors in the difficulty
  /// avatar badges: beginner (green), intermediate (orange), advanced (red).
  /// @param difficulty String value representing workout difficulty level
  /// @return Color The Material color corresponding to the difficulty level
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        // Fallback to grey for unrecognized difficulty levels
        return Colors.grey;
    }
  }
}