import 'package:uuid/uuid.dart';
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
      id: const Uuid().v4(),
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
      _mockTrainings[index] = TrainingModel(
        id: training.id,
        name: training.name,
        description: training.description,
        traineeId: training.traineeId,
        trainerId: training.trainerId,
        exercises: training.exercises,
        scheduledDate: training.scheduledDate,
        isCompleted: true,
        completedAt: DateTime.now(),
        difficulty: training.difficulty,
        estimatedDuration: training.estimatedDuration,
        category: training.category,
        notes: training.notes,
      );
      
      print('=== WORKOUT COMPLETED ===');
      print('Training: ${training.name}');
      print('Completed by trainee ID: ${training.traineeId}');
    }
  }
}