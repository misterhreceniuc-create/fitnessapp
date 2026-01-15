/// @file exercise_history_service.dart
/// @brief Service for managing exercise performance history and progress tracking
/// @details This service provides comprehensive exercise history management including
/// saving completed workout data, retrieving historical performance records, generating
/// progress comparisons, and calculating exercise statistics. It maintains an in-memory
/// repository of ExerciseHistoryEntry objects that capture trainee performance across
/// training sessions. The service supports progressive overload tracking by comparing
/// current performance against previous records for the same exercise. Used extensively
/// by both trainers (for progress reports) and trainees (for viewing personal records
/// and historical data). In a production app, the in-memory storage would be replaced
/// with persistent database storage, but the interface remains the same.

import 'package:uuid/uuid.dart';
import '../models/exercise_history_model.dart';
import '../models/training_model.dart';
import '../../features/workout/data/exercise_model.dart';

/// @class ExerciseHistoryService
/// @brief Manages exercise performance history and progress tracking for trainees
/// @details Provides CRUD operations and analysis functions for exercise history data.
/// Main responsibilities include:
/// - Saving workout completion data to history
/// - Retrieving historical performance by trainee and exercise
/// - Generating progress comparisons between current and previous performance
/// - Calculating aggregate statistics (max weight, average volume, etc.)
/// - Supporting trainer progress reports with detailed exercise-level analysis
///
/// The service uses in-memory storage (_exerciseHistory) for demonstration purposes.
/// All methods are async to support future database integration without API changes.
class ExerciseHistoryService {
  /// @brief In-memory storage of exercise history entries
  /// @details Static list shared across all service instances. In production,
  /// this would be replaced with database queries, but kept as a list for
  /// demonstration and testing purposes. Contains all historical exercise
  /// performance data for all trainees.
  static final List<ExerciseHistoryEntry> _exerciseHistory = [];

  /// @brief UUID generator for creating unique history entry IDs
  final Uuid _uuid = const Uuid();

  /// @brief Saves all exercises from a completed training to history
  /// @details Extracts each exercise with actualSets from the completed training
  /// and creates ExerciseHistoryEntry records. Only processes exercises that have
  /// actualSets (completed exercises), skipping any that weren't performed. Each
  /// entry captures the exercise name, trainee ID, training ID, completion timestamp,
  /// and all actualSet data for future progress comparisons. Throws exception if
  /// training is not marked as completed or lacks a completedAt timestamp.
  /// @param training The completed training model with actualSets data
  /// @return Future<void> Completes when all history entries are saved
  /// @throws Exception if training is not completed
  Future<void> saveTrainingHistory(TrainingModel training) async {
    if (!training.isCompleted || training.completedAt == null) {
      throw Exception('Training must be completed to save history');
    }

    // Iterate through all exercises in the training
    for (final exercise in training.exercises) {
      // Only save exercises that have recorded actualSets (were actually performed)
      if (exercise.actualSets.isNotEmpty) {
        // Create a history entry for this exercise
        final historyEntry = ExerciseHistoryEntry(
          id: _uuid.v4(), // Generate unique ID for this history record
          exerciseName: exercise.name,
          traineeId: training.traineeId,
          trainingId: training.id,
          completedAt: training.completedAt!,
          actualSets: List.from(exercise.actualSets), // Copy to prevent reference issues
          notes: exercise.notes,
        );

        _exerciseHistory.add(historyEntry);
        print('💾 Saved history for ${exercise.name}: ${exercise.actualSets.length} sets');
      }
    }
  }

