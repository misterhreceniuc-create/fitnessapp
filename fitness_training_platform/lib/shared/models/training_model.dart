/// @file training_model.dart
/// @brief Core data models for workout training sessions and exercises
/// @details This file contains the primary data models used throughout the fitness
/// training platform for managing workout sessions, exercises, and exercise templates.
/// It defines the structure for workout assignments, exercise specifications, and
/// pre-defined exercise templates that trainers can use to build training programs.
/// All models support JSON serialization for data persistence and API communication.

import 'package:uuid/uuid.dart';
import '../../features/workout/data/exercise_model.dart';

/// @class TrainingModel
/// @brief Represents a complete workout training session assigned to a trainee
/// @details This model encapsulates all information about a workout assignment including
/// the exercises to be performed, scheduling details, completion status, and metadata
/// like difficulty and category. It supports both single and recurring workout schedules
/// through recurrence fields. Each training session belongs to one trainee and is created
/// by one trainer. The model tracks both planned exercises and their completion status.
class TrainingModel {
  /// @brief Unique identifier for this training session
  final String id;

  /// @brief Display name of the workout (e.g., "Upper Body Strength")
  final String name;

  /// @brief Detailed description of the workout's purpose and goals
  final String description;

  /// @brief ID of the trainee who will perform this workout
  final String traineeId;

  /// @brief ID of the trainer who created this workout
  final String trainerId;

  /// @brief List of exercises to be performed in this training session
  final List<ExerciseModel> exercises;

  /// @brief Date and time when this workout is scheduled to be performed
  final DateTime scheduledDate;

  /// @brief Flag indicating if the trainee has completed this workout
  final bool isCompleted;

  /// @brief Timestamp of when the workout was marked as completed (null if not completed)
  final DateTime? completedAt;

  /// @brief Difficulty level of the workout (beginner, intermediate, advanced)
  final String difficulty;

  /// @brief Estimated time in minutes to complete this workout
  final int estimatedDuration;

  /// @brief Category of workout (strength, cardio, flexibility, etc.)
  final String category;

  /// @brief Optional additional notes or instructions for the trainee
  final String? notes;

  /// @brief Unique identifier linking related recurring workouts together
  /// @details All workouts in a recurring series share the same recurrenceGroupId.
  /// Null for non-recurring (one-time) workouts.
  final String? recurrenceGroupId;

  /// @brief Position of this workout in the recurring series (0-indexed)
  /// @details For example, 0 = first occurrence, 1 = second occurrence, etc.
  /// Null for non-recurring workouts.
  final int? recurrenceIndex;

  /// @brief Total number of workouts in the recurring series
  /// @details Indicates how many times this workout will repeat.
  /// Null for non-recurring workouts.
  final int? totalRecurrences;

