/// @file steps_service.dart
/// @brief Service for managing trainee daily step count tracking
/// @details Provides functionality to log, retrieve, update, and delete step entries
///          for trainees. Supports both manual step entry and persistent storage
///          using LocalStorageService. This service maintains an in-memory cache
///          of step entries and synchronizes with local storage for persistence.

import '../models/steps_model.dart';
import 'local_storage_service.dart';

/// @class StepsService
/// @brief Service class responsible for managing trainee step count data
/// @details This service handles all operations related to daily step tracking for trainees,
///          including creating manual entries, retrieving step counts by date, and managing
///          the persistence of step data through LocalStorageService. The service maintains
///          an in-memory list of step entries that is synchronized with local storage.
///          All operations simulate network delays for realistic user experience.
class StepsService {
  /// @brief Local storage service instance for persisting step data
  final LocalStorageService _storage;

  /// @brief In-memory cache of all step entries across all trainees
  final List<StepsModel> _steps = [];

  /// @brief Constructor for StepsService
  /// @details Initializes the service with a LocalStorageService instance for data persistence
  /// @param _storage The LocalStorageService instance to use for loading and saving step data
  StepsService(this._storage);

  /// @brief Loads all step entries from persistent storage
  /// @details Retrieves step data from LocalStorageService, clears the in-memory cache,
  ///          and populates it with the loaded data. This method should be called during
  ///          application initialization to restore previously saved step entries.
  /// @return Future<void> Completes when all step entries have been loaded into memory
  /// @throws Exception if storage read operation fails
  Future<void> loadFromStorage() async {
    // Retrieve raw JSON data from local storage
    final stepsData = await _storage.loadSteps();

    // Clear existing in-memory cache to prevent duplicates
    _steps.clear();

    // Deserialize JSON data and populate the in-memory list
    _steps.addAll(stepsData.map((json) => StepsModel.fromJson(json)));

    // Log the number of entries loaded for debugging purposes
    print('Loaded ${_steps.length} step entries from storage');
  }

  /// @brief Saves the current in-memory step entries to persistent storage
  /// @details Serializes all step entries to JSON format and persists them using
  ///          LocalStorageService. This is a private method called internally after
  ///          any modification to the step data (create, update, delete operations).
  /// @return Future<void> Completes when all step entries have been saved to storage
  /// @throws Exception if storage write operation fails
  Future<void> _saveToStorage() async {
    // Serialize all step entries to JSON format
    final stepsData = _steps.map((s) => s.toJson()).toList();

    // Persist the JSON data to local storage
    await _storage.saveSteps(stepsData);
  }

  /// @brief Retrieves the step entry for a specific trainee and date
  /// @details Searches the in-memory cache for a step entry matching the given trainee ID
  ///          and date. The comparison is done at date-only precision (year, month, day),
  ///          ignoring time components. Simulates a 300ms network delay for realistic UX.
  /// @param traineeId The unique identifier of the trainee whose steps to retrieve
  /// @param date The date for which to retrieve step data (time component is ignored)
  /// @return Future<StepsModel?> The step entry if found, null if no entry exists for the date
  Future<StepsModel?> getStepsForDate(String traineeId, DateTime date) async {
    // Simulate network/database delay for realistic user experience
    await Future.delayed(const Duration(milliseconds: 300));

    // Normalize date to midnight (strip time component) for accurate comparison
    final dateOnly = DateTime(date.year, date.month, date.day);

    try {
      // Search for matching entry by trainee ID and date
      return _steps.firstWhere(
        (s) {
          // Normalize stored date to midnight for comparison
          final stepDate = DateTime(s.date.year, s.date.month, s.date.day);
          return s.traineeId == traineeId && stepDate == dateOnly;
        },
      );
    } catch (e) {
      // Return null if no matching entry found (firstWhere throws StateError)
      return null;
    }
  }

  /// @brief Retrieves the step entry for today's date for a specific trainee
  /// @details Convenience method that calls getStepsForDate with the current date.
  ///          Useful for quickly accessing today's step count without manually passing
  ///          DateTime.now().
  /// @param traineeId The unique identifier of the trainee whose today's steps to retrieve
  /// @return Future<StepsModel?> Today's step entry if found, null if no entry exists
  Future<StepsModel?> getTodaySteps(String traineeId) async {
    return await getStepsForDate(traineeId, DateTime.now());
  }

