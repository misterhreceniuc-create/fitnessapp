/// @file training_service.dart
/// @brief Training/Workout management service for the fitness training platform
/// @details This service handles all CRUD operations for training sessions,
/// including creation, retrieval, updating, deletion, and completion tracking.
/// It manages both individual workouts and recurring workout groups, with
/// persistent storage via LocalStorageService. The service uses in-memory
/// caching with automatic persistence to ensure data consistency across
/// app sessions.

import '../models/training_model.dart';
import 'local_storage_service.dart';

/// @class TrainingService
/// @brief Core service for managing training sessions and workout programs
/// @details Provides comprehensive workout management functionality including:
/// - Single and recurring workout creation
/// - Trainer-to-trainee workout assignment
/// - Workout completion tracking and history
/// - Bulk operations for recurring workout groups
/// - Persistent storage integration
///
/// The service maintains an in-memory cache (_trainings) synchronized with
/// persistent storage via LocalStorageService. All operations include simulated
/// network delays to mimic real-world API behavior.
class TrainingService {
  /// @brief Local storage service for persisting training data
  final LocalStorageService _storage;

  /// @brief In-memory cache of all training sessions
  /// @details Stores all training models loaded from storage and created during
  /// runtime. This list is synchronized with persistent storage after every
  /// modification operation (create, update, delete, complete).
  final List<TrainingModel> _trainings = [];

  /// @brief Constructor for TrainingService
  /// @details Initializes the service with a LocalStorageService dependency.
  /// Call loadFromStorage() after instantiation to populate the in-memory cache.
  /// @param _storage LocalStorageService instance for data persistence
  TrainingService(this._storage);

  /// @brief Loads all training sessions from persistent storage
  /// @details Retrieves training data from LocalStorageService, deserializes
  /// JSON data into TrainingModel objects, and populates the in-memory cache.
  /// This method should be called during app initialization to restore the
  /// previous session state. Clears existing cache before loading to prevent
  /// duplicates.
  /// @return Future<void> Completes when all trainings are loaded and cached
  Future<void> loadFromStorage() async {
    // Fetch serialized training data from storage
    final trainingsData = await _storage.loadTrainings();

    // Clear existing cache to prevent duplicates
    _trainings.clear();

    // Deserialize and populate cache
    _trainings.addAll(trainingsData.map((json) => TrainingModel.fromJson(json)));

    print('Loaded ${_trainings.length} trainings from storage');
  }

  /// @brief Persists the current in-memory training cache to storage
  /// @details Private method that serializes all TrainingModel objects to JSON
  /// and saves them via LocalStorageService. Called automatically after any
  /// modification operation (create, update, delete, complete) to ensure data
  /// persistence across app sessions.
  /// @return Future<void> Completes when data is successfully persisted
  Future<void> _saveToStorage() async {
    // Serialize all training models to JSON format
    final trainingsData = _trainings.map((t) => t.toJson()).toList();

    // Persist to storage
    await _storage.saveTrainings(trainingsData);
  }

  /// @brief Retrieves all training sessions assigned to a specific trainee
  /// @details Filters the training cache by traineeId and returns all matching
  /// workouts. Includes debug logging to trace assignment relationships. This
  /// method is typically called when a trainee views their dashboard to display
  /// their workout schedule.
  /// @param traineeId The unique identifier of the trainee user
  /// @return Future<List<TrainingModel>> List of all trainings assigned to the trainee
  Future<List<TrainingModel>> getTrainingsForTrainee(String traineeId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Debug logging for troubleshooting assignment issues
    print('=== TRAINING SERVICE DEBUG ===');
    print('Looking for trainings for trainee ID: $traineeId');
    print('Total trainings in system: ${_trainings.length}');

    for (var training in _trainings) {
      print('- Training "${training.name}" assigned to: ${training.traineeId}');
    }

    // Filter trainings by traineeId
    final trainings = _trainings.where((training) => training.traineeId == traineeId).toList();
    print('Found ${trainings.length} matching trainings');

    return trainings;
  }

  /// @brief Retrieves all training sessions created by a specific trainer
  /// @details Filters the training cache by trainerId and returns all workouts
  /// created by that trainer. This is used in the trainer dashboard to display
  /// all workouts they have assigned to their trainees.
  /// @param trainerId The unique identifier of the trainer user
  /// @return Future<List<TrainingModel>> List of all trainings created by the trainer
  Future<List<TrainingModel>> getTrainingsForTrainer(String trainerId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Filter trainings by trainerId
    return _trainings.where((training) => training.trainerId == trainerId).toList();
  }

  /// @brief Creates a new training session and persists it to storage
  /// @details Accepts a TrainingModel object, creates a new instance with all
  /// provided properties, adds it to the in-memory cache, and persists to storage.
  /// Supports both single workouts and recurring workouts (via recurrenceGroupId).
  /// Includes debug logging to track creation success and assignment details.
  /// @param training The training model to create (with all required properties)
  /// @return Future<TrainingModel> The newly created training with all fields populated
  Future<TrainingModel> createTraining(TrainingModel training) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Create a new training instance with all properties
    // This ensures immutability and proper object instantiation
    final newTraining = TrainingModel(
      id: training.id,
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

    // Add to in-memory cache
    _trainings.add(newTraining);

    // Persist to storage
    await _saveToStorage();

    // Debug logging for creation confirmation
    print('=== WORKOUT CREATED ===');
    print('Training: ${newTraining.name}');
    print('Assigned to trainee ID: ${newTraining.traineeId}');
    print('Created by trainer ID: ${newTraining.trainerId}');
    print('Total trainings now: ${_trainings.length}');

    return newTraining;
  }

