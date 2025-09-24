import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/models/training_model.dart';
import '../../../workout/data/exercise_model.dart';

class WorkoutSessionDialog extends StatefulWidget {
  final TrainingModel training;
  final Function(TrainingModel) onWorkoutUpdated;

  const WorkoutSessionDialog({
    super.key,
    required this.training,
    required this.onWorkoutUpdated,
  });

  @override
  State<WorkoutSessionDialog> createState() => _WorkoutSessionDialogState();
}

class _WorkoutSessionDialogState extends State<WorkoutSessionDialog> {
  late List<ExerciseModel> _exercises;
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _isResting = false;
  int _restTimeRemaining = 0;
  Timer? _restTimer;
  
  // Controllers for current set input
  final _repsController = TextEditingController();
  final _kgController = TextEditingController();
  
  // Controllers for editing completed sets
  Map<String, List<TextEditingController>> _editRepsControllers = {};
  Map<String, List<TextEditingController>> _editKgControllers = {};
  
  // Track workout session state
  bool _workoutStarted = false;
  bool _workoutCompleted = false;
  bool _isEditingResults = false;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.training.exercises);
    _initializeEditControllers();
    _loadExistingData();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _repsController.dispose();
    _kgController.dispose();
    _disposeEditControllers();
    super.dispose();
  }

  void _initializeEditControllers() {
    for (int i = 0; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      final exerciseId = exercise.id;
      _editRepsControllers[exerciseId] = [];
      _editKgControllers[exerciseId] = [];
      
      // Initialize controllers for existing sets
      for (int j = 0; j < exercise.actualSets.length; j++) {
        _editRepsControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[j].reps.toString())
        );
        _editKgControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[j].kg.toString())
        );
      }
    }
  }

  void _updateEditControllersForExercise(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final exerciseId = exercise.id;
    final currentActualSets = exercise.actualSets.length;
    final currentControllers = _editRepsControllers[exerciseId]?.length ?? 0;

    // If we need more controllers, add them
    if (currentActualSets > currentControllers) {
      for (int i = currentControllers; i < currentActualSets; i++) {
        _editRepsControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[i].reps.toString())
        );
        _editKgControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[i].kg.toString())
        );
      }
    }
    // If we have too many controllers, dispose and remove the extras
    else if (currentActualSets < currentControllers) {
      for (int i = currentActualSets; i < currentControllers; i++) {
        _editRepsControllers[exerciseId]![i].dispose();
        _editKgControllers[exerciseId]![i].dispose();
      }
      _editRepsControllers[exerciseId] = _editRepsControllers[exerciseId]!.sublist(0, currentActualSets);
      _editKgControllers[exerciseId] = _editKgControllers[exerciseId]!.sublist(0, currentActualSets);
    }
  }

  void _disposeEditControllers() {
    for (final controllers in _editRepsControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    for (final controllers in _editKgControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  void _loadExistingData() {
    // Check if there's existing workout data
    bool hasExistingData = false;
    int lastCompletedExercise = 0;
    int lastCompletedSet = 0;

    for (int i = 0; i < _exercises.length; i++) {
      if (_exercises[i].actualSets.isNotEmpty) {
        hasExistingData = true;
        lastCompletedExercise = i;
        lastCompletedSet = _exercises[i].actualSets.length;
      }
    }

    if (hasExistingData) {
      setState(() {
        _workoutStarted = true;
        _currentExerciseIndex = lastCompletedExercise;
        _currentSetIndex = lastCompletedSet;
        
        // If all sets are completed for current exercise, move to next
        if (_currentSetIndex >= _exercises[_currentExerciseIndex].sets) {
          if (_currentExerciseIndex < _exercises.length - 1) {
            _currentExerciseIndex++;
            _currentSetIndex = 0;
          } else {
            // All exercises completed
            _workoutCompleted = true;
          }
        }
      });
    }
  }

  void _startWorkout() {
    setState(() {
      _workoutStarted = true;
      _currentExerciseIndex = 0;
      _currentSetIndex = 0;
    });
  }

  void _submitSet() {
    final reps = int.tryParse(_repsController.text);
    final kg = double.tryParse(_kgController.text);

    if (reps == null || kg == null || reps <= 0 || kg < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid reps and weight')),
      );
      return;
    }

    // Add the set data using your existing ActualSet class
    final newSet = ActualSet(reps: reps, kg: kg);
    final updatedSets = List<ActualSet>.from(_exercises[_currentExerciseIndex].actualSets);

    if (updatedSets.length <= _currentSetIndex) {
      updatedSets.add(newSet);
    } else {
      updatedSets[_currentSetIndex] = newSet;
    }

    _exercises[_currentExerciseIndex] = _exercises[_currentExerciseIndex].copyWith(
      actualSets: updatedSets,
    );

    // Update edit controllers to match the new actualSets
    _updateEditControllersForExercise(_currentExerciseIndex);

    // Clear input fields
    _repsController.clear();
    _kgController.clear();

    // Save progress
    _saveProgress();

    // Check if this was the last set of the current exercise
    if (_currentSetIndex + 1 >= _exercises[_currentExerciseIndex].sets) {
      // Move to next exercise or complete workout
      if (_currentExerciseIndex + 1 >= _exercises.length) {
        _completeWorkout();
      } else {
        _moveToNextExercise();
      }
    } else {
      // Start rest period for next set
      _startRestPeriod();
    }
  }

  void _startRestPeriod() {
    setState(() {
      _isResting = true;
      _restTimeRemaining = _exercises[_currentExerciseIndex].restTimeSeconds;
      _currentSetIndex++;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_restTimeRemaining > 0) {
          _restTimeRemaining--;
        } else {
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restTimeRemaining = 0;
    });
  }

  void _moveToNextExercise() {
    setState(() {
      _currentExerciseIndex++;
      _currentSetIndex = 0;
      _isResting = false;
    });
    _restTimer?.cancel();
  }

  void _saveProgress() {
    final updatedTraining = widget.training.copyWith(exercises: _exercises);
    widget.onWorkoutUpdated(updatedTraining);
  }

  void _completeWorkout() {
    // Update all edit controllers to match final actualSets
    for (int i = 0; i < _exercises.length; i++) {
      _updateEditControllersForExercise(i);
    }

    setState(() {
      _workoutCompleted = true;
      _isResting = false;
    });
    _restTimer?.cancel();
  }

  void _submitCompletedWorkout() {
    final completedTraining = widget.training.copyWith(
      exercises: _exercises,
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    
    widget.onWorkoutUpdated(completedTraining);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout completed and submitted to trainer!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditingResults = !_isEditingResults;
    });
  }

  void _saveEditedResults() {
    // Validate all inputs first
    for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
      final exercise = _exercises[exerciseIndex];
      final exerciseId = exercise.id;
      final repsControllers = _editRepsControllers[exerciseId]!;
      final kgControllers = _editKgControllers[exerciseId]!;

      for (int setIndex = 0; setIndex < repsControllers.length; setIndex++) {
        final repsText = repsControllers[setIndex].text.trim();
        final kgText = kgControllers[setIndex].text.trim();

        if (repsText.isEmpty || kgText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please fill in all fields for ${exercise.name}, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final reps = int.tryParse(repsText);
        final kg = double.tryParse(kgText);

        if (reps == null || reps <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a valid number of reps for ${exercise.name}, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (kg == null || kg < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a valid weight for ${exercise.name}, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    try {
      // If validation passes, save the results
      for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
        final exercise = _exercises[exerciseIndex];
        final exerciseId = exercise.id;
        final repsControllers = _editRepsControllers[exerciseId]!;
        final kgControllers = _editKgControllers[exerciseId]!;

        // Update actualSets with values from controllers
        final updatedSets = <ActualSet>[];
        for (int setIndex = 0; setIndex < repsControllers.length; setIndex++) {
          final reps = int.parse(repsControllers[setIndex].text.trim());
          final kg = double.parse(kgControllers[setIndex].text.trim());
          updatedSets.add(ActualSet(reps: reps, kg: kg));
        }

        _exercises[exerciseIndex] = exercise.copyWith(actualSets: updatedSets);
      }

      _saveProgress();
      setState(() {
        _isEditingResults = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving changes. Please check your input values.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _workoutCompleted 
                  ? _buildCompletionView()
                  : _workoutStarted 
                      ? _buildWorkoutView()
                      : _buildStartView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.training.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStartView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fitness_center,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to start your workout?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '${_exercises.length} exercises • ${widget.training.estimatedDuration} min',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startWorkout,
              child: const Text('Start Workout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutView() {
    if (_isResting) {
      return _buildRestView();
    }

    final currentExercise = _exercises[_currentExerciseIndex];
    final completedSets = currentExercise.actualSets.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentExerciseIndex + (_currentSetIndex / currentExercise.sets)) / _exercises.length,
          ),
          const SizedBox(height: 20),
          
          // Exercise info
          Text(
            currentExercise.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Set ${_currentSetIndex + 1} of ${currentExercise.sets}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),

          // Target vs completed sets
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Show completed sets
                  if (completedSets > 0) ...[
                    const Text(
                      'Completed Sets:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(completedSets, (index) {
                      final set = currentExercise.actualSets[index];
                      return Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Set ${index + 1}'),
                          subtitle: Text('${set.reps} reps × ${set.kg} kg'),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Current set input
                  const Text(
                    'Current Set:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Target: ${currentExercise.reps} reps × ${currentExercise.weight ?? 'bodyweight'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reps Completed',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _kgController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitSet,
                      child: Text(
                        _currentSetIndex + 1 >= currentExercise.sets
                            ? (_currentExerciseIndex + 1 >= _exercises.length 
                                ? 'Finish Exercise' 
                                : 'Next Exercise')
                            : 'Complete Set',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestView() {
    final minutes = _restTimeRemaining ~/ 60;
    final seconds = _restTimeRemaining % 60;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer,
            size: 80,
            color: Colors.orange,
          ),
          const SizedBox(height: 20),
          const Text(
            'Rest Period',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Set ${_currentSetIndex} of ${_exercises[_currentExerciseIndex].sets}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 30),
          
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _skipRest,
                  child: const Text('Skip Rest'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _restTimeRemaining <= 0 ? () {
                    setState(() {
                      _isResting = false;
                    });
                  } : null,
                  child: Text(_restTimeRemaining <= 0 ? 'Continue' : 'Wait...'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.celebration,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 20),
          const Text(
            'Workout Completed!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 10),
          const Text(
            'Great job! Review your results below.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, exerciseIndex) {
                final exercise = _exercises[exerciseIndex];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${exercise.actualSets.length} sets completed'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Results:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...exercise.actualSets.asMap().entries.map((entry) {
                              final setIndex = entry.key;
                              final set = entry.value;
                              final exerciseId = exercise.id;

                              if (_isEditingResults) {
                                // Edit mode - show TextFields
                                return Card(
                                  color: Colors.blue.shade50,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Set ${setIndex + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _editRepsControllers[exerciseId]![setIndex],
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Reps',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _editKgControllers[exerciseId]![setIndex],
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(
                                                  labelText: 'Weight (kg)',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // View mode - show read-only results
                                return ListTile(
                                  leading: const Icon(Icons.check_circle, color: Colors.green),
                                  title: Text('Set ${setIndex + 1}'),
                                  subtitle: Text('${set.reps} reps × ${set.kg} kg'),
                                );
                              }
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          _isEditingResults
            ? Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _toggleEditMode,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancel Edit',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveEditedResults,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleEditMode,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Edit Results',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitCompletedWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Submit to Trainer',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}