  /// @brief Creates or updates a manual step entry for a specific trainee and date
  /// @details Logs a manual step count entry for the given trainee and date. If an entry
  ///          already exists for the specified date, it updates the existing entry with
  ///          the new step count while preserving the original entry ID. If no entry exists,
  ///          creates a new entry with a timestamp-based ID. All entries are marked as
  ///          manual (isManual = true). Simulates 300ms delay and persists to storage.
  /// @param traineeId The unique identifier of the trainee logging steps
  /// @param date The date for which to log steps (time component is ignored)
  /// @param steps The number of steps taken on the specified date
  /// @return Future<StepsModel> The created or updated step entry
  /// @throws Exception if storage save operation fails
  Future<StepsModel> logManualSteps({
    required String traineeId,
    required DateTime date,
    required int steps,
  }) async {
    // Simulate network/database delay for realistic user experience
    await Future.delayed(const Duration(milliseconds: 300));

    // Normalize date to midnight (strip time component)
    final dateOnly = DateTime(date.year, date.month, date.day);

    // Search for existing entry for this trainee and date
    final existingIndex = _steps.indexWhere(
      (s) {
        final stepDate = DateTime(s.date.year, s.date.month, s.date.day);
        return s.traineeId == traineeId && stepDate == dateOnly;
      },
    );

    // Create step entry (preserve existing ID if updating, generate new ID if creating)
    final stepsEntry = StepsModel(
      id: existingIndex >= 0
          ? _steps[existingIndex].id // Preserve existing ID
          : DateTime.now().millisecondsSinceEpoch.toString(), // Generate new ID
      traineeId: traineeId,
      date: dateOnly,
      steps: steps,
      isManual: true, // Mark as manually entered
    );

    // Update existing entry or add new entry to in-memory list
    if (existingIndex >= 0) {
      _steps[existingIndex] = stepsEntry;
    } else {
      _steps.add(stepsEntry);
    }

    // Persist changes to local storage
    await _saveToStorage();
    return stepsEntry;
  }

  /// @brief Retrieves all step entries for a specific trainee
  /// @details Filters the in-memory cache for all step entries belonging to the specified
  ///          trainee and returns them sorted by date in descending order (newest first).
  ///          Useful for displaying step history or generating reports. Simulates 300ms delay.
  /// @param traineeId The unique identifier of the trainee whose step history to retrieve
  /// @return Future<List<StepsModel>> List of step entries sorted by date (newest first)
  Future<List<StepsModel>> getAllSteps(String traineeId) async {
    // Simulate network/database delay for realistic user experience
    await Future.delayed(const Duration(milliseconds: 300));

    // Filter steps by trainee ID and sort by date (newest first)
    final steps = _steps.where((s) => s.traineeId == traineeId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return steps;
  }

  /// @brief Deletes a step entry by its unique identifier
  /// @details Removes the specified step entry from the in-memory cache and persists
  ///          the change to local storage. Simulates a 300ms network delay. If no entry
  ///          with the given ID exists, the operation completes without error.
  /// @param stepId The unique identifier of the step entry to delete
  /// @return Future<void> Completes when the entry has been deleted and changes persisted
  /// @throws Exception if storage save operation fails
  Future<void> deleteStepEntry(String stepId) async {
    // Simulate network/database delay for realistic user experience
    await Future.delayed(const Duration(milliseconds: 300));

    // Remove entry from in-memory list
    _steps.removeWhere((s) => s.id == stepId);

    // Persist changes to local storage
    await _saveToStorage();
  }

  /// @brief Checks if a manual step entry exists for a specific trainee and date
  /// @details Retrieves the step entry for the given date and verifies if it exists and
  ///          is marked as a manual entry (isManual = true). Useful for UI logic to determine
  ///          whether to show edit or create options for step entries.
  /// @param traineeId The unique identifier of the trainee to check
  /// @param date The date to check for manual entry (time component is ignored)
  /// @return Future<bool> True if a manual entry exists for the date, false otherwise
  Future<bool> hasManualEntryForDate(String traineeId, DateTime date) async {
    // Retrieve step entry for the specified date
    final entry = await getStepsForDate(traineeId, date);

    // Return true only if entry exists and is marked as manual
    return entry != null && entry.isManual;
  }
}