  /// @brief Updates an existing training session with new data
  /// @details Locates a training by ID in the cache and replaces it with the
  /// updated version. If found, persists changes to storage. If the training
  /// doesn't exist, returns the input without modification (no error thrown).
  /// @param training The updated training model with the same ID as existing training
  /// @return Future<TrainingModel> The updated training model
  Future<TrainingModel> updateTraining(TrainingModel training) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Locate training by ID
    final index = _trainings.indexWhere((t) => t.id == training.id);

    if (index != -1) {
      // Replace with updated version
      _trainings[index] = training;

      // Persist changes to storage
      await _saveToStorage();
    }

    return training;
  }

  /// @brief Marks a training session as completed by the trainee
  /// @details Locates a training by ID, updates its completion status and
  /// timestamp using copyWith(), and persists to storage. This is called when
  /// a trainee finishes their workout and logs all exercises. Includes debug
  /// logging for completion tracking.
  /// @param trainingId The unique identifier of the training to mark as complete
  /// @return Future<void> Completes when the training is marked complete and persisted
  Future<void> completeTraining(String trainingId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Locate training by ID
    final index = _trainings.indexWhere((t) => t.id == trainingId);

    if (index != -1) {
      final training = _trainings[index];

      // Update with completion status and timestamp
      _trainings[index] = training.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      // Persist changes to storage
      await _saveToStorage();

      // Debug logging for completion confirmation
      print('=== WORKOUT COMPLETED ===');
      print('Training: ${training.name}');
      print('Completed by trainee ID: ${training.traineeId}');
    }
  }

  /// @brief Updates all training sessions in a recurring workout group
  /// @details Locates all trainings sharing the same recurrenceGroupId and
  /// updates their core properties (name, description, exercises, etc.) based
  /// on a template training. Preserves individual scheduling dates and completion
  /// status. Useful for batch-editing recurring workouts without recreating them.
  /// @param recurrenceGroupId The shared ID linking recurring workouts together
  /// @param templateTraining A training model containing the updated properties to apply
  /// @return Future<List<TrainingModel>> List of all updated training sessions
  Future<List<TrainingModel>> updateRecurrenceGroup(String recurrenceGroupId, TrainingModel templateTraining) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final updatedTrainings = <TrainingModel>[];

    // Iterate through all trainings to find matching recurrence group
    for (int i = 0; i < _trainings.length; i++) {
      final training = _trainings[i];

      if (training.recurrenceGroupId == recurrenceGroupId) {
        // Update with template properties while preserving scheduling and status
        final updated = training.copyWith(
          name: templateTraining.name,
          description: templateTraining.description,
          exercises: templateTraining.exercises,
          difficulty: templateTraining.difficulty,
          estimatedDuration: templateTraining.estimatedDuration,
          category: templateTraining.category,
          notes: templateTraining.notes,
        );

        // Replace in cache and track for return
        _trainings[i] = updated;
        updatedTrainings.add(updated);
      }
    }

    // Only persist if updates were made
    if (updatedTrainings.isNotEmpty) {
      await _saveToStorage();
    }

    return updatedTrainings;
  }

  /// @brief Retrieves all training sessions belonging to a recurring workout group
  /// @details Filters the training cache by recurrenceGroupId to find all related
  /// workouts in a recurring series. Used for displaying recurring workout schedules
  /// and managing bulk operations on workout groups.
  /// @param recurrenceGroupId The shared identifier linking recurring workouts
  /// @return Future<List<TrainingModel>> List of all trainings in the recurrence group
  Future<List<TrainingModel>> getTrainingsByRecurrenceGroup(String recurrenceGroupId) async {
    // Simulate network delay (shorter for query operations)
    await Future.delayed(const Duration(milliseconds: 300));

    // Filter by recurrence group ID
    return _trainings.where((t) => t.recurrenceGroupId == recurrenceGroupId).toList();
  }

  /// @brief Deletes a single training session from the system
  /// @details Removes a training by ID from the in-memory cache and persists
  /// the change to storage. Does not affect other trainings in the same
  /// recurrence group. Use deleteRecurrenceGroup() to delete all related workouts.
  /// @param trainingId The unique identifier of the training to delete
  /// @return Future<void> Completes when the training is deleted and changes persisted
  Future<void> deleteTraining(String trainingId) async {
    // Simulate network delay (shorter for delete operations)
    await Future.delayed(const Duration(milliseconds: 300));

    // Remove training from cache
    _trainings.removeWhere((t) => t.id == trainingId);

    // Persist changes to storage
    await _saveToStorage();
  }

  /// @brief Deletes all training sessions in a recurring workout group
  /// @details Removes all trainings sharing the same recurrenceGroupId from the
  /// cache and persists changes. Returns the IDs of all deleted trainings for
  /// confirmation or UI updates. Useful for canceling recurring workout series.
  /// @param recurrenceGroupId The shared identifier of the recurring workout group
  /// @return Future<List<String>> List of IDs of all deleted training sessions
  Future<List<String>> deleteRecurrenceGroup(String recurrenceGroupId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final deletedIds = <String>[];

    // Remove all trainings in the recurrence group and track their IDs
    _trainings.removeWhere((training) {
      if (training.recurrenceGroupId == recurrenceGroupId) {
        deletedIds.add(training.id);
        return true; // Remove this training
      }
      return false; // Keep this training
    });

    // Only persist if deletions were made
    if (deletedIds.isNotEmpty) {
      await _saveToStorage();
    }

    return deletedIds;
  }
}
