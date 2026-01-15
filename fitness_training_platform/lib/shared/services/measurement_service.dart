/// @file measurement_service.dart
/// @brief Service for managing trainee body measurements and weight tracking
/// @details This service provides comprehensive functionality for storing, retrieving,
/// and managing trainee body measurements including weight and body dimensions.
/// It enforces a one-measurement-per-day policy and persists data using LocalStorageService.
/// All operations include simulated network delays to mimic real API behavior.

import '../models/measurement_model.dart';
import 'local_storage_service.dart';

/// @class MeasurementService
/// @brief Service class that manages trainee body measurements and weight tracking
/// @details Provides CRUD operations for measurement data with the following key features:
/// - One measurement per trainee per day (updates existing if duplicate date)
/// - Automatic sorting by date (newest first)
/// - Persistent storage using LocalStorageService
/// - Mock API delays for realistic behavior (300-500ms)
/// - Support for weight and custom body measurements (chest, waist, hips, etc.)
class MeasurementService {
  /// @brief Local storage service instance for persisting measurement data
  final LocalStorageService _storage;

  /// @brief In-memory cache of all measurement records
  /// @details Stores all loaded measurements for quick access. Changes are
  /// synchronized to persistent storage via _saveToStorage()
  final List<MeasurementModel> _measurements = [];

  /// @brief Constructor that initializes the service with a storage instance
  /// @param _storage LocalStorageService instance for data persistence
  MeasurementService(this._storage);

  /// @brief Loads all measurements from persistent storage into memory
  /// @details Clears the current in-memory cache and repopulates it with data
  /// from LocalStorageService. This should be called once during app initialization.
  /// Prints debug information about the number of measurements loaded.
  /// @return Future that completes when loading is finished
  Future<void> loadFromStorage() async {
    // Retrieve serialized measurement data from storage
    final measurementsData = await _storage.loadMeasurements();

    // Clear existing cache to prevent duplicates
    _measurements.clear();

    // Deserialize JSON data into MeasurementModel objects
    _measurements.addAll(measurementsData.map((json) => MeasurementModel.fromJson(json)));

    // Debug logging for verification
    print('Loaded ${_measurements.length} measurements from storage');
  }

  /// @brief Private method to persist current in-memory measurements to storage
  /// @details Serializes all measurements to JSON and saves them using LocalStorageService.
  /// Called internally after any create, update, or delete operation to maintain data consistency.
  /// @return Future that completes when save operation is finished
  Future<void> _saveToStorage() async {
    // Serialize all measurements to JSON format
    final measurementsData = _measurements.map((m) => m.toJson()).toList();

    // Persist to storage
    await _storage.saveMeasurements(measurementsData);
  }