  /// @brief Constructor for creating a TrainingModel instance
  /// @details Creates a new training model with all required and optional parameters.
  /// Provides sensible defaults for difficulty (beginner), duration (60 minutes),
  /// and category (strength) when not specified.
  /// @param id Unique identifier for the training session
  /// @param name Display name of the workout
  /// @param description Detailed description of the workout
  /// @param traineeId ID of the trainee assigned to this workout
  /// @param trainerId ID of the trainer who created this workout
  /// @param exercises List of exercises in this training session
  /// @param scheduledDate When the workout is scheduled
  /// @param isCompleted Whether the workout has been completed (default: false)
  /// @param completedAt When the workout was completed (optional)
  /// @param difficulty Difficulty level (default: 'beginner')
  /// @param estimatedDuration Duration in minutes (default: 60)
  /// @param category Workout category (default: 'strength')
  /// @param notes Additional notes (optional)
  /// @param recurrenceGroupId Links recurring workouts (optional)
  /// @param recurrenceIndex Position in recurring series (optional)
  /// @param totalRecurrences Total occurrences in series (optional)
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
    this.estimatedDuration = 60,
    this.category = 'strength',
    this.notes,
    this.recurrenceGroupId,
    this.recurrenceIndex,
    this.totalRecurrences,
  });

  /// @brief Creates a copy of this model with specified fields replaced
  /// @details Implements the immutable update pattern. Returns a new TrainingModel
  /// instance with the provided values replacing the original values. All parameters
  /// are optional; unspecified fields retain their original values.
  /// @param id New unique identifier (optional)
  /// @param name New workout name (optional)
  /// @param description New description (optional)
  /// @param traineeId New trainee ID (optional)
  /// @param trainerId New trainer ID (optional)
  /// @param exercises New exercise list (optional)
  /// @param scheduledDate New scheduled date (optional)
  /// @param isCompleted New completion status (optional)
  /// @param completedAt New completion timestamp (optional)
  /// @param difficulty New difficulty level (optional)
  /// @param estimatedDuration New duration estimate (optional)
  /// @param category New category (optional)
  /// @param notes New notes (optional)
  /// @param recurrenceGroupId New recurrence group ID (optional)
  /// @param recurrenceIndex New recurrence index (optional)
  /// @param totalRecurrences New total recurrences (optional)
  /// @return A new TrainingModel with updated values
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
    String? recurrenceGroupId,
    int? recurrenceIndex,
    int? totalRecurrences,
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
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      recurrenceIndex: recurrenceIndex ?? this.recurrenceIndex,
      totalRecurrences: totalRecurrences ?? this.totalRecurrences,
    );
  }

  /// @brief Checks if this workout is part of a recurring series
  /// @details Determines recurrence status by checking if recurrenceGroupId is set.
  /// @return true if this is a recurring workout, false for one-time workouts
  bool get isRecurring => recurrenceGroupId != null;

  /// @brief Generates a human-readable display text for recurrence information
  /// @details Creates text like "2 of 5" to show the workout's position in a series.
  /// Returns empty string for non-recurring workouts.
  /// @return Display text showing "X of Y" format, or empty string if not recurring
  String get recurrenceDisplayText {
    if (!isRecurring) return '';
    return '${(recurrenceIndex ?? 0) + 1} of ${totalRecurrences ?? 1}';
  }

  /// @brief Factory constructor to create a TrainingModel from JSON data
  /// @details Deserializes a JSON map into a TrainingModel instance. Handles type
  /// conversions for dates, lists, and nullable fields. Provides default values
  /// for optional fields when not present in JSON. The exercises list is mapped
  /// from JSON array to ExerciseModel objects.
  /// @param json Map containing the serialized training data
  /// @return A new TrainingModel instance populated with data from JSON
  factory TrainingModel.fromJson(Map<String, dynamic> json) {
    return TrainingModel(
      // Extract basic identifiers and metadata
      id: json['id'],
      name: json['name'],
      description: json['description'],
      traineeId: json['traineeId'],
      trainerId: json['trainerId'],

      // Deserialize the exercises array by mapping each JSON object to ExerciseModel
      exercises: (json['exercises'] as List)
          .map((e) => ExerciseModel.fromJson(e))
          .toList(),

      // Parse ISO8601 date string to DateTime object
      scheduledDate: DateTime.parse(json['scheduledDate']),

      // Use default values if optional fields are missing
      isCompleted: json['isCompleted'] ?? false,

      // Conditionally parse completedAt timestamp (null if not present)
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,

      // Apply defaults for workout metadata
      difficulty: json['difficulty'] ?? 'beginner',
      estimatedDuration: json['estimatedDuration'] ?? 60,
      category: json['category'] ?? 'strength',

      // Optional fields for notes and recurrence
      notes: json['notes'],
      recurrenceGroupId: json['recurrenceGroupId'],
      recurrenceIndex: json['recurrenceIndex'],
      totalRecurrences: json['totalRecurrences'],
    );
  }

  /// @brief Converts this TrainingModel to a JSON map
  /// @details Serializes all fields to a JSON-compatible map structure. Converts
  /// DateTime objects to ISO8601 strings and nested ExerciseModel objects to JSON.
  /// Includes all fields, even nullable ones (with null values preserved).
  /// @return Map containing all training data in JSON-serializable format
  Map<String, dynamic> toJson() {
    return {
      // Serialize basic fields directly
      'id': id,
      'name': name,
      'description': description,
      'traineeId': traineeId,
      'trainerId': trainerId,

      // Map each exercise to JSON format
      'exercises': exercises.map((e) => e.toJson()).toList(),

      // Convert DateTime objects to ISO8601 strings for JSON compatibility
      'scheduledDate': scheduledDate.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(), // Null-safe conversion

      // Include workout metadata
      'difficulty': difficulty,
      'estimatedDuration': estimatedDuration,
      'category': category,

      // Optional fields (may be null)
      'notes': notes,
      'recurrenceGroupId': recurrenceGroupId,
      'recurrenceIndex': recurrenceIndex,
      'totalRecurrences': totalRecurrences,
    };
  }
}

