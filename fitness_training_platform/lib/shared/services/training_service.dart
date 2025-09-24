import '../models/training_model.dart';

class TrainingService {
  final List<TrainingModel> _mockTrainings = [];

  Future<List<TrainingModel>> getTrainingsForTrainee(String traineeId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    print('=== TRAINING SERVICE DEBUG ===');
    print('Looking for trainings for trainee ID: $traineeId');
    print('Total trainings in system: ${_mockTrainings.length}');
    
    for (var training in _mockTrainings) {
      print('- Training "${training.name}" assigned to: ${training.traineeId}');
    }
    
    final trainings = _mockTrainings.where((training) => training.traineeId == traineeId).toList();
    print('Found ${trainings.length} matching trainings');
    
    return trainings;
  }

  Future<List<TrainingModel>> getTrainingsForTrainer(String trainerId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockTrainings.where((training) => training.trainerId == trainerId).toList();
  }

  Future<TrainingModel> createTraining(TrainingModel training) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newTraining = TrainingModel(
      id: training.id, // Use the provided ID to maintain consistency
      name: training.name,
      description: training.description,
      traineeId: training.traineeId,
      trainerId: training.trainerId,
      exercises: training.exercises,
      scheduledDate: training.scheduledDate,
      difficulty: training.difficulty,
      estimatedDuration: training.estimatedDuration,
      category: training.category,
      notes: training.notes,
      recurrenceGroupId: training.recurrenceGroupId,
      recurrenceIndex: training.recurrenceIndex,
      totalRecurrences: training.totalRecurrences,
    );
    
    _mockTrainings.add(newTraining);
    
    print('=== WORKOUT CREATED ===');
    print('Training: ${newTraining.name}');
    print('Assigned to trainee ID: ${newTraining.traineeId}');
    print('Created by trainer ID: ${newTraining.trainerId}');
    print('Total trainings now: ${_mockTrainings.length}');
    
    return newTraining;
  }

  Future<TrainingModel> updateTraining(TrainingModel training) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockTrainings.indexWhere((t) => t.id == training.id);
    if (index != -1) {
      _mockTrainings[index] = training;
    }
    return training;
  }

  Future<void> completeTraining(String trainingId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockTrainings.indexWhere((t) => t.id == trainingId);
    if (index != -1) {
      final training = _mockTrainings[index];
      _mockTrainings[index] = training.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      print('=== WORKOUT COMPLETED ===');
      print('Training: ${training.name}');
      print('Completed by trainee ID: ${training.traineeId}');
    }
  }

  Future<List<TrainingModel>> updateRecurrenceGroup(String recurrenceGroupId, TrainingModel templateTraining) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final updatedTrainings = <TrainingModel>[];

    for (int i = 0; i < _mockTrainings.length; i++) {
      final training = _mockTrainings[i];
      if (training.recurrenceGroupId == recurrenceGroupId) {
        // Update all fields except the ones that should remain unique per instance
        final updated = training.copyWith(
          name: templateTraining.name,
          description: templateTraining.description,
          exercises: templateTraining.exercises,
          difficulty: templateTraining.difficulty,
          estimatedDuration: templateTraining.estimatedDuration,
          category: templateTraining.category,
          notes: templateTraining.notes,
          // Keep original scheduledDate, id, recurrence fields, completion status
        );
        _mockTrainings[i] = updated;
        updatedTrainings.add(updated);
      }
    }

    return updatedTrainings;
  }

  Future<List<TrainingModel>> getTrainingsByRecurrenceGroup(String recurrenceGroupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockTrainings.where((t) => t.recurrenceGroupId == recurrenceGroupId).toList();
  }

  Future<void> deleteTraining(String trainingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockTrainings.removeWhere((t) => t.id == trainingId);
  }

  Future<List<String>> deleteRecurrenceGroup(String recurrenceGroupId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final deletedIds = <String>[];

    _mockTrainings.removeWhere((training) {
      if (training.recurrenceGroupId == recurrenceGroupId) {
        deletedIds.add(training.id);
        return true;
      }
      return false;
    });

    return deletedIds;
  }
}