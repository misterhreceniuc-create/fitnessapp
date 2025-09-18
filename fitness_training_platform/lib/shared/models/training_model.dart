import 'package:uuid/uuid.dart';

class TrainingModel {
  final String id;
  final String name;
  final String description;
  final String traineeId;
  final String trainerId;
  final List<ExerciseModel> exercises;
  final DateTime scheduledDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String difficulty; // beginner, intermediate, advanced
  final int estimatedDuration; // minutes
  final String category; // strength, cardio, flexibility, etc.
  final String? notes;

  TrainingModel({
    required this.id,
    required this.name,
    required this.description,
    required this.traineeId,
    required this.trainerId,
    required this.exercises,
    required this.scheduledDate,
    this.isCompleted = false,
    this.completedAt,
    this.difficulty = 'beginner',
    this.estimatedDuration = 30,
    this.category = 'strength',
    this.notes,
  });

  factory TrainingModel.fromJson(Map<String, dynamic> json) {
    return TrainingModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      traineeId: json['traineeId'],
      trainerId: json['trainerId'],
      exercises: (json['exercises'] as List)
          .map((e) => ExerciseModel.fromJson(e))
          .toList(),
      scheduledDate: DateTime.parse(json['scheduledDate']),
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      difficulty: json['difficulty'] ?? 'beginner',
      estimatedDuration: json['estimatedDuration'] ?? 30,
      category: json['category'] ?? 'strength',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'traineeId': traineeId,
      'trainerId': trainerId,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'scheduledDate': scheduledDate.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'difficulty': difficulty,
      'estimatedDuration': estimatedDuration,
      'category': category,
      'notes': notes,
    };
  }

  TrainingModel copyWith({
    String? id,
    String? name,
    String? description,
    String? traineeId,
    String? trainerId,
    List<ExerciseModel>? exercises,
    DateTime? scheduledDate,
    bool? isCompleted,
    DateTime? completedAt,
    String? difficulty,
    int? estimatedDuration,
    String? category,
    String? notes,
  }) {
    return TrainingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      traineeId: traineeId ?? this.traineeId,
      trainerId: trainerId ?? this.trainerId,
      exercises: exercises ?? this.exercises,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      difficulty: difficulty ?? this.difficulty,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }
}

class ExerciseModel {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double? weight;
  final String? notes;
  final bool isCompleted;
  final double? actualWeight;
  final int? actualReps;
  final String category; // strength, cardio, flexibility
  final String targetMuscle; // chest, legs, back, etc.
  final String equipment; // barbell, dumbbell, bodyweight, etc.
  final String instructions;
  final int restTimeSeconds;

  ExerciseModel({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
    this.notes,
    this.isCompleted = false,
    this.actualWeight,
    this.actualReps,
    this.category = 'strength',
    this.targetMuscle = 'general',
    this.equipment = 'bodyweight',
    this.instructions = '',
    this.restTimeSeconds = 60,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'],
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],
      weight: json['weight']?.toDouble(),
      notes: json['notes'],
      isCompleted: json['isCompleted'] ?? false,
      actualWeight: json['actualWeight']?.toDouble(),
      actualReps: json['actualReps'],
      category: json['category'] ?? 'strength',
      targetMuscle: json['targetMuscle'] ?? 'general',
      equipment: json['equipment'] ?? 'bodyweight',
      instructions: json['instructions'] ?? '',
      restTimeSeconds: json['restTimeSeconds'] ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
      'isCompleted': isCompleted,
      'actualWeight': actualWeight,
      'actualReps': actualReps,
      'category': category,
      'targetMuscle': targetMuscle,
      'equipment': equipment,
      'instructions': instructions,
      'restTimeSeconds': restTimeSeconds,
    };
  }

  ExerciseModel copyWith({
    bool? isCompleted,
    double? actualWeight,
    int? actualReps,
    String? notes,
  }) {
    return ExerciseModel(
      id: id,
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      actualWeight: actualWeight ?? this.actualWeight,
      actualReps: actualReps ?? this.actualReps,
      category: category,
      targetMuscle: targetMuscle,
      equipment: equipment,
      instructions: instructions,
      restTimeSeconds: restTimeSeconds,
    );
  }
}

// Exercise Library - Pre-defined exercises trainers can choose from
class ExerciseTemplate {
  final String id;
  final String name;
  final String category;
  final String targetMuscle;
  final String equipment;
  final String instructions;
  final String difficultyLevel;
  final List<String> tips;

  ExerciseTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.targetMuscle,
    required this.equipment,
    required this.instructions,
    required this.difficultyLevel,
    this.tips = const [],
  });

  ExerciseModel toExerciseModel({
    required int sets,
    required int reps,
    double? weight,
    String? notes,
    int restTimeSeconds = 60,
  }) {
    return ExerciseModel(
      id: const Uuid().v4(),
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      notes: notes,
      category: category,
      targetMuscle: targetMuscle,
      equipment: equipment,
      instructions: instructions,
      restTimeSeconds: restTimeSeconds,
    );
  }
}