/// @class ExerciseModel
/// @brief Represents a single exercise within a training session
/// @details Defines an exercise with its planned parameters (sets, reps, weight) and
/// tracks actual performance through actualSets, actualWeight, and actualReps. Each
/// exercise includes metadata like category, target muscle, equipment type, and
/// instructions. The model supports tracking completion status and includes rest time
/// between sets. Used both for planning workouts and recording trainee performance.
class ExerciseModel {
  /// @brief Unique identifier for this exercise instance
  final String id;

  /// @brief Name of the exercise (e.g., "Bench Press", "Squats")
  final String name;

  /// @brief Planned number of sets to perform
  final int sets;

  /// @brief Planned number of repetitions per set
  final int reps;

  /// @brief Planned weight to use in kilograms (null for bodyweight exercises)
  final double? weight;

  /// @brief Optional notes or instructions specific to this exercise instance
  final String? notes;

  /// @brief Flag indicating if the trainee has completed this exercise
  final bool isCompleted;

  /// @brief Actual weight used by trainee (may differ from planned weight)
  final double? actualWeight;

  /// @brief Actual repetitions performed (may differ from planned reps)
  final int? actualReps;

  /// @brief List of actual sets performed with detailed reps and weight per set
  /// @details Each ActualSet contains the specific reps and kg for that set,
  /// allowing precise tracking of performance variations across sets
  final List<ActualSet> actualSets;

  /// @brief Category of exercise (strength, cardio, flexibility)
  final String category;

  /// @brief Primary muscle group targeted (chest, legs, back, shoulders, etc.)
  final String targetMuscle;

  /// @brief Equipment required (barbell, dumbbell, bodyweight, machine, etc.)
  final String equipment;

  /// @brief Detailed instructions on how to perform the exercise correctly
  final String instructions;

  /// @brief Rest time in seconds between sets
  final int restTimeSeconds;

