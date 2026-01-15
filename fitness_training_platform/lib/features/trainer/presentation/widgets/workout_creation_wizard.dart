/// @file workout_creation_wizard.dart
/// @brief Multi-step wizard for creating and editing workouts with exercises
/// @details This file contains a comprehensive multi-step workflow for trainers to
/// create and edit training sessions. The wizard guides trainers through four distinct
/// steps: (1) basic workout information, (2) trainee selection, (3) exercise selection
/// and configuration, and (4) review and creation. It supports creating single workouts,
/// recurring workouts, and workouts from pre-defined templates. Exercise selection is
/// highly interactive, featuring library browsing, custom exercise creation, exercise
/// configuration with sets/reps/weight, and inline editing with drag-and-drop reordering.
/// All user input is validated before proceeding to the next step, and comprehensive
/// recurrence calculations ensure accurate multi-trainee multi-occurrence scheduling.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/services/exercise_library_service.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../shared/widgets/common/custom_button.dart';
import '../../../../shared/widgets/common/custom_text_field.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/services/localization_service.dart';
import 'custom_exercise_dialog.dart';

/// @class WorkoutCreationWizard
/// @brief Multi-step stateful widget for creating or editing training workouts
/// @details This is the root widget that orchestrates the entire workout creation
/// and editing workflow. It provides a 4-step wizard interface wrapped in a Dialog,
/// guiding trainers through defining workout parameters, selecting trainees, choosing
/// exercises, and reviewing the complete configuration before creation. Supports both
/// creating new workouts from scratch and editing existing workouts. Can also be
/// initialized with a WorkoutTemplate to quickly create workouts from predefined programs.
///
/// The widget maintains all state in its State class and uses PageView for smooth
/// transitions between wizard steps. Exercise selection is fully interactive with
/// library browsing, custom exercise creation, and inline editing capabilities.
class WorkoutCreationWizard extends StatefulWidget {
  /// @brief List of available trainees for assignment
  /// @details Contains all trainee users that can be selected for this workout
  final List<UserModel> trainees;

  /// @brief Callback invoked when a workout is successfully created or updated
  /// @details The callback receives the newly created or updated TrainingModel.
  /// For recurring workouts, this may be called multiple times (once per instance)
  /// during batch creation. Called before dialog is closed.
  final Function(TrainingModel) onWorkoutCreated;

  /// @brief Optional existing workout for edit mode
  /// @details If provided, the wizard initializes with this workout's data and
  /// operates in edit mode. In edit mode, only the single existing workout is updated
  /// rather than creating new instances. Null indicates new workout creation mode.
  final TrainingModel? initialWorkout;

  /// @brief Optional template to initialize workout from
  /// @details If provided, the wizard pre-populates workout details and exercises
  /// from the template. Ignored if initialWorkout is provided (edit mode takes precedence).
  /// Used for "create from template" workflows.
  final WorkoutTemplate? initialTemplate;

  /// @brief Constructor for WorkoutCreationWizard
  /// @details Initializes the wizard with required trainees list, callback, and
  /// optional initial data. Either initialWorkout (edit) or initialTemplate (from template)
  /// may be provided, but not both - initialWorkout takes precedence if both exist.
  /// @param super.key Flutter widget key for lifecycle management
  /// @param trainees Required list of available trainee users for assignment
  /// @param onWorkoutCreated Required callback invoked after successful creation/update
  /// @param initialWorkout Optional existing workout for editing (null = new creation)
  /// @param initialTemplate Optional template to pre-populate workout (null = blank form)
  const WorkoutCreationWizard({
    super.key,
    required this.trainees,
    required this.onWorkoutCreated,
    this.initialWorkout,
    this.initialTemplate,
  });

  @override
  State<WorkoutCreationWizard> createState() => _WorkoutCreationWizardState();
}

/// @class _WorkoutCreationWizardState
/// @brief State manager for the workout creation wizard
/// @details This class manages all state for the 4-step workout creation wizard.
/// It maintains page navigation, form field controllers, and all workout parameters
/// (basic info, trainee selection, exercise list, recurrence settings). Validation
/// logic prevents progression to next steps until required fields are complete.
/// The class orchestrates complex workflows including exercise library browsing,
/// custom exercise creation, recurrence scheduling calculations, and batch creation
/// of recurring workouts across multiple trainees.
///
/// State variables are organized into logical groups:
/// - Navigation: _currentPage, _pageController
/// - Basic Info: _nameController, _descriptionController, _difficulty, etc.
/// - Trainees: _selectedTrainees
/// - Exercises: _selectedExercises
/// - Recurrence: _recurrenceFrequency, _recurrenceCount, _recurrenceDayCount
class _WorkoutCreationWizardState extends State<WorkoutCreationWizard> {
  /// @brief Controller for page transitions in the wizard
  /// @details Manages the PageView that displays the four wizard steps.
  /// Used for programmatic navigation (previous/next page) with smooth animations.
  final PageController _pageController = PageController();

  /// @brief Service for accessing predefined exercise templates
  /// @details Provides methods to search and retrieve exercise templates from the library.
  /// Used in the exercise selection step to browse available exercises.
  final ExerciseLibraryService _exerciseLibrary = ExerciseLibraryService();

  /// @brief Current step index in the wizard (0-3)
  /// @details Tracks which page is currently displayed: 0=Basic Info, 1=Trainee Selection,
  /// 2=Exercise Selection, 3=Review & Create. Updated when user navigates between pages.
  int _currentPage = 0;

  /// @brief Total number of steps in the wizard workflow
  /// @details Fixed value of 4 representing the complete workflow:
  /// Step 1: Basic Information, Step 2: Trainee Selection, Step 3: Exercise Selection, Step 4: Review
  final int _totalPages = 4;

  // ===== STEP 1: BASIC INFORMATION FIELDS =====

  /// @brief Text controller for workout name/title
  /// @details Input field for trainer to enter the workout's display name (e.g., "Upper Body Strength")
  final _nameController = TextEditingController();

  /// @brief Text controller for workout description
  /// @details Input field for trainer to enter a detailed description of the workout's purpose and goals
  final _descriptionController = TextEditingController();

