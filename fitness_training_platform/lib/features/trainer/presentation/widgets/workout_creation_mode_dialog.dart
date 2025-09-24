import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../shared/services/template_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

enum WorkoutCreationMode {
  fromScratch,
  fromTemplate,
}

class WorkoutCreationModeDialog extends StatefulWidget {
  final Function(WorkoutCreationMode mode, {WorkoutTemplate? selectedTemplate}) onModeSelected;

  const WorkoutCreationModeDialog({
    super.key,
    required this.onModeSelected,
  });

  @override
  State<WorkoutCreationModeDialog> createState() => _WorkoutCreationModeDialogState();
}

class _WorkoutCreationModeDialogState extends State<WorkoutCreationModeDialog> {
  final TemplateService _templateService = sl.get<TemplateService>();
  List<WorkoutTemplate> _availableTemplates = [];
  WorkoutTemplate? _selectedTemplate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      try {
        // Load both personal and public templates
        final personalTemplates = await _templateService.getTemplatesForTrainer(currentUser.id);
        final publicTemplates = await _templateService.getPublicTemplates();

        // Combine and remove duplicates
        final allTemplates = <WorkoutTemplate>[];
        allTemplates.addAll(personalTemplates);
        for (final template in publicTemplates) {
          if (!allTemplates.any((t) => t.id == template.id)) {
            allTemplates.add(template);
          }
        }

        setState(() {
          _availableTemplates = allTemplates;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading templates: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Create New Workout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose how you want to create your workout:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // From Scratch Option
            Card(
              child: InkWell(
                onTap: () {
                  widget.onModeSelected(WorkoutCreationMode.fromScratch);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create from Scratch',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Build a custom workout by selecting exercises manually',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // From Template Option
            Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.library_books, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use Workout Template',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Start with a pre-built workout template',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_availableTemplates.isEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No templates available. Create some templates first!',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: Row(
                                children: [
                                  Text('Select Template (${_availableTemplates.length} available)'),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: _selectedTemplate != null ? () {
                                      widget.onModeSelected(
                                        WorkoutCreationMode.fromTemplate,
                                        selectedTemplate: _selectedTemplate,
                                      );
                                      Navigator.pop(context);
                                    } : null,
                                    child: const Text('Use Template'),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _availableTemplates.length,
                                itemBuilder: (context, index) {
                                  final template = _availableTemplates[index];
                                  final isSelected = _selectedTemplate?.id == template.id;
                                  return ListTile(
                                    selected: isSelected,
                                    leading: CircleAvatar(
                                      backgroundColor: _getDifficultyColor(template.difficulty),
                                      child: Text(
                                        template.difficulty[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(template.name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(template.description),
                                        Text('${template.exercises.length} exercises • ${template.estimatedDuration} min'),
                                      ],
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                                    onTap: () {
                                      setState(() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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