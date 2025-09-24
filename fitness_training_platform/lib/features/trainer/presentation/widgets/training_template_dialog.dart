import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../shared/services/exercise_library_service.dart';

class WorkoutTemplateDialog extends StatefulWidget {
  final Function(WorkoutTemplate) onTemplateCreated;
  final WorkoutTemplate? initialTemplate;

  const WorkoutTemplateDialog({
    super.key,
    required this.onTemplateCreated,
    this.initialTemplate,
  });

  @override
  State<WorkoutTemplateDialog> createState() => _WorkoutTemplateDialogState();
}

class _WorkoutTemplateDialogState extends State<WorkoutTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _tagsController = TextEditingController();

  final ExerciseLibraryService _exerciseLibraryService = sl.get<ExerciseLibraryService>();

  String _selectedDifficulty = 'beginner';
  String _selectedCategory = 'strength';
  bool _isPublic = false;
  List<ExerciseTemplate> _selectedExercises = [];
  List<ExerciseTemplate> _availableExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableExercises();
    if (widget.initialTemplate != null) {
      _populateForm();
    } else {
      _estimatedDurationController.text = '60';
    }
  }

  void _populateForm() {
    final template = widget.initialTemplate!;
    _nameController.text = template.name;
    _descriptionController.text = template.description;
    _notesController.text = template.notes ?? '';
    _estimatedDurationController.text = template.estimatedDuration.toString();
    _tagsController.text = template.tags.join(', ');
    _selectedDifficulty = template.difficulty;
    _selectedCategory = template.category;
    _isPublic = template.isPublic;
    _selectedExercises = List.from(template.exercises);
  }

  Future<void> _loadAvailableExercises() async {
    try {
      final exercises = _exerciseLibraryService.getAllExercises();
      setState(() {
        _availableExercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.initialTemplate != null ? 'Edit Workout Template' : 'Create Workout Template',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Template Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a template name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description *',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedDifficulty,
                                    decoration: const InputDecoration(
                                      labelText: 'Difficulty',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['beginner', 'intermediate', 'advanced']
                                        .map((difficulty) => DropdownMenuItem(
                                              value: difficulty,
                                              child: Text(difficulty.toUpperCase()),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDifficulty = value!;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['strength', 'cardio', 'flexibility', 'balance']
                                        .map((category) => DropdownMenuItem(
                                              value: category,
                                              child: Text(category.toUpperCase()),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _estimatedDurationController,
                              decoration: const InputDecoration(
                                labelText: 'Estimated Duration (minutes)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter estimated duration';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tagsController,
                              decoration: const InputDecoration(
                                labelText: 'Tags (comma separated)',
                                border: OutlineInputBorder(),
                                hintText: 'upper body, beginner, strength',
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Make Public'),
                              subtitle: const Text('Allow other trainers to use this template'),
                              value: _isPublic,
                              onChanged: (value) {
                                setState(() {
                                  _isPublic = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Select Exercises:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
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
                                        Text('Selected Exercises (${_selectedExercises.length})'),
                                        const Spacer(),
                                        ElevatedButton(
                                          onPressed: _showExerciseSelector,
                                          child: const Text('Add Exercises'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: _selectedExercises.isEmpty
                                        ? const Center(
                                            child: Text('No exercises selected'),
                                          )
                                        : ListView.builder(
                                            itemCount: _selectedExercises.length,
                                            itemBuilder: (context, index) {
                                              final exercise = _selectedExercises[index];
                                              return ListTile(
                                                title: Text(exercise.name),
                                                subtitle: Text('${exercise.category} • ${exercise.targetMuscle}'),
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedExercises.removeAt(index);
                                                    });
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveTemplate,
                  child: Text(widget.initialTemplate != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Select Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _availableExercises[index];
                    final isSelected = _selectedExercises.contains(exercise);
                    return CheckboxListTile(
                      title: Text(exercise.name),
                      subtitle: Text('${exercise.category} • ${exercise.targetMuscle} • ${exercise.equipment}'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedExercises.add(exercise);
                          } else {
                            _selectedExercises.remove(exercise);
                          }
                        });
                        Navigator.pop(context);
                        _showExerciseSelector(); // Refresh the dialog
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTemplate() {
    if (_formKey.currentState!.validate()) {
      if (_selectedExercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one exercise'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser == null) return;

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final template = WorkoutTemplate(
        id: widget.initialTemplate?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        exercises: _selectedExercises,
        difficulty: _selectedDifficulty,
        estimatedDuration: int.parse(_estimatedDurationController.text),
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdBy: currentUser.id,
        isPublic: _isPublic,
        tags: tags,
      );

      widget.onTemplateCreated(template);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _estimatedDurationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }
}