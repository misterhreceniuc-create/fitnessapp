/// @file goal_service.dart
/// @brief Service for managing fitness goals and tracking progress
/// @details This service provides comprehensive goal management functionality including
/// creating, updating, deleting, and tracking progress on fitness goals. Goals are
/// assigned by trainers to trainees and can represent various fitness objectives
/// (weight loss, muscle gain, strength targets, etc.). The service handles data
/// persistence through LocalStorageService and maintains an in-memory cache for
/// efficient access.

import '../models/goal_model.dart';
import 'local_storage_service.dart';

/// @class GoalService
/// @brief Service class for managing fitness goals and progress tracking
/// @details Provides CRUD operations for fitness goals assigned by trainers to trainees.
/// Goals support various types (weight, strength, endurance, etc.) with target values,
/// current progress, and deadlines. The service maintains an in-memory list of goals
/// and persists changes to local storage. All operations include simulated network
/// delays to mimic real API behavior.
class GoalService {
  /// @brief Local storage service for persisting goal data
  final LocalStorageService _storage;

  /// @brief In-memory cache of all goals for fast access and manipulation
  final List<GoalModel> _goals = [];

  /// @brief Constructor that initializes the goal service with a storage provider
  /// @param _storage LocalStorageService instance for data persistence
  GoalService(this._storage);

  /// @brief Loads all goals from persistent storage into memory
  /// @details Retrieves goal data from LocalStorageService, deserializes JSON data
  /// into GoalModel objects, and populates the in-memory _goals list. This method
  /// should be called during service initialization to restore previously saved goals.
  /// Clears any existing in-memory goals before loading to ensure data consistency.
  /// @return Future<void> Completes when all goals are loaded
  Future<void> loadFromStorage() async {
    // Retrieve raw goal data from storage
    final goalsData = await _storage.loadGoals();

    // Clear existing goals to prevent duplicates
    _goals.clear();

    // Deserialize JSON data into GoalModel objects and add to cache
    _goals.addAll(goalsData.map((json) => GoalModel.fromJson(json)));

    print('Loaded ${_goals.length} goals from storage');
  }

  /// @brief Private method to persist current goal data to storage
  /// @details Serializes all in-memory goals to JSON format and saves them to
  /// persistent storage via LocalStorageService. This method is called internally
  /// after any data modification operation (create, update, delete) to ensure
  /// data persistence across app restarts.
  /// @return Future<void> Completes when data is successfully saved
  Future<void> _saveToStorage() async {
    // Serialize all goals to JSON format
    final goalsData = _goals.map((g) => g.toJson()).toList();

    // Persist to storage
    await _storage.saveGoals(goalsData);
  }

  /// @brief Retrieves all goals created by a specific trainer
  /// @details Fetches and filters goals where the trainerId matches the provided ID.
  /// Results are sorted by creation date in descending order (newest first).
  /// Includes a simulated network delay to mimic API behavior.
  /// @param trainerId The unique identifier of the trainer
  /// @return Future<List<GoalModel>> List of goals created by the trainer, sorted by creation date
  Future<List<GoalModel>> getGoalsForTrainer(String trainerId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Filter goals by trainer ID and sort by creation date (newest first)
    final goals = _goals
        .where((g) => g.trainerId == trainerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return goals;
  }

  /// @brief Retrieves all goals assigned to a specific trainee
  /// @details Fetches and filters goals where the traineeId matches the provided ID.
  /// Results are sorted by creation date in descending order (newest first).
  /// Includes a simulated network delay to mimic API behavior. Useful for displaying
  /// a trainee's dashboard showing all their fitness objectives.
  /// @param traineeId The unique identifier of the trainee
  /// @return Future<List<GoalModel>> List of goals assigned to the trainee, sorted by creation date
  Future<List<GoalModel>> getGoalsForTrainee(String traineeId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Filter goals by trainee ID and sort by creation date (newest first)
    final goals = _goals
        .where((g) => g.traineeId == traineeId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return goals;
  }

  /// @brief Creates a new goal and persists it to storage
  /// @details Adds a new goal to the in-memory list and saves it to persistent storage.
  /// The goal must be fully initialized with all required fields before being passed
  /// to this method. Includes a simulated network delay and debug logging to track
  /// goal creation events.
  /// @param goal The GoalModel object to create with all required fields populated
  /// @return Future<GoalModel> The created goal object (same as input)
  Future<GoalModel> createGoal(GoalModel goal) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Add goal to in-memory cache
    _goals.add(goal);

    // Persist to storage
    await _saveToStorage();

    // Debug logging for goal creation tracking
    print('=== GOAL SERVICE ===');
    print('Goal created: ${goal.name}');
    print('Assigned to trainee: ${goal.traineeId}');
    print('Created by trainer: ${goal.trainerId}');

    return goal;
  }

  /// @brief Updates an existing goal with new data
  /// @details Searches for a goal by ID and replaces it with the provided updated goal.
  /// All fields of the goal are replaced with values from the provided goal object.
  /// Changes are persisted to storage after the update. Includes simulated network delay.
  /// @param goal The GoalModel object containing updated data (must have valid existing ID)
  /// @return Future<GoalModel> The updated goal object
  /// @throws Exception if goal with the specified ID is not found
  Future<GoalModel> updateGoal(GoalModel goal) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the goal by ID
    final index = _goals.indexWhere((g) => g.id == goal.id);

    if (index != -1) {
      // Replace the existing goal with updated data
      _goals[index] = goal;

      // Persist changes to storage
      await _saveToStorage();

      return goal;
    }

    // Goal not found - throw exception
    throw Exception('Goal not found');
  }

