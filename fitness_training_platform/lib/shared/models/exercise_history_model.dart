/// @file exercise_history_model.dart
/// @brief Data models for tracking exercise performance history and progress comparisons
/// @details This file contains three primary data models for the exercise history tracking system:
/// ExerciseHistoryEntry (individual exercise completion records), ExerciseProgressComparison
/// (comparison between current and previous performance), and TrainingProgressReport (aggregate
/// progress report for an entire training session). These models support the trainer's ability
/// to monitor trainee progress over time through detailed performance metrics like weight, reps,
/// volume, and improvement percentages. Used extensively in progress tracking and reporting features.

import '../../features/workout/data/exercise_model.dart';

/// @class ExerciseHistoryEntry
/// @brief Records a completed exercise's performance data for history tracking
/// @details Captures all performance details when a trainee completes an exercise within
/// a training session. Stores the actualSets (reps and weight per set), timestamp, and
/// relationships to the trainee and training. Provides helper getters for calculating
/// performance metrics: maxWeight, maxReps, totalVolume, and totalReps. Used to build
/// historical performance timelines for progress tracking and comparing current performance
/// against previous sessions. Each entry is immutable once created and persisted in
/// ExerciseHistoryService for long-term storage and retrieval.
class ExerciseHistoryEntry {
  /// @brief Unique identifier for this history entry
  final String id;

  /// @brief Name of the exercise performed (e.g., "Bench Press", "Squats")
  final String exerciseName;

  /// @brief ID of the trainee who performed this exercise
  final String traineeId;

  /// @brief ID of the training session this exercise was part of
  final String trainingId;

  /// @brief Timestamp when this exercise was completed
  final DateTime completedAt;

  /// @brief List of actual sets performed with reps and weight data
  /// @details Each ActualSet contains the specific reps and kg for that set,
  /// enabling precise performance tracking and volume calculations
  final List<ActualSet> actualSets;

  /// @brief Optional notes about the exercise performance
  /// @details May include trainee feedback, form notes, or observations
  final String? notes;

  /// @brief Constructor for ExerciseHistoryEntry
  /// @details Creates a new history entry with all required performance data
  /// @param id Unique identifier for the entry
  /// @param exerciseName Name of the exercise
  /// @param traineeId ID of the trainee
  /// @param trainingId ID of the training session
  /// @param completedAt Completion timestamp
  /// @param actualSets List of sets with reps and weight
  /// @param notes Optional performance notes
  ExerciseHistoryEntry({
    required this.id,
    required this.exerciseName,
    required this.traineeId,
    required this.trainingId,
    required this.completedAt,
    required this.actualSets,
    this.notes,
  });

  /// @brief Factory constructor to create an ExerciseHistoryEntry from JSON data
  /// @details Deserializes a JSON map into an ExerciseHistoryEntry. Parses the
  /// completedAt timestamp from ISO 8601 string and deserializes the actualSets list
  /// by mapping each JSON object to ActualSet. Used for loading history from storage.
  /// @param json Map containing the serialized history entry data
  /// @return A new ExerciseHistoryEntry instance populated with data from JSON
  factory ExerciseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryEntry(
      id: json['id'],
      exerciseName: json['exerciseName'],
      traineeId: json['traineeId'],
      trainingId: json['trainingId'],
      completedAt: DateTime.parse(json['completedAt']),
      actualSets: (json['actualSets'] as List)
          .map((e) => ActualSet.fromJson(e))
          .toList(),
      notes: json['notes'],
    );
  }

  /// @brief Converts this ExerciseHistoryEntry to a JSON map
  /// @details Serializes all fields to a JSON-compatible map structure. Converts
  /// the DateTime to ISO 8601 string and maps actualSets to JSON array format.
  /// Used for persisting history to storage.
  /// @return Map containing all history data in JSON-serializable format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'traineeId': traineeId,
      'trainingId': trainingId,
      'completedAt': completedAt.toIso8601String(),
      'actualSets': actualSets.map((e) => e.toJson()).toList(),
      'notes': notes,
    };
  }

  /// @brief Calculates the maximum weight used across all sets
  /// @details Finds the highest kg value from all actualSets. Returns 0.0 if
  /// no sets were recorded. Used for tracking personal records and strength progress.
  /// @return The maximum weight in kg, or 0.0 if no sets exist
  double get maxWeight => actualSets.isNotEmpty
      ? actualSets.map((s) => s.kg).reduce((a, b) => a > b ? a : b)
      : 0.0;

  /// @brief Calculates the maximum reps performed in a single set
  /// @details Finds the highest reps value from all actualSets. Returns 0 if
  /// no sets were recorded. Used for tracking endurance and rep records.
  /// @return The maximum reps, or 0 if no sets exist
  int get maxReps => actualSets.isNotEmpty
      ? actualSets.map((s) => s.reps).reduce((a, b) => a > b ? a : b)
      : 0;

  /// @brief Calculates the total volume (weight × reps) across all sets
  /// @details Sums up (kg × reps) for each set to compute total workout volume.
  /// Volume is a key metric for tracking overall workout intensity and progress.
  /// @return Total volume in kg·reps
  double get totalVolume => actualSets.fold(0.0, (sum, set) => sum + (set.kg * set.reps));

  /// @brief Calculates the total number of reps performed across all sets
  /// @details Sums up all reps from every set. Used for tracking workout density
  /// and overall work capacity.
  /// @return Total reps performed
  int get totalReps => actualSets.fold(0, (sum, set) => sum + set.reps);
}

