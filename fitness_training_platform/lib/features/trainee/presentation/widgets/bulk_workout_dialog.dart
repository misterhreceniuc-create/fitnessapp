import 'package:flutter/material.dart';
import '../../../../shared/models/training_model.dart';
import '../../../workout/data/exercise_model.dart';
import '../../../../shared/services/exercise_history_service.dart';
import '../../../../shared/models/exercise_history_model.dart';
import '../../../../core/dependency_injection/injection_container.dart';

class BulkWorkoutDialog extends StatefulWidget {
  final TrainingModel training;
  final Function(TrainingModel) onWorkoutUpdated;

  const BulkWorkoutDialog({
    super.key,
    required this.training,
    required this.onWorkoutUpdated,
  });

  @override
  State<BulkWorkoutDialog> createState() => _BulkWorkoutDialogState();
}

class _BulkWorkoutDialogState extends State<BulkWorkoutDialog> {
  late List<ExerciseModel> _exercises;
  late Map<String, List<TextEditingController>> _repsControllers;
  late Map<String, List<TextEditingController>> _kgControllers;
  Map<String, ExerciseHistoryEntry?> _exerciseHistory = {};

  // Services
  final ExerciseHistoryService _historyService = sl.get<ExerciseHistoryService>();

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.training.exercises);
    _initializeControllers();
    _loadExerciseHistory();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _repsControllers = {};
    _kgControllers = {};

    for (final exercise in _exercises) {
      final exerciseId = exercise.id;
      _repsControllers[exerciseId] = [];
      _kgControllers[exerciseId] = [];

      // Create controllers for each set
      for (int setIndex = 0; setIndex < exercise.sets; setIndex++) {
        String repsValue = '';
        String kgValue = '';

        // Pre-fill with existing data if available
        if (setIndex < exercise.actualSets.length) {
          repsValue = exercise.actualSets[setIndex].reps.toString();
          kgValue = exercise.actualSets[setIndex].kg.toString();
        } else {
          // Pre-fill with target values as placeholders
          repsValue = '';
          kgValue = exercise.weight?.toString() ?? '';
        }

        _repsControllers[exerciseId]!.add(TextEditingController(text: repsValue));
        _kgControllers[exerciseId]!.add(TextEditingController(text: kgValue));
      }
    }
  }

  void _disposeControllers() {
    for (final controllers in _repsControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    for (final controllers in _kgControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _loadExerciseHistory() async {
    for (final exercise in _exercises) {
      try {
        final history = await _historyService.getLastExerciseHistory(
          widget.training.traineeId,
          exercise.name,
        );
        if (mounted) {
          setState(() {
            _exerciseHistory[exercise.name] = history;
          });
        }
      } catch (e) {
        print('Error loading history for ${exercise.name}: $e');
      }
    }
  }

  void _saveProgress() {
    // Update exercises with current controller values
    final updatedExercises = <ExerciseModel>[];

    for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
      final exercise = _exercises[exerciseIndex];
      final exerciseId = exercise.id;
      final repsControllers = _repsControllers[exerciseId]!;
      final kgControllers = _kgControllers[exerciseId]!;

      final actualSets = <ActualSet>[];

      // Only add sets that have valid data
      for (int setIndex = 0; setIndex < exercise.sets; setIndex++) {
        final repsText = repsControllers[setIndex].text.trim();
        final kgText = kgControllers[setIndex].text.trim();

        if (repsText.isNotEmpty && kgText.isNotEmpty) {
          final reps = int.tryParse(repsText);
          final kg = double.tryParse(kgText);

          if (reps != null && reps > 0 && kg != null && kg >= 0) {
            actualSets.add(ActualSet(reps: reps, kg: kg));
          }
        }
      }

      updatedExercises.add(exercise.copyWith(actualSets: actualSets));
    }

    _exercises = updatedExercises;
    final updatedTraining = widget.training.copyWith(exercises: _exercises);
    widget.onWorkoutUpdated(updatedTraining);
  }

  void _validateAndCompleteWorkout() {
    // Check if all fields are filled
    List<String> missingFields = [];

    for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
      final exercise = _exercises[exerciseIndex];
      final exerciseId = exercise.id;
      final repsControllers = _repsControllers[exerciseId]!;
      final kgControllers = _kgControllers[exerciseId]!;

      for (int setIndex = 0; setIndex < exercise.sets; setIndex++) {
        final repsText = repsControllers[setIndex].text.trim();
        final kgText = kgControllers[setIndex].text.trim();

        if (repsText.isEmpty || kgText.isEmpty) {
          missingFields.add('${exercise.name} - Set ${setIndex + 1}');
        } else {
          final reps = int.tryParse(repsText);
          final kg = double.tryParse(kgText);

          if (reps == null || reps <= 0) {
            missingFields.add('${exercise.name} - Set ${setIndex + 1} (invalid reps)');
          }
          if (kg == null || kg < 0) {
            missingFields.add('${exercise.name} - Set ${setIndex + 1} (invalid weight)');
          }
        }
      }
    }

    if (missingFields.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Workout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please complete the following fields:'),
              const SizedBox(height: 10),
              ...missingFields.take(5).map((field) => Text('• $field')),
              if (missingFields.length > 5)
                Text('... and ${missingFields.length - 5} more'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Save progress and complete workout
    _saveProgress();
    _completeWorkout();
  }

  void _completeWorkout() async {
    final completedTraining = widget.training.copyWith(
      exercises: _exercises,
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    // Save exercise history
    try {
      await _historyService.saveTrainingHistory(completedTraining);
      print('✅ Exercise history saved successfully');
    } catch (e) {
      print('❌ Error saving exercise history: $e');
    }

    widget.onWorkoutUpdated(completedTraining);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout completed and submitted to trainer!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.training.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'All-at-Once Mode',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
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

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fill out all exercises at your own pace. No timers or rest periods.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, exerciseIndex) {
                final exercise = _exercises[exerciseIndex];
                return _buildExerciseCard(exercise, exerciseIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise, int exerciseIndex) {
    final exerciseId = exercise.id;
    final repsControllers = _repsControllers[exerciseId]!;
    final kgControllers = _kgControllers[exerciseId]!;
    final history = _exerciseHistory[exercise.name];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(N
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercise.sets} sets',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (exercise.instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exercise.instructions,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'Target: ${exercise.reps} reps × ${exercise.weight != null ? '${exercise.weight} kg' : 'bodyweight'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Show previous performance if available
            if (history != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Performance:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: history.actualSets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        return Text(
                          'Set ${index + 1}: ${set.reps}×${set.kg}kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                          ),
                        );
                      }).toList(),
                    ),
                    Text(
                      'Max: ${history.maxReps} reps × ${history.maxWeight.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Sets input
            ...List.generate(exercise.sets, (setIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Set ${setIndex + 1}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: repsControllers[setIndex],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _saveProgress(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: kgControllers[setIndex],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _saveProgress(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _saveProgress();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Save & Exit',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _validateAndCompleteWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Complete Workout',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}