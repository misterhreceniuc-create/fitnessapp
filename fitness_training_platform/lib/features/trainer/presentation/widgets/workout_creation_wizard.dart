import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/services/exercise_library_service.dart';
import '../../../../shared/widgets/common/custom_button.dart';
import '../../../../shared/widgets/common/custom_text_field.dart';

class WorkoutCreationWizard extends StatefulWidget {
  final List<UserModel> trainees;
  final Function(TrainingModel) onWorkoutCreated;

  const WorkoutCreationWizard({
    super.key,
    required this.trainees,
    required this.onWorkoutCreated,
  });

  @override
  State<WorkoutCreationWizard> createState() => _WorkoutCreationWizardState();
}

class _WorkoutCreationWizardState extends State<WorkoutCreationWizard> {
  final PageController _pageController = PageController();
  final ExerciseLibraryService _exerciseLibrary = ExerciseLibraryService();
  
  int _currentPage = 0;
  final int _totalPages = 4;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  // Form data
  UserModel? _selectedTrainee;
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  String _difficulty = 'beginner';
  int _estimatedDuration = 30;
  String _category = 'strength';
  List<ExerciseModel> _selectedExercises = [];

  @override
  void initState() {
    super.initState();
    // If only one trainee, pre-select them
    if (widget.trainees.length == 1) {
      _selectedTrainee = widget.trainees.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildBasicInfoPage(),
                  _buildTraineeSelectionPage(),
                  _buildExerciseSelectionPage(),
                  _buildReviewPage(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'Basic Information',
      'Select Trainee',
      'Add Exercises',
      'Review & Create'
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create Workout',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            titles[_currentPage],
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              label: 'Workout Name',
              controller: _nameController,
              hint: 'e.g., Upper Body Strength',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Brief description of the workout',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _category,
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
              decoration: const InputDecoration(
                labelText: 'Difficulty Level',
                border: OutlineInputBorder(),
              ),
              value: _difficulty,
              items: ['beginner', 'intermediate', 'advanced']
                  .map((difficulty) => DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty.toUpperCase()),
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
                const Text('Estimated Duration (minutes)'),
                Slider(
                  value: _estimatedDuration.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 21,
                  label: '$_estimatedDuration min',
                  onChanged: (value) {
                    setState(() {
                      _estimatedDuration = value.round();
                    });
                  },
                ),
                Center(child: Text('$_estimatedDuration minutes')),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Scheduled Date'),
              subtitle: Text(_scheduledDate.toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraineeSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select Trainee',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.trainees.length,
              itemBuilder: (context, index) {
                final trainee = widget.trainees[index];
                final isSelected = _selectedTrainee?.id == trainee.id;
                
                return Card(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.green,
                      child: Text(
                        trainee.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      trainee.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(trainee.email),
                    trailing: isSelected 
                        ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedTrainee = trainee;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Exercises (${_selectedExercises.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showExerciseLibrary,
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedExercises.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No exercises added yet'),
                        SizedBox(height: 8),
                        Text('Tap "Add Exercise" to get started'),
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
                      return Card(
                        key: ValueKey(exercise.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(exercise.name),
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

  Widget _buildReviewPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Workout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildReviewCard('Basic Information', [
              'Name: ${_nameController.text}',
              'Description: ${_descriptionController.text}',
              'Category: ${_category.toUpperCase()}',
              'Difficulty: ${_difficulty.toUpperCase()}',
              'Duration: $_estimatedDuration minutes',
              'Scheduled: ${_scheduledDate.toString().split(' ')[0]}',
            ]),
            const SizedBox(height: 16),
            _buildReviewCard('Assigned To', [
              'Trainee: ${_selectedTrainee?.name ?? 'None selected'}',
              'Email: ${_selectedTrainee?.email ?? ''}',
            ]),
            const SizedBox(height: 16),
            _buildReviewCard('Exercises (${_selectedExercises.length})', 
              _selectedExercises.map((exercise) =>
                '${exercise.name} - ${exercise.sets}×${exercise.reps}${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}'
              ).toList()),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Additional Notes (Optional)',
              controller: _notesController,
              hint: 'Any special instructions for the trainee...',
            ),
          ],
        ),
      ),
    );
  }

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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            CustomButton(
              text: 'Previous',
              onPressed: _previousPage,
              isOutlined: true,
              icon: Icons.arrow_back,
            )
          else
            const SizedBox(),
          
          if (_currentPage < _totalPages - 1)
            CustomButton(
              text: 'Next',
              onPressed: _canProceedToNext() ? _nextPage : () {},
              icon: Icons.arrow_forward,
            )
          else
            CustomButton(
              text: 'Create Workout',
              onPressed: _canCreateWorkout() ? _createWorkout : () {},
              icon: Icons.check,
            ),
        ],
      ),
    );
  }

  // Navigation methods
  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _canProceedToNext() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.isNotEmpty && _descriptionController.text.isNotEmpty;
      case 1:
        return _selectedTrainee != null;
      case 2:
        return _selectedExercises.isNotEmpty;
      default:
        return true;
    }
  }

  bool _canCreateWorkout() {
    return _nameController.text.isNotEmpty &&
           _descriptionController.text.isNotEmpty &&
           _selectedTrainee != null &&
           _selectedExercises.isNotEmpty;
  }

  // Action methods
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

  void _showExerciseLibrary() {
    showDialog(
      context: context,
      builder: (context) => _ExerciseLibraryDialog(
        exerciseLibrary: _exerciseLibrary,
        onExerciseSelected: (exerciseTemplate) {
          _showExerciseConfigDialog(exerciseTemplate);
        },
      ),
    );
  }

  void _showExerciseConfigDialog(ExerciseTemplate template) {
    Navigator.pop(context); // Close exercise library dialog
    
    showDialog(
      context: context,
      builder: (context) => _ExerciseConfigDialog(
        template: template,
        onExerciseConfigured: (exercise) {
          setState(() {
            _selectedExercises.add(exercise);
          });
        },
      ),
    );
  }

  void _editExercise(int index) {
    final exercise = _selectedExercises[index];
    showDialog(
      context: context,
      builder: (context) => _ExerciseEditDialog(
        exercise: exercise,
        onExerciseUpdated: (updatedExercise) {
          setState(() {
            _selectedExercises[index] = updatedExercise;
          });
        },
      ),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  void _createWorkout() {
    final workout = TrainingModel(
      id: const Uuid().v4(),
      name: _nameController.text,
      description: _descriptionController.text,
      traineeId: _selectedTrainee!.id,
      trainerId: 'current_trainer_id', // This will be updated by the parent
      exercises: _selectedExercises,
      scheduledDate: _scheduledDate,
      difficulty: _difficulty,
      estimatedDuration: _estimatedDuration,
      category: _category,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    widget.onWorkoutCreated(workout);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Workout "${workout.name}" created successfully! 🎉'),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(exercise.category),
              child: Icon(_getCategoryIcon(exercise.category), color: Colors.white),
            ),
            title: Text(exercise.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exercise.targetMuscle.toUpperCase()} • ${exercise.equipment.toUpperCase()}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(exercise.difficultyLevel).withOpacity(0.1),
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
    return AlertDialog(
      title: Text('Configure ${widget.template.name}'),
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
                      const Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                label: 'Weight (kg) - Optional',
                controller: _weightController,
                keyboardType: TextInputType.number,
                hint: 'Leave empty for bodyweight',
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rest Time: ${_restTimeSeconds}s'),
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
          child: const Text('Cancel'),
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
          child: const Text('Add Exercise'),
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
    return AlertDialog(
      title: Text('Edit ${widget.exercise.name}'),
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
                Text('Rest Time: ${_restTimeSeconds}s'),
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
          child: const Text('Cancel'),
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
          child: const Text('Save Changes'),
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