  /// @brief Constructor for creating an ExerciseModel instance
  /// @details Creates a new exercise with planned parameters and optional actual
  /// performance data. Initializes actualSets as empty list if not provided.
  /// Provides default values for category, targetMuscle, equipment, instructions,
  /// and rest time when not specified.
  /// @param id Unique identifier for the exercise
  /// @param name Name of the exercise
  /// @param sets Number of sets to perform
  /// @param reps Repetitions per set
  /// @param weight Weight in kilograms (optional, null for bodyweight)
  /// @param notes Additional notes (optional)
  /// @param isCompleted Completion status (default: false)
  /// @param actualWeight Weight actually used (optional)
  /// @param actualReps Reps actually performed (optional)
  /// @param actualSets Detailed per-set performance data (default: empty list)
  /// @param category Exercise category (default: 'strength')
  /// @param targetMuscle Target muscle group (default: 'general')
  /// @param equipment Required equipment (default: 'bodyweight')
  /// @param instructions How to perform the exercise (default: empty string)
  /// @param restTimeSeconds Rest between sets (default: 60)
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
    List<ActualSet>? actualSets,
    this.category = 'strength',
    this.targetMuscle = 'general',
    this.equipment = 'bodyweight',
    this.instructions = '',
    this.restTimeSeconds = 60,
  }) : actualSets = actualSets ?? []; // Initialize empty list if not provided

  /// @brief Factory constructor to create an ExerciseModel from JSON data
  /// @details Deserializes a JSON map into an ExerciseModel instance. Handles type
  /// conversions for numeric fields (weight, actualWeight) ensuring they are doubles.
  /// Deserializes the actualSets list by mapping each JSON object to ActualSet.
  /// Provides default values for optional fields when not present in JSON.
  /// @param json Map containing the serialized exercise data
  /// @return A new ExerciseModel instance populated with data from JSON
  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      // Extract basic identifiers and planned parameters
      id: json['id'],
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],

      // Convert numeric weight values to double (handles both int and double from JSON)
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      notes: json['notes'],
      isCompleted: json['isCompleted'] ?? false,

      // Handle actual performance data with type conversion
      actualWeight: json['actualWeight'] != null ? (json['actualWeight'] as num).toDouble() : null,
      actualReps: json['actualReps'],

      // Deserialize actualSets array, defaulting to empty list if not present
      actualSets: json['actualSets'] != null
          ? (json['actualSets'] as List).map((e) => ActualSet.fromJson(e)).toList()
          : [],

      // Apply default values for exercise metadata
      category: json['category'] ?? 'strength',
      targetMuscle: json['targetMuscle'] ?? 'general',
      equipment: json['equipment'] ?? 'bodyweight',
      instructions: json['instructions'] ?? '',
      restTimeSeconds: json['restTimeSeconds'] ?? 60,
    );
  }

  /// @brief Converts this ExerciseModel to a JSON map
  /// @details Serializes all fields to a JSON-compatible map structure. Maps the
  /// actualSets list to JSON array format. All numeric and string fields are
  /// included directly, with nullable fields preserved as null.
  /// @return Map containing all exercise data in JSON-serializable format
  Map<String, dynamic> toJson() {
    return {
      // Serialize identifiers and basic parameters
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,

      // Include completion tracking
      'isCompleted': isCompleted,

      // Serialize actual performance data
      'actualWeight': actualWeight,
      'actualReps': actualReps,

      // Map actualSets to JSON array format
      'actualSets': actualSets.map((e) => e.toJson()).toList(),

      // Include exercise metadata
      'category': category,
      'targetMuscle': targetMuscle,
      'equipment': equipment,
      'instructions': instructions,
      'restTimeSeconds': restTimeSeconds,
    };
  }

  /// @brief Creates a copy of this model with specified fields replaced
  /// @details Implements the immutable update pattern for exercise data. Returns a
  /// new ExerciseModel with the provided values replacing the original values.
  /// This method is primarily used to update completion status and actual performance
  /// data after a trainee completes the exercise. Unmodifiable fields (id, name, sets,
  /// reps, weight, category, etc.) retain their original values.
  /// @param isCompleted New completion status (optional)
  /// @param actualWeight Weight actually used (optional)
  /// @param actualReps Reps actually performed (optional)
  /// @param notes Updated notes (optional)
  /// @param actualSets Updated per-set performance data (optional)
  /// @return A new ExerciseModel with updated values
  ExerciseModel copyWith({
    bool? isCompleted,
    double? actualWeight,
    int? actualReps,
    String? notes,
    List<ActualSet>? actualSets,
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
      actualSets: actualSets ?? this.actualSets,
      category: category,
      targetMuscle: targetMuscle,
      equipment: equipment,
      instructions: instructions,
      restTimeSeconds: restTimeSeconds,
    );
  }
}