  /// @brief Deletes a goal by its ID
  /// @details Removes a goal from the in-memory list and updates persistent storage.
  /// The deletion is permanent and cannot be undone. Includes simulated network delay.
  /// @param goalId The unique identifier of the goal to delete
  /// @return Future<void> Completes when the goal is deleted and changes are persisted
  Future<void> deleteGoal(String goalId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Remove the goal from in-memory cache
    _goals.removeWhere((g) => g.id == goalId);

    // Persist changes to storage
    await _saveToStorage();
  }

  /// @brief Updates the current progress value of a goal
  /// @details Updates only the currentValue field of a goal while preserving all other
  /// fields. Automatically marks the goal as completed if the new value meets or exceeds
  /// the target value. This is the primary method for tracking trainee progress toward
  /// their fitness objectives. Changes are persisted to storage.
  /// @param goalId The unique identifier of the goal to update
  /// @param newValue The new current progress value (e.g., new weight, reps achieved)
  /// @return Future<GoalModel> The updated goal with new progress value
  /// @throws Exception if goal with the specified ID is not found
  Future<GoalModel> updateProgress(String goalId, double newValue) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the goal by ID
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) {
      throw Exception('Goal not found');
    }

    // Get the existing goal
    final goal = _goals[index];

    // Create updated goal with new progress value
    // Auto-complete if target is reached or exceeded
    final updatedGoal = GoalModel(
      id: goal.id,
      traineeId: goal.traineeId,
      trainerId: goal.trainerId,
      name: goal.name,
      type: goal.type,
      targetValue: goal.targetValue,
      currentValue: newValue,
      unit: goal.unit,
      deadline: goal.deadline,
      isCompleted: newValue >= goal.targetValue, // Auto-complete on target reached
      createdAt: goal.createdAt,
    );

    // Update in-memory cache
    _goals[index] = updatedGoal;

    // Persist changes to storage
    await _saveToStorage();

    return updatedGoal;
  }

  /// @brief Manually marks a goal as completed
  /// @details Sets the goal's isCompleted flag to true and updates the currentValue
  /// to match the targetValue. This is useful for manually completing goals that may
  /// not have precise numeric tracking or when a trainer wants to override automatic
  /// completion. Changes are persisted to storage.
  /// @param goalId The unique identifier of the goal to mark as completed
  /// @return Future<GoalModel> The updated goal marked as completed
  /// @throws Exception if goal with the specified ID is not found
  Future<GoalModel> markAsCompleted(String goalId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the goal by ID
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) {
      throw Exception('Goal not found');
    }

    // Get the existing goal
    final goal = _goals[index];

    // Create updated goal with completion status
    // Set currentValue to targetValue to indicate 100% completion
    final updatedGoal = GoalModel(
      id: goal.id,
      traineeId: goal.traineeId,
      trainerId: goal.trainerId,
      name: goal.name,
      type: goal.type,
      targetValue: goal.targetValue,
      currentValue: goal.targetValue, // Set to target to show 100% progress
      unit: goal.unit,
      deadline: goal.deadline,
      isCompleted: true, // Explicitly mark as completed
      createdAt: goal.createdAt,
    );

    // Update in-memory cache
    _goals[index] = updatedGoal;

    // Persist changes to storage
    await _saveToStorage();

    return updatedGoal;
  }

  /// @brief Retrieves a single goal by its unique identifier
  /// @details Searches for a goal with the specified ID in the in-memory cache.
  /// Includes a shorter simulated network delay (300ms) compared to other operations
  /// as this is typically a faster lookup operation. Returns null if not found rather
  /// than throwing an exception, making it suitable for existence checks.
  /// @param goalId The unique identifier of the goal to retrieve
  /// @return Future<GoalModel?> The goal if found, null otherwise
  Future<GoalModel?> getGoalById(String goalId) async {
    // Simulate network delay (shorter for single item lookup)
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Search for goal by ID
      return _goals.firstWhere((g) => g.id == goalId);
    } catch (e) {
      // Goal not found - return null instead of throwing
      return null;
    }
  }
}
