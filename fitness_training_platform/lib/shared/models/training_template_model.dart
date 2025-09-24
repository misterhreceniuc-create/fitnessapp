import 'package:uuid/uuid.dart';
import 'training_model.dart';

// Workout Template - Reusable training programs
class WorkoutTemplate {
  final String id;
  final String name;
  final String description;
  final List<ExerciseTemplate> exercises;
  final String difficulty; // beginner, intermediate, advanced
  final int estimatedDuration; // minutes
  final String category; // strength, cardio, flexibility, etc.
  final String? notes;
  final String createdBy; // trainer ID who created this template
  final DateTime createdAt;
  final bool isPublic; // whether other trainers can use this template
  final List<String> tags; // for easier searching/filtering

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
    required this.createdBy,
    this.difficulty = 'beginner',
    this.estimatedDuration = 60,
    this.category = 'strength',
    this.notes,
    DateTime? createdAt,
    this.isPublic = false,
    this.tags = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  TrainingModel toTrainingModel({
    required String traineeId,
    required DateTime scheduledDate,
    Map<String, Map<String, dynamic>>? exerciseOverrides, // exerciseId -> {sets, reps, weight, notes}
  }) {
    final exerciseModels = exercises.map((template) {
      final overrides = exerciseOverrides?[template.id] ?? {};
      return template.toExerciseModel(
        sets: overrides['sets'] ?? 3,
        reps: overrides['reps'] ?? 10,
        weight: overrides['weight'],
        notes: overrides['notes'],
        restTimeSeconds: overrides['restTimeSeconds'] ?? 60,
      );
    }).toList();

    return TrainingModel(
      id: const Uuid().v4(),
      name: name,
      description: description,
      traineeId: traineeId,
      trainerId: createdBy,
      exercises: exerciseModels,
      scheduledDate: scheduledDate,
      difficulty: difficulty,
      estimatedDuration: estimatedDuration,
      category: category,
      notes: notes,
    );
  }

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<ExerciseTemplate>? exercises,
    String? difficulty,
    int? estimatedDuration,
    String? category,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    bool? isPublic,
    List<String>? tags,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      difficulty: difficulty ?? this.difficulty,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
    );
  }
}