/// @class ExerciseTemplate
/// @brief Pre-defined exercise template in the exercise library
/// @details Represents a reusable exercise definition that trainers can select when
/// creating workouts. Contains all the metadata and instructions for an exercise but
/// not the workout-specific parameters like sets, reps, and weight. Supports both
/// system-provided exercises and custom exercises created by trainers. Can be
/// converted to an ExerciseModel when added to a training session by specifying
/// the workout parameters (sets, reps, weight).
class ExerciseTemplate {
  /// @brief Unique identifier for this exercise template
  final String id;

  /// @brief Name of the exercise (e.g., "Bench Press", "Pull-ups")
  final String name;

  /// @brief Category of exercise (strength, cardio, flexibility)
  final String category;

  /// @brief Primary muscle group targeted by this exercise
  final String targetMuscle;

  /// @brief Equipment required to perform this exercise
  final String equipment;

  /// @brief Detailed step-by-step instructions for proper form and execution
  final String instructions;

  /// @brief Difficulty rating (beginner, intermediate, advanced)
  final String difficultyLevel;

  /// @brief List of helpful tips for performing the exercise safely and effectively
  final List<String> tips;

  /// @brief Optional URL to a video demonstration of the exercise
  final String? videoUrl;

  /// @brief ID of the trainer who created this custom exercise (null for system exercises)
  final String? createdBy;

  /// @brief Flag indicating if this is a custom exercise created by a trainer
  /// @details false for system-provided exercises, true for trainer-created exercises
  final bool isCustom;

  /// @brief Constructor for creating an ExerciseTemplate instance
  /// @details Creates a new exercise template with all its metadata. Used to define
  /// exercises in the exercise library that trainers can select from when building
  /// workouts. Tips default to empty list and isCustom defaults to false if not specified.
  /// @param id Unique identifier for the template
  /// @param name Name of the exercise
  /// @param category Exercise category (strength, cardio, flexibility)
  /// @param targetMuscle Primary muscle group targeted
  /// @param equipment Required equipment
  /// @param instructions How to perform the exercise
  /// @param difficultyLevel Difficulty rating
  /// @param tips List of helpful tips (default: empty list)
  /// @param videoUrl URL to demonstration video (optional)
  /// @param createdBy ID of trainer who created this (optional, null for system exercises)
  /// @param isCustom Whether this is a custom exercise (default: false)
  ExerciseTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.targetMuscle,
    required this.equipment,
    required this.instructions,
    required this.difficultyLevel,
    this.tips = const [],
    this.videoUrl,
    this.createdBy,
    this.isCustom = false,
  });

  /// @brief Converts this template to an ExerciseModel for use in a workout
  /// @details Creates a new ExerciseModel instance from this template by combining
  /// the template's metadata (category, targetMuscle, equipment, instructions) with
  /// workout-specific parameters (sets, reps, weight). Generates a new unique ID
  /// using UUID v4. This method is used when a trainer selects an exercise from
  /// the library and adds it to a training session.
  /// @param sets Number of sets for this workout instance
  /// @param reps Number of repetitions per set
  /// @param weight Weight to use in kilograms (optional, null for bodyweight)
  /// @param notes Additional notes for this specific workout instance (optional)
  /// @param restTimeSeconds Rest time between sets (default: 60 seconds)
  /// @return A new ExerciseModel ready to be added to a TrainingModel
  ExerciseModel toExerciseModel({
    required int sets,
    required int reps,
    double? weight,
    String? notes,
    int restTimeSeconds = 60,
  }) {
    // Generate a new unique ID for the exercise instance
    return ExerciseModel(
      id: const Uuid().v4(),
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      notes: notes,
      // Copy metadata from template
      category: category,
      targetMuscle: targetMuscle,
      equipment: equipment,
      instructions: instructions,
      restTimeSeconds: restTimeSeconds,
    );
  }
}