  /// @brief Retrieves exercise history for a specific trainee and exercise
  /// @details Filters the exercise history to find all entries matching both the
  /// trainee ID and exercise name. Results are sorted by date (most recent first).
  /// Optionally limits the number of results returned. Used to view performance
  /// history timeline for a specific exercise, enabling trainees and trainers to
  /// see progression over time.
  /// @param traineeId ID of the trainee to filter by
  /// @param exerciseName Name of the exercise to retrieve history for
  /// @param limit Optional maximum number of entries to return (most recent entries)
  /// @return Future<List<ExerciseHistoryEntry>> Sorted list of matching history entries
  Future<List<ExerciseHistoryEntry>> getExerciseHistory(
    String traineeId,
    String exerciseName, {
    int? limit,
  }) async {
    final filtered = _exerciseHistory
        .where((entry) =>
            entry.traineeId == traineeId &&
            entry.exerciseName == exerciseName)
        .toList();

    // Sort by date (most recent first)
    filtered.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    if (limit != null && limit > 0) {
      return filtered.take(limit).toList();
    }

    return filtered;
  }

  // Get the most recent history entry for an exercise
  Future<ExerciseHistoryEntry?> getLastExerciseHistory(
    String traineeId,
    String exerciseName,
  ) async {
    // Retrieve only 1 entry (the most recent)
    final history = await getExerciseHistory(traineeId, exerciseName, limit: 1);
    return history.isNotEmpty ? history.first : null;
  }

  /// @brief Retrieves all exercise history for a specific trainee
  /// @details Returns all history entries across all exercises for the trainee,
  /// sorted by date (most recent first). Used for generating comprehensive
  /// performance overviews and analyzing overall training progress across
  /// multiple exercises and training sessions.
  /// @param traineeId ID of the trainee
  /// @return Future<List<ExerciseHistoryEntry>> All history entries for the trainee
  Future<List<ExerciseHistoryEntry>> getTraineeHistory(String traineeId) async {
    // Filter all entries for this trainee
    final filtered = _exerciseHistory
        .where((entry) => entry.traineeId == traineeId)
        .toList();

    // Sort by date (most recent first)
    filtered.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return filtered;
  }

  /// @brief Generates a comprehensive progress report for a completed training
  /// @details Creates a TrainingProgressReport by comparing each exercise in the
  /// completed training against the trainee's previous performance of that exercise.
  /// For each exercise, retrieves the most recent previous history entry (excluding
  /// the current training) and constructs an ExerciseProgressComparison. The report
  /// includes exercise-level progress metrics (weight, reps, volume changes) and
  /// aggregate workout-level metrics (total improvement percentage, volume increase).
  /// Used by trainers to review trainee progress and provide feedback.
  /// @param training The completed training to generate a report for
  /// @param traineeName Name of the trainee for display in the report
  /// @return Future<TrainingProgressReport> Complete progress report with comparisons
  /// @throws Exception if training is not completed
  Future<TrainingProgressReport> generateProgressReport(
    TrainingModel training,
    String traineeName,
  ) async {
    if (!training.isCompleted) {
      throw Exception('Training must be completed to generate progress report');
    }

    final comparisons = <ExerciseProgressComparison>[];

    // Process each exercise that has recorded sets
    for (final exercise in training.exercises) {
      if (exercise.actualSets.isNotEmpty) {
        // Attempt to get the most recent historical entry
        final previousHistory = await getLastExerciseHistory(
          training.traineeId,
          exercise.name,
        );

        // Ensure we get truly "previous" data by filtering out current training
        // This prevents comparing the training against itself
        ExerciseHistoryEntry? previousEntry;
        if (previousHistory != null && previousHistory.trainingId != training.id) {
          previousEntry = previousHistory;
        } else {
          // The most recent entry is from the current training, so get the second most recent
          final allHistory = await getExerciseHistory(training.traineeId, exercise.name);
          final otherEntries = allHistory
              .where((entry) => entry.trainingId != training.id)
              .toList();
          previousEntry = otherEntries.isNotEmpty ? otherEntries.first : null;
        }

        // Create progress comparison for this exercise
        final comparison = ExerciseProgressComparison(
          exerciseName: exercise.name,
          previous: previousEntry, // May be null if first time doing this exercise
          current: exercise.actualSets,
          currentDate: training.completedAt!,
        );

        comparisons.add(comparison);
      }
    }

    // Build and return the complete progress report
    return TrainingProgressReport(
      trainingId: training.id,
      trainingName: training.name,
      traineeId: training.traineeId,
      traineeName: traineeName,
      completedAt: training.completedAt!,
      exerciseComparisons: comparisons,
    );
  }