/// @class ExerciseProgressComparison
/// @brief Compares current exercise performance against previous historical performance
/// @details Encapsulates both current and previous performance data for a single exercise,
/// providing calculated progress metrics (weight, reps, volume improvements) and descriptive
/// summaries. Used to generate detailed progress reports showing how trainees have improved
/// since their last performance of the same exercise. Supports percentage-based progress
/// tracking and human-readable improvement descriptions for trainer and trainee feedback.
class ExerciseProgressComparison {
  /// @brief Name of the exercise being compared
  final String exerciseName;

  /// @brief Previous historical performance for this exercise
  /// @details Null if this is the trainee's first time performing this exercise.
  /// When present, enables calculation of progress metrics.
  final ExerciseHistoryEntry? previous;

  /// @brief Current actual sets performed in this session
  final List<ActualSet> current;

  /// @brief Date of the current performance
  final DateTime currentDate;

  /// @brief Constructor for ExerciseProgressComparison
  /// @details Creates a comparison object with current and optional previous data
  /// @param exerciseName Name of the exercise
  /// @param previous Previous performance (null if first time)
  /// @param current Current performance sets
  /// @param currentDate Timestamp of current performance
  ExerciseProgressComparison({
    required this.exerciseName,
    this.previous,
    required this.current,
    required this.currentDate,
  });

  /// @brief Calculates absolute weight progress (current max - previous max)
  /// @details Returns the difference in kg between the current maximum weight
  /// and the previous maximum weight. Positive values indicate improvement,
  /// negative values indicate decrease, and 0 indicates maintained performance.
  /// Returns 0.0 if no previous data exists or current sets are empty.
  /// @return Weight progress in kg (can be positive, negative, or zero)
  double get weightProgress {
    if (previous == null || current.isEmpty) return 0.0;
    final currentMax = current.map((s) => s.kg).reduce((a, b) => a > b ? a : b);
    return currentMax - previous!.maxWeight;
  }

  /// @brief Calculates absolute reps progress (current max - previous max)
  /// @details Returns the difference in reps between the current maximum reps
  /// and the previous maximum reps. Positive values indicate endurance improvement.
  /// Returns 0 if no previous data exists or current sets are empty.
  /// @return Reps progress (can be positive, negative, or zero)
  int get repsProgress {
    if (previous == null || current.isEmpty) return 0;
    final currentMax = current.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
    return currentMax - previous!.maxReps;
  }

  /// @brief Calculates absolute volume progress (current total - previous total)
  /// @details Returns the difference in total volume (kg·reps) between current
  /// and previous sessions. Volume combines both weight and reps into a single
  /// metric, providing a comprehensive view of overall workout intensity improvement.
  /// Returns 0.0 if no previous data exists or current sets are empty.
  /// @return Volume progress in kg·reps (can be positive, negative, or zero)
  double get volumeProgress {
    if (previous == null || current.isEmpty) return 0.0;
    final currentVolume = current.fold(0.0, (sum, set) => sum + (set.kg * set.reps));
    return currentVolume - previous!.totalVolume;
  }

  /// @brief Calculates weight progress as a percentage of previous max weight
  /// @details Computes percentage improvement/decline relative to the previous
  /// maximum weight: ((current - previous) / previous) × 100. Returns 0.0 if
  /// no previous data exists, previous weight was 0, or current sets are empty.
  /// Useful for relative comparisons across exercises with different weight ranges.
  /// @return Weight progress percentage (positive for improvement, negative for decline)
  double get weightProgressPercentage {
    if (previous == null || previous!.maxWeight == 0 || current.isEmpty) return 0.0;
    final currentMax = current.map((s) => s.kg).reduce((a, b) => a > b ? a : b);
    return ((currentMax - previous!.maxWeight) / previous!.maxWeight) * 100;
  }

  /// @brief Checks if any progress metric improved from previous performance
  /// @details Returns true if weight, reps, or volume increased compared to
  /// the previous session. Used for highlighting successful progress in reports.
  /// @return true if any metric improved, false otherwise
  bool get hasImproved => weightProgress > 0 || repsProgress > 0 || volumeProgress > 0;