  /// @brief Text controller for additional notes and instructions
  /// @details Optional field for trainer to add special instructions, form cues, or other notes
  /// to guide the trainee during workout execution
  final _notesController = TextEditingController();

  // ===== STEP 2: TRAINEE SELECTION FIELDS =====

  /// @brief List of trainees selected for this workout
  /// @details Tracks which trainee(s) this workout will be assigned to. Multiple trainees
  /// can be selected, which will result in creating separate workout instances for each
  /// (especially important for recurring workouts). Updated when user checks/unchecks
  /// trainee selection checkboxes.
  List<UserModel> _selectedTrainees = [];

  /// @brief Scheduled date and time for the workout
  /// @details First occurrence date for this workout. Subsequent occurrences in recurring
  /// workouts are calculated by adding recurrence intervals. Defaults to tomorrow.
  /// User selects via date picker in Step 1.
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));

  /// @brief Difficulty level of the workout
  /// @details Must be one of: 'beginner', 'intermediate', 'advanced'.
  /// Default is 'beginner'. Selected via dropdown in Step 1.
  String _difficulty = 'beginner';

  /// @brief Estimated duration of the workout in minutes
  /// @details Range: 15-120 minutes. User adjusts via slider in Step 1.
  /// Default is 30 minutes. Used for scheduling and workout planning.
  int _estimatedDuration = 30;

  // ===== STEP 3: EXERCISE SELECTION FIELDS =====

  /// @brief Category/type of the overall workout
  /// @details Must be one of: 'strength', 'cardio', 'flexibility', 'sports', 'rehabilitation'
  /// Default is 'strength'. Selected via dropdown in Step 1.
  String _category = 'strength';

  /// @brief List of exercises selected for this workout
  /// @details Contains ExerciseModel instances with complete configuration (sets, reps, weight).
  /// User adds/removes/reorders exercises in Step 3. Can be reordered via drag-and-drop.
  /// Used in Step 4 for review and for creating TrainingModel. Must have at least 1 exercise.
  List<ExerciseModel> _selectedExercises = [];

  // ===== STEP 1: RECURRENCE CONFIGURATION FIELDS =====

  /// @brief Recurrence frequency for the workout
  /// @details Must be one of: 'None', 'Daily', 'Weekly', 'Monthly'.
  /// Determines how the workout repeats. Default is 'None' (single occurrence).
  /// Affects which recurrence count/day fields are visible in the UI.
  String _recurrenceFrequency = 'None';

  /// @brief Number of repetitions for weekly/monthly recurrence
  /// @details Only used when _recurrenceFrequency is 'Weekly' or 'Monthly'.
  /// Specifies how many weeks or months the workout repeats. Default is 1.
  /// Not used for 'Daily' or 'None' frequencies.
  int _recurrenceCount = 1;

  /// @brief Number of days for daily recurrence
  /// @details Only used when _recurrenceFrequency is 'Daily'.
  /// Specifies how many consecutive days the workout repeats (1-7). Default is 1.
  /// Not used for 'Weekly', 'Monthly', or 'None' frequencies.
  int _recurrenceDayCount = 1;

  /// @brief Initialize wizard state based on construction parameters
  /// @details This method populates form fields and selections based on whether
  /// the wizard is in edit mode, template mode, or new creation mode. Priority:
  /// 1. If initialWorkout provided: Load all fields from existing workout (edit mode)
  /// 2. Else if initialTemplate provided: Load template data and convert exercises
  /// 3. Else if single trainee: Auto-select the only available trainee
  /// The method performs a deep copy of exercises to allow safe editing without
  /// modifying the original workout data.
  /// @return void
  @override
  void initState() {
    super.initState();
    // Edit mode: load existing workout data
    if (widget.initialWorkout != null) {
      final w = widget.initialWorkout!;
      _nameController.text = w.name;
      _descriptionController.text = w.description;
      _notesController.text = w.notes ?? '';
      _scheduledDate = w.scheduledDate;
      _difficulty = w.difficulty;
      _estimatedDuration = w.estimatedDuration;
      _category = w.category;

      // Deep copy exercises to allow editing without modifying original
      _selectedExercises = w.exercises.map((e) => ExerciseModel(
        id: e.id,
        name: e.name,
        sets: e.sets,
        reps: e.reps,
        weight: e.weight,
        notes: e.notes,
        category: e.category,
        targetMuscle: e.targetMuscle,
        equipment: e.equipment,
        instructions: e.instructions,
        restTimeSeconds: e.restTimeSeconds,
      )).toList();

      // Find and select the trainee this workout is assigned to
      final trainee = widget.trainees.firstWhere(
        (t) => t.id == w.traineeId,
        orElse: () => widget.trainees.first,
      );
      _selectedTrainees = [trainee];
    }
    // Template mode: load template data and convert exercises
    else if (widget.initialTemplate != null) {
      final template = widget.initialTemplate!;
      _nameController.text = template.name;
      _descriptionController.text = template.description;
      _notesController.text = template.notes ?? '';
      _difficulty = template.difficulty;
      _estimatedDuration = template.estimatedDuration;
      _category = template.category;

      // Convert template exercises to workout exercises with default configuration
      _selectedExercises = template.exercises.map((templateExercise) =>
        templateExercise.toExerciseModel(
          sets: 3,                // Default 3 sets
          reps: 10,               // Default 10 reps
          restTimeSeconds: 60,    // Default 60 second rest
        )
      ).toList();
    }
    // New creation mode: auto-select single trainee if available
    else if (widget.trainees.length == 1) {
      _selectedTrainees = [widget.trainees.first];
    }
  }

  /// @brief Clean up resources before state is disposed
  /// @details Disposes all TextEditingControllers and PageController to release
  /// memory and prevent memory leaks. Called automatically when this state object
  /// is no longer needed.
  /// @return void
  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// @brief Build the complete wizard dialog UI
  /// @brief Constructs the main dialog layout with four components:
  /// (1) Header with title, current step indicator, and progress bar
  /// (2) PageView with four wizard step pages
  /// (3) Navigation buttons for Previous/Next/Create
  /// The PageView transitions between steps smoothly when navigated via buttons.
  /// @details The dialog takes up 90% of screen width and height, providing
  /// adequate space for complex forms and lists. The PageView tracks current page
  /// and updates _currentPage state for proper button display and validation.
  /// @param context Build context for accessing theme and media query data
  /// @return Widget A Dialog containing the complete wizard interface
  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Create a dialog sized to 90% of available screen space
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Step 1: Header with title, step indicator, and progress bar
            _buildHeader(),

            // Step 2: PageView with all four wizard pages
            Expanded(
              child: PageView(
                controller: _pageController,
                // Update current page when user swipes
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 0: Basic workout information
                  _buildBasicInfoPage(),
                  // Page 1: Trainee selection
                  _buildTraineeSelectionPage(),
                  // Page 2: Exercise selection and configuration
                  _buildExerciseSelectionPage(),
                  // Page 3: Review all details before creation
                  _buildReviewPage(),
                ],
              ),
            ),

            // Step 3: Navigation buttons (Previous/Next/Create)
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  /// @brief Build the dialog header with title, step indicator, and progress bar
  /// @details Constructs the top section of the dialog with:
  /// - Main title "Create Workout" (or "Edit Workout" if editing)
  /// - Close button to dismiss the dialog
  /// - Current step name (e.g., "Basic Information", "Add Exercises")
  /// - Linear progress indicator showing completion percentage (e.g., 25%, 50%, 75%, 100%)
  /// The header uses the primary theme color for a consistent visual style.
  /// Step titles track the current page via _currentPage index (0-3).
  /// @return Widget The header container with title, indicator text, and progress bar
  Widget _buildHeader() {
    final lang = context.watch<LanguageProvider>();

    // Step names displayed at top of each page
    final titles = [
      lang.translate('basic_information'),   // Step 0: Workout details
      lang.translate('select_trainees'),      // Step 1: Trainee assignment
      lang.translate('exercise_selection'),       // Step 2: Exercise selection
      lang.translate('review_create')      // Step 3: Final review
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Title row with close button
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.initialWorkout != null
                      ? lang.translate('edit_workout')
                      : lang.translate('create_workout_wizard'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              // Close button to dismiss the entire dialog
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Current step indicator text
          Text(
            titles[_currentPage],
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Progress bar showing completion percentage
          LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,  // 0.25, 0.50, 0.75, 1.0
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  /// @brief Build Step 0 (Basic Information) page of the wizard
  /// @details This is the first step where trainers enter basic workout information:
  /// - Workout name (required, validated before proceeding)
  /// - Workout description (required)
  /// - Category (dropdown: strength, cardio, flexibility, sports, rehabilitation)
  /// - Difficulty (dropdown: beginner, intermediate, advanced)
  /// - Estimated duration (slider: 15-120 minutes)
  /// - Scheduled date (date picker, defaults to tomorrow)
  /// - Recurrence settings (frequency dropdown with conditional day/count fields)
  ///
  /// Recurrence UI is context-aware: selecting 'Daily' shows day count (1-7),
  /// 'Weekly'/'Monthly' shows repetition count field, 'None' hides recurrence fields.
  /// All fields except recurrence are used in both edit and new creation modes.
  ///
  /// @return Widget A scrollable column containing all basic information form fields
  Widget _buildBasicInfoPage() {
    final lang = context.watch<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Required: Workout name/title
            CustomTextField(
              label: lang.translate('workout_name'),
              controller: _nameController,
              hint: lang.translate('enter_workout_name'),
            ),
            const SizedBox(height: 16),
            // Required: Workout description
            CustomTextField(
              label: lang.translate('description'),
              controller: _descriptionController,
              hint: lang.translate('workout_description'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              initialValue: _category,
              items: ['strength', 'cardio', 'flexibility', 'sports', 'rehabilitation']
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _category = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: lang.translate('difficulty_level'),
                border: const OutlineInputBorder(),
              ),
              initialValue: _difficulty,
              items: ['beginner', 'intermediate', 'advanced']
                  .map((difficulty) => DropdownMenuItem(
                        value: difficulty,
                        child: Text(lang.translate(difficulty)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.translate('estimated_duration')),
                Slider(
                  value: _estimatedDuration.toDouble(),
                  min: 15.0,
                  max: 120.0,
                  divisions: 21,
                  label: '$_estimatedDuration min',
                  onChanged: (value) {
                    setState(() {
                      _estimatedDuration = value.round();
                    });
                  },
                ),
                Center(child: Text('$_estimatedDuration ${lang.translate('minutes_label')}')),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(lang.translate('scheduled_date')),
              subtitle: Text(_scheduledDate.toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: lang.translate('recurrence_label'),
                        border: const OutlineInputBorder(),
                      ),
                      initialValue: _recurrenceFrequency,
                      items: ['None', 'Daily', 'Weekly', 'Monthly']
                          .map((freq) => DropdownMenuItem(
                                value: freq,
                                child: Text(lang.translate(freq.toLowerCase())),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _recurrenceFrequency = value!;
                          if (_recurrenceFrequency == 'Daily' && (_recurrenceDayCount < 1 || _recurrenceDayCount > 7)) {
                            _recurrenceDayCount = 1;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_recurrenceFrequency == 'Daily')
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Repeat for (days)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _recurrenceDayCount,
                        items: [1,2,3,4,5,6,7]
                            .map((day) => DropdownMenuItem(
                                  value: day,
                                  child: Text('$day ${day > 1 ? lang.translate('days_label') : lang.translate('day_label')}'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _recurrenceDayCount = val ?? 1;
                          });
                        },
                      ),
                    ),
                  if (_recurrenceFrequency == 'Weekly' || _recurrenceFrequency == 'Monthly')
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: _recurrenceFrequency == 'Weekly' ? lang.translate('repeat_for_weeks') : lang.translate('repeat_for_months'),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _recurrenceCount.toString(),
                        onChanged: (val) {
                          setState(() {
                            _recurrenceCount = int.tryParse(val) ?? 1;
                          });
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// @brief Build Step 1 (Trainee Selection) page of the wizard
  /// @details This step allows trainers to select which trainee(s) should receive
  /// this workout. Multiple trainees can be selected. Each selected trainee will
  /// receive a separate copy of the workout (or multiple copies if recurrence is enabled).
  /// Selection is tracked by matching UserModel.id values.
  ///
  /// Each trainee is displayed as a Card with:
  /// - Avatar with first letter of trainee's name
  /// - Trainee name (bolded if selected)
  /// - Email address
  /// - Checkbox for selection (synced with _selectedTrainees list)
  /// - Highlighted background color when selected
  ///
  /// Validation requires at least one trainee to be selected before proceeding.
  /// In edit mode, the original trainee is auto-selected (read-only effectively).
  ///
  /// @return Widget A scrollable list of trainee selection cards with checkboxes
  Widget _buildTraineeSelectionPage() {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.translate('select_trainees'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Scrollable list of available trainees
          Expanded(
            child: ListView.builder(
              itemCount: widget.trainees.length,
              itemBuilder: (context, index) {
                final trainee = widget.trainees[index];
                // Check if this trainee is in the selected list by matching IDs
                final isSelected = _selectedTrainees.any((t) => t.id == trainee.id);

                return Card(
                  // Highlight selected trainees with primary color background
                  color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                  child: ListTile(
                    // Avatar with trainee's initial
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.green,
                      child: Text(
                        trainee.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    // Trainee name (bold if selected)
                    title: Text(
                      trainee.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    // Trainee email
                    subtitle: Text(trainee.email),
                    // Checkbox to toggle selection
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            // Add trainee to selected list
                            _selectedTrainees.add(trainee);
                          } else {
                            // Remove trainee from selected list
                            _selectedTrainees.removeWhere((t) => t.id == trainee.id);
                          }
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// @brief Build Step 2 (Exercise Selection) page of the wizard
  /// @details This step allows trainers to add, configure, and manage exercises
  /// for the workout. The page provides multiple ways to add exercises:
  /// - "Add Exercise": Browse and select from the predefined exercise library
  /// - "Create Custom": Define a brand new custom exercise
  ///
  /// Once exercises are added, they're displayed in a reorderable list where users can:
  /// - View exercise details (sets x reps @ weight)
  /// - Drag-and-drop to reorder exercises
  /// - Edit exercise configuration (sets, reps, weight, rest time, notes)
  /// - Delete exercises from the workout
  ///
  /// The UI is responsive: on very narrow screens (<320px), buttons are stacked vertically
  /// with reduced text. On narrow screens (320-400px), buttons appear as icons with tooltips.
  /// On wider screens, full-text buttons are displayed.
  ///
  /// Validation requires at least one exercise before proceeding to the next step.
  /// The list supports ReorderableListView for drag-and-drop reordering.
  ///
  /// @return Widget A column with add buttons and a reorderable exercise list
  Widget _buildExerciseSelectionPage() {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Responsive layout for add exercise buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 320;
              final isNarrow = constraints.maxWidth < 400;

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('add_exercises_count', params: {'count': '${_selectedExercises.length}'}),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showExerciseLibrary,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(lang.translate('add'), style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showCustomExerciseDialog,
                            icon: const Icon(Icons.fitness_center, size: 16),
                            label: Text(lang.translate('custom'), style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.translate('add_exercises_count', params: {'count': '${_selectedExercises.length}'}),
                          style: TextStyle(
                            fontSize: isNarrow ? 16 : 18,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      isNarrow
                        ? IconButton(
                            onPressed: _showExerciseLibrary,
                            icon: const Icon(Icons.add),
                            tooltip: 'Add Exercise',
                          )
                        : ElevatedButton.icon(
                            onPressed: _showExerciseLibrary,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(lang.translate('add_exercise'), style: const TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      isNarrow
                        ? IconButton(
                            onPressed: _showCustomExerciseDialog,
                            icon: const Icon(Icons.fitness_center),
                            tooltip: 'Create Custom Exercise',
                          )
                        : OutlinedButton.icon(
                            onPressed: _showCustomExerciseDialog,
                            icon: const Icon(Icons.fitness_center, size: 18),
                            label: Text(lang.translate('create_custom_exercise'), style: const TextStyle(fontSize: 14)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedExercises.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(lang.translate('no_exercises_added')),
                        const SizedBox(height: 8),
                        Text(lang.translate('tap_add_to_start')),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _selectedExercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final exercise = _selectedExercises.removeAt(oldIndex);
                        _selectedExercises.insert(newIndex, exercise);
                      });
                    },
                    itemBuilder: (context, index) {
                      final exercise = _selectedExercises[index];
                      final lang = context.watch<LanguageProvider>();
                      final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
                      return Card(
                        key: ValueKey(exercise.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(translatedName),
                          subtitle: Text(
                            '${exercise.sets} sets × ${exercise.reps} reps'
                            '${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editExercise(index),
                                icon: const Icon(Icons.edit, color: Colors.blue),
                              ),
                              IconButton(
                                onPressed: () => _removeExercise(index),
                                icon: const Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// @brief Build Step 3 (Review & Create) page of the wizard
  /// @details This final step displays a comprehensive summary of all workout
  /// configuration before creation or update:
  /// - Basic Information: name, description, category, difficulty, duration, scheduled date, recurrence
  /// - Assigned To: list of selected trainees and their emails
  /// - Exercises: count and details (sets x reps @ weight) for each exercise
  /// - Additional Notes: optional instructions for the trainee
  /// - Recurrence Summary: (if applicable) total workout count calculation
  ///
  /// The page is scrollable to accommodate long exercise lists. Read-only display
  /// allows trainers to verify all details before committing. For recurring workouts,
  /// a blue information box displays the total number of workout instances that
  /// will be created (trainees × occurrences).
  ///
  /// Example: 2 trainees × 4 weekly occurrences = 8 total workouts
  ///
  /// @return Widget A scrollable column displaying complete workout configuration summary
  Widget _buildReviewPage() {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate('review_workout'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Summary card: Basic workout information
            _buildReviewCard(lang.translate('basic_information'), [
              '${lang.translate('name')}: ${_nameController.text}',
              '${lang.translate('description')}: ${_descriptionController.text}',
              '${lang.translate('category_label')}: ${_category.toUpperCase()}',
              '${lang.translate('difficulty_level')}: ${lang.translate(_difficulty)}',
              '${lang.translate('duration_label')}: $_estimatedDuration ${lang.translate('minutes_label')}',
              '${lang.translate('scheduled_label')}: ${_scheduledDate.toString().split(' ')[0]}',
              '${lang.translate('recurrence_label')}: ${_getRecurrenceDescription()}',
            ]),
            const SizedBox(height: 16),

            // Summary card: Trainee assignments
            _buildReviewCard(lang.translate('assigned_to'), [
              '${lang.translate('trainees')}: ${_selectedTrainees.isNotEmpty ? _selectedTrainees.map((t) => t.name).join(", ") : lang.translate('none_selected')}',
              '${lang.translate('emails')}: ${_selectedTrainees.isNotEmpty ? _selectedTrainees.map((t) => t.email).join(", ") : ''}',
            ]),
            const SizedBox(height: 16),

            // Summary card: Exercise list with counts
            _buildReviewCard(lang.translate('exercises_with_count', params: {'count': '${_selectedExercises.length}'}),
              _selectedExercises.map((exercise) {
                final lang = context.watch<LanguageProvider>();
                final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
                return '$translatedName - ${exercise.sets}×${exercise.reps}${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}';
              }).toList()),
            const SizedBox(height: 16),

            // Optional notes field for trainer instructions
            CustomTextField(
              label: 'Additional Notes (Optional)',
              controller: _notesController,
              hint: 'Any special instructions for the trainee...',
            ),
            const SizedBox(height: 16),

            // Recurrence summary (only shown if recurrence is enabled)
            if (_recurrenceFrequency != 'None')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recurrence Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Total workout count calculation
                    Text(
                      'This will create ${_getTotalWorkoutsCount()} workout${_getTotalWorkoutsCount() > 1 ? 's' : ''} total',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                    // Breakdown: trainees × occurrences
                    Text(
                      '${_selectedTrainees.length} trainee${_selectedTrainees.length > 1 ? 's' : ''} × ${_getRecurrenceInstances()} occurrence${_getRecurrenceInstances() > 1 ? 's' : ''} each',
                      style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// @brief Build a styled review summary card
  /// @details Creates a reusable Card widget for displaying review information.
  /// Each card has a bold title and a list of detail items. Used on the review page
  /// to organize information into logical sections (Basic Info, Assigned To, Exercises).
  /// @param title The heading for this review card section
  /// @param items List of detail strings to display (one per line)
  /// @return Widget A Card containing the title and formatted item list
  Widget _buildReviewCard(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(item),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final lang = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          return Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: CustomButton(
                    text: lang.translate('previous'),
                    onPressed: _previousPage,
                    isOutlined: true,
                    icon: Icons.arrow_back,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 12),

              Expanded(
                child: _currentPage < _totalPages - 1
                  ? CustomButton(
                      text: lang.translate('next'),
                      onPressed: _canProceedToNext() ? _nextPage : () {},
                      icon: Icons.arrow_forward,
                    )
                  : CustomButton(
                      text: widget.initialWorkout != null
                          ? lang.translate('update_workout')
                          : lang.translate('create_workout_button'),
                      onPressed: _canCreateWorkout() ? _createWorkout : () {},
                      icon: Icons.check,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== NAVIGATION AND VALIDATION METHODS =====

  /// @brief Animate to the previous wizard step
  /// @details Programmatically triggers a smooth page transition to the previous step
  /// in the PageView. The animation lasts 300ms with ease-in-out curve for smooth
  /// visual effect. Only called when the Previous button is visible (not on step 0).
  /// @return void
  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// @brief Animate to the next wizard step
  /// @details Programmatically triggers a smooth page transition to the next step
  /// in the PageView. The animation lasts 300ms with ease-in-out curve. Only called
  /// when validation passes (see _canProceedToNext). Not called on the final step (3).
  /// @return void
  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// @brief Validate that user can proceed from current step to the next
  /// @details Enforces step-specific validation rules before allowing Next button:
  /// - Step 0 (Basic Info): Name and description must be non-empty
  /// - Step 1 (Trainee Selection): At least one trainee must be selected
  /// - Step 2 (Exercise Selection): At least one exercise must be added
  /// - Step 3 (Review): Always true (final step, no next button)
  /// This prevents users from progressing with incomplete data.
  /// @return bool True if user can proceed to next step, false otherwise
  bool _canProceedToNext() {
    switch (_currentPage) {
      case 0:
        // Step 0: Validate basic information is complete
        return _nameController.text.isNotEmpty &&
               _descriptionController.text.isNotEmpty &&
               _category.isNotEmpty &&
               _difficulty.isNotEmpty;
      case 1:
        // Step 1: Validate at least one trainee is selected
        return _selectedTrainees.isNotEmpty;
      case 2:
        // Step 2: Validate at least one exercise is added
        return _selectedExercises.isNotEmpty;
      default:
        // Step 3 (or other): No validation needed
        return true;
    }
  }

  /// @brief Validate that the entire workout is complete and ready for creation
  /// @details Checks all required fields across all steps:
  /// - Name and description must be non-empty (from Step 0)
  /// - At least one trainee selected (from Step 1)
  /// - At least one exercise added (from Step 2)
  /// Used to enable/disable the Create button on Step 3 (Review page).
  /// @return bool True if all required data is complete, false otherwise
  bool _canCreateWorkout() {
    return _nameController.text.isNotEmpty &&
           _descriptionController.text.isNotEmpty &&
           _selectedTrainees.isNotEmpty &&
           _selectedExercises.isNotEmpty;
  }

  /// @brief Generate human-readable recurrence description
  /// @details Converts recurrence configuration into a user-friendly string for display
  /// in the review step and header. Examples:
  /// - 'Daily for 3 days'
  /// - 'Weekly for 2 weeks'
  /// - 'Monthly for 1 month'
  /// - 'None (single workout)' [default]
  /// Used in _buildReviewPage() to display the recurrence setting.
  /// @return String A human-readable description of the recurrence pattern
  String _getRecurrenceDescription() {
    switch (_recurrenceFrequency) {
      case 'Daily':
        return 'Daily for $_recurrenceDayCount day${_recurrenceDayCount > 1 ? 's' : ''}';
      case 'Weekly':
        return 'Weekly for $_recurrenceCount week${_recurrenceCount > 1 ? 's' : ''}';
      case 'Monthly':
        return 'Monthly for $_recurrenceCount month${_recurrenceCount > 1 ? 's' : ''}';
      default:
        return 'None (single workout)';
    }
  }

  /// @brief Calculate the number of workout instances based on recurrence settings
  /// @details Determines how many separate workout copies will be created for
  /// EACH TRAINEE based on the recurrence frequency:
  /// - 'Daily': Returns _recurrenceDayCount (1-7)
  /// - 'Weekly'/'Monthly': Returns _recurrenceCount
  /// - 'None': Returns 1 (single occurrence)
  ///
  /// Example: If Daily for 3 days, returns 3
  /// Does not account for number of trainees - use _getTotalWorkoutsCount() for that.
  /// @return int The number of occurrences per trainee
  int _getRecurrenceInstances() {
    switch (_recurrenceFrequency) {
      case 'Daily':
        return _recurrenceDayCount;
      case 'Weekly':
      case 'Monthly':
        return _recurrenceCount;
      default:
        return 1;
    }
  }

  /// @brief Calculate total number of workout instances across all trainees and occurrences
  /// @details Multiplies the number of selected trainees by the number of recurrence
  /// instances per trainee. This is the total count of TrainingModel instances that
  /// will be created.
  ///
  /// Example: 2 trainees × 4 weekly occurrences = 8 total workouts
  /// Displayed in the Recurrence Summary box on the review page.
  /// @return int The total number of workout instances to be created
  int _getTotalWorkoutsCount() {
    return _selectedTrainees.length * _getRecurrenceInstances();
  }

  // ===== ACTION METHODS FOR USER INTERACTIONS =====

  /// @brief Show a date picker dialog for scheduling the workout
  /// @details Displays a native date picker allowing trainers to select the scheduled
  /// date for the first workout occurrence. The date picker:
  /// - Shows the current _scheduledDate as the initial value
  /// - Restricts selection to today and up to 365 days in the future
  /// - Updates _scheduledDate if user confirms selection
  /// Called when user taps the "Scheduled Date" ListTile in Step 0.
  /// @return Future<void> Completes after user selection (or dismissal)
  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _scheduledDate = date;
      });
    }
  }

  /// @brief Show the exercise library dialog for selecting predefined exercises
  /// @details Opens a modal dialog displaying searchable list of predefined exercises
  /// from ExerciseLibraryService. When user selects an exercise, the library dialog
  /// is closed and exercise configuration dialog is shown for the selected exercise.
  /// The configuration dialog allows user to set sets, reps, weight, and rest time
  /// before adding the exercise to the workout.
  /// Called when user taps "Add Exercise" button in Step 2.
  /// @return void
  void _showExerciseLibrary() {
    showDialog(
      context: context,
      builder: (context) => _ExerciseLibraryDialog(
        exerciseLibrary: _exerciseLibrary,
        // Chain to configuration dialog when user selects an exercise
        onExerciseSelected: (exerciseTemplate) {
          _showExerciseConfigDialog(exerciseTemplate);
        },
      ),
    );
  }

  /// @brief Show the exercise configuration dialog for selected exercise
  /// @details Opens a modal dialog for configuring a selected exercise template.
  /// Allows user to set:
  /// - Sets (number of sets to perform)
  /// - Reps (repetitions per set)
  /// - Weight (optional, in kg)
  /// - Rest Time (seconds between sets, 30-180s via slider)
  /// - Notes (optional instructions for this exercise)
  /// When user confirms, the configured ExerciseModel is added to _selectedExercises.
  /// Closes the previously opened exercise library dialog before showing this dialog.
  /// @param template The ExerciseTemplate to configure
  /// @return void
  void _showExerciseConfigDialog(ExerciseTemplate template) {
    Navigator.pop(context); // Close exercise library dialog first

    showDialog(
      context: context,
      builder: (context) => _ExerciseConfigDialog(
        template: template,
        // Add the configured exercise to the selected list
        onExerciseConfigured: (exercise) {
          setState(() {
            _selectedExercises.add(exercise);
          });
        },
      ),
    );
  }

  /// @brief Show the custom exercise creation dialog
  /// @details Opens a modal dialog allowing trainers to define a custom exercise
  /// not in the predefined library. The dialog (CustomExerciseDialog) handles all
  /// custom exercise fields (name, instructions, target muscle, equipment, etc.)
  /// and returns an ExerciseTemplate.
  ///
  /// After custom exercise is created, automatically shows the exercise configuration
  /// dialog to set sets, reps, weight, and rest time before adding to workout.
  /// Gets current user ID from AuthProvider for trainer association.
  /// Called when user taps "Create Custom" button in Step 2.
  /// @return Future<void> Completes after user dismisses all dialogs
  void _showCustomExerciseDialog() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    // Show custom exercise creation dialog
    final result = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (context) => CustomExerciseDialog(
        trainerId: currentUser.id,
      ),
    );

    // If user successfully created a custom exercise, show configuration dialog
    if (result != null) {
      _showExerciseConfigDialog(result);
    }
  }

  /// @brief Show dialog to edit an exercise already in the workout
  /// @details Opens a modal dialog for modifying an exercise's configuration.
  /// Allows user to update:
  /// - Sets and reps
  /// - Weight (kg)
  /// - Rest time between sets
  /// - Additional notes
  /// The updated exercise replaces the original at the same index in _selectedExercises.
  /// @param index The position of the exercise in _selectedExercises to edit
  /// @return void
  void _editExercise(int index) {
    final exercise = _selectedExercises[index];
    showDialog(
      context: context,
      builder: (context) => _ExerciseEditDialog(
        exercise: exercise,
        // Replace the exercise at the original index
        onExerciseUpdated: (updatedExercise) {
          setState(() {
            _selectedExercises[index] = updatedExercise;
          });
        },
      ),
    );
  }

  /// @brief Remove an exercise from the selected exercises list
  /// @details Deletes an exercise at the specified index from _selectedExercises.
  /// Called when user taps delete icon on an exercise in the list.
  /// The list automatically updates via setState, triggering UI rebuild and
  /// ReorderableListView refresh. No dialog shown - deletion is immediate.
  /// @param index The position of the exercise to remove from the list
  /// @return void
  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  /// @brief Create workout(s) based on wizard configuration
  /// @details This is the core method that executes the workout creation or edit operation.
  /// The method handles two distinct workflows:
  ///
  /// EDIT MODE (if initialWorkout provided):
  /// - Updates the existing workout with new configuration
  /// - Preserves original ID, trainer ID, completion status
  /// - Calls onWorkoutCreated callback once with updated model
  /// - Selects only the first trainee (no multi-trainee edit)
  ///
  /// CREATE MODE (no initialWorkout):
  /// - Creates multiple TrainingModel instances based on recurrence and trainees
  /// - Generates unique ID for each instance using UUID v4
  /// - For recurring workouts: generates shared recurrenceGroupId for linkage
  /// - Calculates scheduled dates: base + (recurrenceStep × occurrence index)
  /// - Creates separate instances for each trainee and each occurrence
  /// - Example: 2 trainees, Weekly×4 = 8 total TrainingModels
  ///
  /// RECURRENCE SCHEDULING:
  /// - 'Daily': Creates instances 1 day apart for N days
  /// - 'Weekly': Creates instances 7 days apart for N weeks
  /// - 'Monthly': Creates instances 30 days apart for N months
  /// - 'None': Creates single instance with no recurrence fields
  ///
  /// PERSISTENCE:
  /// - Each created model is immediately persisted via TrainingService
  /// - onWorkoutCreated callback invoked for each instance (for state updates)
  /// - Dialog closed after completion
  /// - Success SnackBar shown with total count
  ///
  /// @return void
  void _createWorkout() {
    int totalCreated = 0;

    // Step 1: Determine recurrence timing and instance count
    Duration recurrenceStep;      // Time interval between occurrences
    int recurrenceInstances;      // Number of times to create for each trainee

    switch (_recurrenceFrequency) {
      case 'Daily':
        recurrenceStep = const Duration(days: 1);
        recurrenceInstances = _recurrenceDayCount;
        break;
      case 'Weekly':
        recurrenceStep = const Duration(days: 7);
        recurrenceInstances = _recurrenceCount;
        break;
      case 'Monthly':
        recurrenceStep = const Duration(days: 30);
        recurrenceInstances = _recurrenceCount;
        break;
      default:
        // No recurrence: single workout
        recurrenceStep = Duration.zero;
        recurrenceInstances = 1;
    }

    // Step 2: Handle edit mode vs create mode
    if (widget.initialWorkout != null) {
      // === EDIT MODE: Update existing workout ===
      final updatedWorkout = TrainingModel(
        id: widget.initialWorkout!.id,              // Preserve original ID
        name: _nameController.text,
        description: _descriptionController.text,
        exercises: _selectedExercises,
        traineeId: _selectedTrainees.first.id,      // Use first selected trainee
        trainerId: widget.initialWorkout!.trainerId, // Preserve original trainer
        scheduledDate: _scheduledDate,
        difficulty: _difficulty,
        estimatedDuration: _estimatedDuration,
        category: _category,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        isCompleted: widget.initialWorkout!.isCompleted,      // Preserve completion status
        completedAt: widget.initialWorkout!.completedAt,
      );
      widget.onWorkoutCreated(updatedWorkout);
      totalCreated = 1;
    } else {
      // === CREATE MODE: Create new workouts with recurrence and multi-trainee support ===
      for (final trainee in _selectedTrainees) {
        // Generate recurrence group ID to link all instances of this trainee's recurring series
        final recurrenceGroupId = recurrenceInstances > 1 ? const Uuid().v4() : null;

        // Loop: Create one instance for each recurrence occurrence
        for (int i = 0; i < recurrenceInstances; i++) {
          // Calculate scheduled date for this occurrence
          // Example: if base is Jan 1 and recurrence is weekly with index 2,
          // then scheduled = Jan 1 + (7 days × 2) = Jan 15
          final scheduledDate = recurrenceStep == Duration.zero
              ? _scheduledDate
              : _scheduledDate.add(recurrenceStep * i);

          // Create a new TrainingModel instance with all configuration
          final traineeWorkout = TrainingModel(
            id: const Uuid().v4(),                   // Unique ID for each instance
            name: _nameController.text,
            description: _descriptionController.text,
            exercises: _selectedExercises,
            traineeId: trainee.id,                   // Different trainee per loop iteration
            trainerId: widget.trainees.isNotEmpty ? widget.trainees.first.id : '', // Fallback
            scheduledDate: scheduledDate,            // Calculated based on recurrence
            difficulty: _difficulty,
            estimatedDuration: _estimatedDuration,
            category: _category,
            notes: _notesController.text.isNotEmpty ? _notesController.text : null,
            recurrenceGroupId: recurrenceGroupId,    // Null for single, UUID for recurring
            recurrenceIndex: recurrenceInstances > 1 ? i : null,      // 0, 1, 2, ... (null if single)
            totalRecurrences: recurrenceInstances > 1 ? recurrenceInstances : null,  // Total count
          );

          // Persist to service and notify listeners
          sl.get<TrainingService>().createTraining(traineeWorkout);
          widget.onWorkoutCreated(traineeWorkout);   // Update parent state/UI
          totalCreated++;
        }
      }
    }

    // Step 3: Close dialog and show success message
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.initialWorkout != null
            ? 'Workout updated!'
            : 'Created $totalCreated workout${totalCreated > 1 ? 's' : ''} successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Exercise Library Dialog
class _ExerciseLibraryDialog extends StatefulWidget {
  final ExerciseLibraryService exerciseLibrary;
  final Function(ExerciseTemplate) onExerciseSelected;

  const _ExerciseLibraryDialog({
    required this.exerciseLibrary,
    required this.onExerciseSelected,
  });

  @override
  State<_ExerciseLibraryDialog> createState() => _ExerciseLibraryDialogState();
}

class _ExerciseLibraryDialogState extends State<_ExerciseLibraryDialog> {
  final _searchController = TextEditingController();
  List<ExerciseTemplate> _filteredExercises = [];

  @override
  void initState() {
    super.initState();
    _filteredExercises = widget.exerciseLibrary.getAllExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Exercise Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _filterExercises,
              ),
            ),
            Expanded(
              child: _buildExercisesList(_filteredExercises),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesList(List<ExerciseTemplate> exercises) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final lang = context.watch<LanguageProvider>();
        final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(exercise.category),
              child: Icon(_getCategoryIcon(exercise.category), color: Colors.white),
            ),
            title: Text(translatedName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exercise.targetMuscle.toUpperCase()} • ${exercise.equipment.toUpperCase()}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(exercise.difficultyLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    exercise.difficultyLevel.toUpperCase(),
                    style: TextStyle(
                      color: _getDifficultyColor(exercise.difficultyLevel),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.add_circle, color: Colors.green),
            onTap: () => widget.onExerciseSelected(exercise),
          ),
        );
      },
    );
  }

  void _filterExercises(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredExercises = widget.exerciseLibrary.getAllExercises();
      } else {
        _filteredExercises = widget.exerciseLibrary.searchExercises(query);
      }
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'strength':
        return Colors.blue;
      case 'cardio':
        return Colors.red;
      case 'flexibility':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'strength':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.favorite;
      case 'flexibility':
        return Icons.self_improvement;
      default:
        return Icons.sports;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Exercise Configuration Dialog
class _ExerciseConfigDialog extends StatefulWidget {
  final ExerciseTemplate template;
  final Function(ExerciseModel) onExerciseConfigured;

  const _ExerciseConfigDialog({
    required this.template,
    required this.onExerciseConfigured,
  });

  @override
  State<_ExerciseConfigDialog> createState() => _ExerciseConfigDialogState();
}

class _ExerciseConfigDialogState extends State<_ExerciseConfigDialog> {
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  int _restTimeSeconds = 60;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final translatedName = LocalizationService.translateExerciseName(widget.template.name, lang.currentLanguage);

    return AlertDialog(
      title: Text('${lang.translate('configure')} $translatedName'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.template.instructions,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.template.tips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(lang.translate('tips_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...widget.template.tips.map((tip) => Text('• $tip')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: lang.translate('sets'),
                      controller: _setsController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      label: lang.translate('reps'),
                      controller: _repsController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: '${lang.translate('weight_kg')} - ${lang.translate('optional')}',
                controller: _weightController,
                keyboardType: TextInputType.number,
                hint: 'Leave empty for bodyweight',
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${lang.translate('rest_time')}: ${_restTimeSeconds}s'),
                  Slider(
                    value: _restTimeSeconds.toDouble(),
                    min: 30,
                    max: 180,
                    divisions: 15,
                    onChanged: (value) {
                      setState(() {
                        _restTimeSeconds = value.round();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Notes (Optional)',
                controller: _notesController,
                hint: 'Additional instructions...',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lang.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (_setsController.text.isNotEmpty && _repsController.text.isNotEmpty) {
              final exercise = widget.template.toExerciseModel(
                sets: int.parse(_setsController.text),
                reps: int.parse(_repsController.text),
                weight: _weightController.text.isNotEmpty
                    ? double.parse(_weightController.text)
                    : null,
                notes: _notesController.text.isNotEmpty ? _notesController.text : null,
                restTimeSeconds: _restTimeSeconds,
              );
              
              widget.onExerciseConfigured(exercise);
              Navigator.pop(context);
            }
          },
          child: Text(lang.translate('add_exercise')),
        ),
      ],
    );
  }
}

// Exercise Edit Dialog
class _ExerciseEditDialog extends StatefulWidget {
  final ExerciseModel exercise;
  final Function(ExerciseModel) onExerciseUpdated;

  const _ExerciseEditDialog({
    required this.exercise,
    required this.onExerciseUpdated,
  });

  @override
  State<_ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<_ExerciseEditDialog> {
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;
  late int _restTimeSeconds;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: widget.exercise.sets.toString());
    _repsController = TextEditingController(text: widget.exercise.reps.toString());
    _weightController = TextEditingController(
      text: widget.exercise.weight?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.exercise.notes ?? '');
    _restTimeSeconds = widget.exercise.restTimeSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return AlertDialog(
      title: Text(lang.translate('edit_exercise_title', params: {'name': widget.exercise.name})),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Sets',
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Reps',
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Weight (kg)',
              controller: _weightController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lang.translate('rest_time')}: ${_restTimeSeconds}s'),
                Slider(
                  value: _restTimeSeconds.toDouble(),
                  min: 30,
                  max: 180,
                  divisions: 15,
                  onChanged: (value) {
                    setState(() {
                      _restTimeSeconds = value.round();
                    });
                  },
                ),
              ],
            ),
CustomTextField(
              label: 'Notes',
              controller: _notesController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lang.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedExercise = ExerciseModel(
              id: widget.exercise.id,
              name: widget.exercise.name,
              sets: int.parse(_setsController.text),
              reps: int.parse(_repsController.text),
              weight: _weightController.text.isNotEmpty
                  ? double.parse(_weightController.text)
                  : null,
              notes: _notesController.text.isNotEmpty ? _notesController.text : null,
              category: widget.exercise.category,
              targetMuscle: widget.exercise.targetMuscle,
              equipment: widget.exercise.equipment,
              instructions: widget.exercise.instructions,
              restTimeSeconds: _restTimeSeconds,
            );
            
            widget.onExerciseUpdated(updatedExercise);
            Navigator.pop(context);
          },
          child: Text(lang.translate('save_changes')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}