  /// @brief Calculates aggregate statistics for a specific exercise and trainee
  /// @details Computes various performance metrics across all historical sessions:
  /// - totalSessions: Number of times the exercise was performed
  /// - maxWeight: Highest weight ever used across all sessions
  /// - maxReps: Highest reps ever performed in a single set
  /// - averageVolume: Mean volume (kg·reps) per session
  /// - lastPerformed: Date of most recent performance
  /// - firstPerformed: Date of first performance
  /// Returns zeros/nulls if no history exists. Used for displaying personal
  /// records and long-term progress trends.
  /// @param traineeId ID of the trainee
  /// @param exerciseName Name of the exercise
  /// @return Future<Map<String, dynamic>> Statistics map with metrics
  Future<Map<String, dynamic>> getExerciseStats(
    String traineeId,
    String exerciseName,
  ) async {
    final history = await getExerciseHistory(traineeId, exerciseName);

    // Return zero values if no history exists
    if (history.isEmpty) {
      return {
        'totalSessions': 0,
        'maxWeight': 0.0,
        'maxReps': 0,
        'averageVolume': 0.0,
        'lastPerformed': null,
      };
    }

    // Calculate maximums across all historical sessions
    final maxWeight = history.map((e) => e.maxWeight).reduce((a, b) => a > b ? a : b);
    final maxReps = history.map((e) => e.maxReps).reduce((a, b) => a > b ? a : b);
    // Calculate average volume per session
    final averageVolume = history.map((e) => e.totalVolume).reduce((a, b) => a + b) / history.length;

    return {
      'totalSessions': history.length,
      'maxWeight': maxWeight,
      'maxReps': maxReps,
      'averageVolume': averageVolume,
      'lastPerformed': history.first.completedAt, // Most recent (already sorted)
      'firstPerformed': history.last.completedAt, // Oldest (at end of sorted list)
    };
  }

  /// @brief Clears all exercise history from the in-memory storage
  /// @details Removes all ExerciseHistoryEntry records from the static list.
  /// Used primarily for testing and debugging purposes to reset the history
  /// state. In a production database implementation, this would be a dangerous
  /// operation requiring admin privileges.
  /// @return Future<void> Completes when history is cleared
  Future<void> clearHistory() async {
    _exerciseHistory.clear();
    print('🧹 Exercise history cleared');
  }

  /// @brief Returns the total count of history entries
  /// @details Simple getter for debugging and monitoring purposes. Shows how
  /// many exercise performance records are currently stored in memory.
  /// @return Total number of history entries
  int get historyCount => _exerciseHistory.length;

  /// @brief Retrieves all unique exercise names performed by a trainee
  /// @details Extracts and returns a sorted list of distinct exercise names
  /// from the trainee's history. Used for displaying exercise selection lists
  /// filtered to exercises the trainee has previously performed, enabling
  /// quick access to personal history for specific exercises.
  /// @param traineeId ID of the trainee
  /// @return Future<List<String>> Sorted list of unique exercise names
  Future<List<String>> getTraineeExerciseNames(String traineeId) async {
    // Get all history for this trainee
    final traineeHistory = await getTraineeHistory(traineeId);
    // Use a Set to collect unique exercise names (automatically deduplicates)
    final uniqueNames = <String>{};
    for (final entry in traineeHistory) {
      uniqueNames.add(entry.exerciseName);
    }
    // Convert to list and sort alphabetically for consistent display
    return uniqueNames.toList()..sort();
  }
}