  /// @brief Generates a human-readable description of progress
  /// @details Creates a descriptive string summarizing performance changes:
  /// - "First time doing this exercise" if no previous data
  /// - Lists specific improvements/declines in weight and reps
  /// - "Performance maintained" if no changes occurred
  /// Used for displaying progress feedback to trainees and trainers.
  /// @return Human-readable progress summary string
  String get progressDescription {
    if (previous == null) return 'First time doing this exercise';

    List<String> improvements = [];
    if (weightProgress > 0) {
      improvements.add('${weightProgress.toStringAsFixed(1)}kg weight increase');
    } else if (weightProgress < 0) {
      improvements.add('${(-weightProgress).toStringAsFixed(1)}kg weight decrease');
    }

    if (repsProgress > 0) {
      improvements.add('$repsProgress more reps');
    } else if (repsProgress < 0) {
      improvements.add('${-repsProgress} fewer reps');
    }

    if (improvements.isEmpty) {
      return 'Performance maintained';
    }

    return improvements.join(', ');
  }
}

/// @class TrainingProgressReport
/// @brief Aggregates progress comparisons for an entire completed training session
/// @details Represents a comprehensive progress report for a training session, containing
/// ExerciseProgressComparison objects for each exercise performed. Provides aggregate
/// metrics like total exercises with improvement, improvement percentage, and total volume
/// increase across the entire workout. Used by trainers to review trainee performance and
/// identify areas of progress or concern. Generated by ExerciseHistoryService when a trainer
/// requests a progress report for a completed workout.
class TrainingProgressReport {
  /// @brief ID of the training session this report covers
  final String trainingId;

  /// @brief Name of the training session
  final String trainingName;

  /// @brief ID of the trainee who completed the workout
  final String traineeId;

  /// @brief Name of the trainee for display purposes
  final String traineeName;

  /// @brief When the training session was completed
  final DateTime completedAt;

  /// @brief List of progress comparisons for each exercise in the workout
  final List<ExerciseProgressComparison> exerciseComparisons;

  /// @brief Constructor for TrainingProgressReport
  /// @details Creates a complete progress report with all exercise comparisons
  /// @param trainingId ID of the training session
  /// @param trainingName Name of the training
  /// @param traineeId ID of the trainee
  /// @param traineeName Name of the trainee
  /// @param completedAt Completion timestamp
  /// @param exerciseComparisons List of exercise-level progress comparisons
  TrainingProgressReport({
    required this.trainingId,
    required this.trainingName,
    required this.traineeId,
    required this.traineeName,
    required this.completedAt,
    required this.exerciseComparisons,
  });

  /// @brief Counts how many exercises showed improvement
  /// @details Filters the exercise comparisons to count only those where
  /// hasImproved is true (any metric increased). Used for quick progress assessment.
  /// @return Number of exercises with improvement
  int get exercisesWithImprovement =>
      exerciseComparisons.where((e) => e.hasImproved).length;

  /// @brief Returns the total number of exercises in the training session
  /// @return Count of all exercises
  int get totalExercises => exerciseComparisons.length;

  /// @brief Calculates the percentage of exercises that showed improvement
  /// @details Computes (exercisesWithImprovement / totalExercises) × 100.
  /// Returns 0.0 if no exercises were performed. Provides a high-level metric
  /// for overall training session progress effectiveness.
  /// @return Improvement percentage (0-100)
  double get improvementPercentage =>
      totalExercises > 0 ? (exercisesWithImprovement / totalExercises) * 100 : 0.0;

  /// @brief Calculates total volume increase across all exercises
  /// @details Sums the volumeProgress from all exercise comparisons to get
  /// the aggregate volume change for the entire workout. Can be positive
  /// (overall improvement) or negative (overall decline).
  /// @return Total volume increase in kg·reps
  double get totalVolumeIncrease =>
      exerciseComparisons.fold(0.0, (sum, comp) => sum + comp.volumeProgress);

  /// @brief Generates an overall progress summary description
  /// @details Creates a human-readable summary of the training session progress:
  /// - "Improvement in all exercises! 🔥" if 100% improvement rate
  /// - "Improvement in X out of Y exercises" for partial improvement
  /// - "Performance maintained across all exercises" if no improvements
  /// Used for displaying a quick progress overview to trainers.
  /// @return Human-readable overall progress summary string
  String get overallProgressSummary {
    if (exercisesWithImprovement == 0) {
      return 'Performance maintained across all exercises';
    } else if (exercisesWithImprovement == totalExercises) {
      return 'Improvement in all exercises! 🔥';
    } else {
      return 'Improvement in $exercisesWithImprovement out of $totalExercises exercises';
    }
  }
}