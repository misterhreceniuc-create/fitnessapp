import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/services/exercise_library_service.dart';
import '../../../../shared/providers/auth_provider.dart';

class CustomExerciseDialog extends StatefulWidget {
  final String? trainerId;
  final Function(ExerciseTemplate)? onExerciseCreated;

  const CustomExerciseDialog({
    super.key,
    this.trainerId,
    this.onExerciseCreated,
  });

  @override
  State<CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<CustomExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _tipsController = TextEditingController();

  String _selectedCategory = 'strength';
  String _selectedTargetMuscle = 'chest';
  String _selectedEquipment = 'bodyweight';
  String _selectedDifficulty = 'beginner';

  final List<String> _categories = ['strength', 'cardio', 'flexibility', 'balance'];
  final List<String> _targetMuscles = [
    'chest', 'back', 'legs', 'shoulders', 'arms', 'core', 'full_body'
  ];
  final List<String> _equipment = [
    'bodyweight', 'dumbbell', 'barbell', 'kettlebell', 'resistance_band',
    'pullup_bar', 'bench', 'cable_machine', 'medicine_ball'
  ];
  final List<String> _difficultyLevels = ['beginner', 'intermediate', 'advanced'];

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _videoUrlController.dispose();
    _tipsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Create Custom Exercise',
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

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Exercise name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.toUpperCase()),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTargetMuscle,
                        decoration: const InputDecoration(
                          labelText: 'Target Muscle',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.accessibility),
                        ),
                        items: _targetMuscles.map((muscle) => DropdownMenuItem(
                          value: muscle,
                          child: Text(muscle.replaceAll('_', ' ').toUpperCase()),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTargetMuscle = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedEquipment,
                        decoration: const InputDecoration(
                          labelText: 'Equipment',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sports_gymnastics),
                        ),
                        items: _equipment.map((equipment) => DropdownMenuItem(
                          value: equipment,
                          child: Text(equipment.replaceAll('_', ' ').toUpperCase()),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEquipment = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDifficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.signal_cellular_alt),
                        ),
                        items: _difficultyLevels.map((difficulty) => DropdownMenuItem(
                          value: difficulty,
                          child: Text(difficulty.toUpperCase()),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDifficulty = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'How to Perform *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Describe step-by-step how to perform this exercise...',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Instructions are required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _tipsController,
                  decoration: const InputDecoration(
                    labelText: 'Tips (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lightbulb_outline),
                    hintText: 'Separate tips with commas (e.g., Keep core tight, Control the movement)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _videoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Video URL (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.video_library),
                    hintText: 'YouTube, Vimeo, or direct video link',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _createExercise,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create Exercise'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _createExercise() {
    if (_formKey.currentState!.validate()) {
      final tips = _tipsController.text.isNotEmpty
          ? _tipsController.text.split(',').map((tip) => tip.trim()).where((tip) => tip.isNotEmpty).toList()
          : <String>[];

      final currentUser = context.read<AuthProvider>().currentUser;
      final trainerId = widget.trainerId ?? currentUser?.id;

      if (trainerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No trainer ID available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final exercise = ExerciseTemplate(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        category: _selectedCategory,
        targetMuscle: _selectedTargetMuscle,
        equipment: _selectedEquipment,
        instructions: _instructionsController.text.trim(),
        difficultyLevel: _selectedDifficulty,
        tips: tips,
        videoUrl: _videoUrlController.text.trim().isNotEmpty ? _videoUrlController.text.trim() : null,
        createdBy: trainerId,
        isCustom: true,
      );

      try {
        final exerciseService = ExerciseLibraryService();
        exerciseService.addCustomExercise(exercise);

        if (widget.onExerciseCreated != null) {
          widget.onExerciseCreated!(exercise);
        }

        Navigator.pop(context, exercise);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom exercise "${exercise.name}" created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating exercise: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}