  /// @brief Retrieves all measurements for a specific trainee, sorted by date
  /// @details Filters the measurement cache by traineeId and returns results
  /// sorted in descending order (newest first). Includes a 500ms mock API delay.
  /// @param traineeId The unique identifier of the trainee
  /// @return Future containing list of MeasurementModel objects sorted by date (newest first)
  Future<List<MeasurementModel>> getMeasurementsForTrainee(String traineeId) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 500));

    // Filter by traineeId and sort by date (newest first)
    final measurements = _measurements
        .where((m) => m.traineeId == traineeId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return measurements;
  }

  /// @brief Retrieves today's measurement entry for a specific trainee
  /// @details Searches for a measurement that matches both the traineeId and today's date
  /// (time component is ignored). Uses date normalization to compare only year, month, day.
  /// Includes a 300ms mock API delay.
  /// @param traineeId The unique identifier of the trainee
  /// @return Future containing the MeasurementModel if found, null otherwise
  Future<MeasurementModel?> getTodayMeasurement(String traineeId) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 300));

    // Get current date normalized to midnight (ignore time component)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Search for measurement matching traineeId and today's date
      return _measurements.firstWhere((m) {
        // Normalize measurement date to midnight for comparison
        final measurementDate = DateTime(m.date.year, m.date.month, m.date.day);
        return m.traineeId == traineeId && measurementDate == today;
      });
    } catch (e) {
      // Return null if no measurement found for today
      return null;
    }
  }

  /// @brief Adds a new measurement or updates existing one for today
  /// @details Enforces the one-measurement-per-day policy. If a measurement already
  /// exists for the trainee on today's date, it will be updated with new values.
  /// Otherwise, a new measurement entry is created. The measurement ID is preserved
  /// during updates or generated from current timestamp for new entries.
  /// Includes a 500ms mock API delay and persists changes to storage.
  /// @param traineeId The unique identifier of the trainee
  /// @param weight The trainee's body weight in kilograms
  /// @param bodyMeasurements Optional map of body measurements (e.g., {"chest": 95.5, "waist": 80.0})
  /// @return Future containing the created or updated MeasurementModel
  Future<MeasurementModel> addMeasurement({
    required String traineeId,
    required double weight,
    Map<String, double>? bodyMeasurements,
  }) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 500));

    // Get current date normalized to midnight
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if measurement already exists for today
    final existingIndex = _measurements.indexWhere((m) {
      // Normalize measurement date for comparison
      final measurementDate = DateTime(m.date.year, m.date.month, m.date.day);
      return m.traineeId == traineeId && measurementDate == today;
    });

    // Create measurement with existing ID (update) or new ID (create)
    final measurement = MeasurementModel(
      id: existingIndex >= 0
          ? _measurements[existingIndex].id // Preserve existing ID for updates
          : DateTime.now().millisecondsSinceEpoch.toString(), // Generate new ID
      traineeId: traineeId,
      date: DateTime.now(),
      weight: weight,
      bodyMeasurements: bodyMeasurements ?? {}, // Default to empty map if not provided
    );

    // Update existing measurement or add new one
    if (existingIndex >= 0) {
      _measurements[existingIndex] = measurement; // Replace existing entry
    } else {
      _measurements.add(measurement); // Add new entry
    }

    // Persist changes to storage
    await _saveToStorage();
    return measurement;
  }

  /// @brief Retrieves the most recent weight measurement for a trainee
  /// @details Fetches all measurements for the trainee (sorted by date, newest first)
  /// and returns the weight from the most recent entry. Includes a 500ms mock API delay.
  /// @param traineeId The unique identifier of the trainee
  /// @return Future containing the latest weight in kilograms, or null if no measurements exist
  Future<double?> getLatestWeight(String traineeId) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 500));

    // Get all measurements sorted by date (newest first)
    final measurements = await getMeasurementsForTrainee(traineeId);

    // Return null if no measurements exist
    if (measurements.isEmpty) return null;

    // Return weight from most recent measurement
    return measurements.first.weight;
  }

  /// @brief Permanently deletes a measurement entry by its ID
  /// @details Removes the measurement from the in-memory cache and persists
  /// the change to storage. Includes a 500ms mock API delay. If the measurement
  /// ID does not exist, the operation completes silently without error.
  /// @param measurementId The unique identifier of the measurement to delete
  /// @return Future that completes when deletion is finished
  Future<void> deleteMeasurement(String measurementId) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 500));

    // Remove measurement matching the provided ID
    _measurements.removeWhere((m) => m.id == measurementId);

    // Persist changes to storage
    await _saveToStorage();
  }

  /// @brief Updates only the body measurements of an existing entry
  /// @details Allows modifying the bodyMeasurements map without affecting weight,
  /// date, or traineeId. Preserves all other fields from the original measurement.
  /// Includes a 500ms mock API delay and persists changes. If the measurement ID
  /// does not exist, the operation completes silently without making changes.
  /// @param measurementId The unique identifier of the measurement to update
  /// @param bodyMeasurements New map of body measurements to replace existing ones
  /// @return Future that completes when update is finished
  Future<void> updateBodyMeasurements({
    required String measurementId,
    required Map<String, double> bodyMeasurements,
  }) async {
    // Mock API delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the measurement by ID
    final index = _measurements.indexWhere((m) => m.id == measurementId);

    // Update only if measurement exists
    if (index != -1) {
      final existing = _measurements[index];

      // Create updated measurement preserving all fields except bodyMeasurements
      _measurements[index] = MeasurementModel(
        id: existing.id,
        traineeId: existing.traineeId,
        date: existing.date,
        weight: existing.weight,
        bodyMeasurements: bodyMeasurements, // Replace with new measurements
      );

      // Persist changes to storage
      await _saveToStorage();
    }
  }
}
