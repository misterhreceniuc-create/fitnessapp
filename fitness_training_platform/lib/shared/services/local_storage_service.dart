/// @file local_storage_service.dart
/// @brief Service for persistent data storage using SharedPreferences
/// @details Provides cross-platform storage (web, mobile, desktop) for all app data
/// Uses JSON serialization to store complex objects in SharedPreferences

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// @class LocalStorageService
/// @brief Handles all persistent storage operations for the application
/// @details Uses SharedPreferences as the underlying storage mechanism, which works
/// on all platforms (web uses localStorage, mobile/desktop use native storage)
class LocalStorageService {
  /// @brief Storage key for user data
  static const String _usersKey = 'users_data';

  /// @brief Storage key for training/workout data
  static const String _trainingsKey = 'trainings_data';

  /// @brief Storage key for fitness goals data
  static const String _goalsKey = 'goals_data';

  /// @brief Storage key for body measurements data
  static const String _measurementsKey = 'measurements_data';

  /// @brief Storage key for daily steps data
  static const String _stepsKey = 'steps_data';

  /// @brief Storage key for exercise history/logs
  static const String _exerciseHistoryKey = 'exercise_history_data';

  /// @brief Storage key for workout templates
  static const String _templatesKey = 'templates_data';

  /// @brief SharedPreferences instance for data persistence
  final SharedPreferences _prefs;

  /// @brief Constructor
  /// @param _prefs SharedPreferences instance injected via dependency injection
  LocalStorageService(this._prefs);

  /// @brief Generic method to save data to storage
  /// @details Serializes the data list to JSON and stores it in SharedPreferences
  /// @param key Storage key to identify the data type
  /// @param data List of JSON objects to save
  /// @return Future that completes when save operation finishes
  Future<void> _saveData(String key, List<Map<String, dynamic>> data) async {
    try {
      // Convert list of objects to JSON string
      final jsonString = json.encode(data);
      // Store in SharedPreferences
      await _prefs.setString(key, jsonString);
      // Log success for debugging
      print('Data saved to $key: ${data.length} items');
    } catch (e) {
      // Log any errors during save operation
      print('Error saving data to $key: $e');
    }
  }

  /// @brief Generic method to load data from storage
  /// @details Retrieves JSON string from SharedPreferences and deserializes it
  /// @param key Storage key to identify the data type
  /// @return Future containing list of JSON objects, or empty list if no data exists
  Future<List<Map<String, dynamic>>> _loadData(String key) async {
    try {
      // Retrieve JSON string from SharedPreferences
      final jsonString = _prefs.getString(key);
      // Check if data exists
      if (jsonString != null && jsonString.isNotEmpty) {
        // Decode JSON string to list
        final List<dynamic> jsonData = json.decode(jsonString);
        // Log success for debugging
        print('Data loaded from $key: ${jsonData.length} items');
        // Cast to proper type and return
        return jsonData.cast<Map<String, dynamic>>();
      }
      // No data found, return empty list
      print('No data for $key, returning empty list');
      return [];
    } catch (e) {
      // Log any errors during load operation
      print('Error loading data from $key: $e');
      return [];
    }
  }

  /// @brief Save user accounts to storage
  /// @param users List of user objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveUsers(List<Map<String, dynamic>> users) async {
    await _saveData(_usersKey, users);
  }

  /// @brief Load user accounts from storage
  /// @return Future containing list of user JSON objects
  Future<List<Map<String, dynamic>>> loadUsers() async {
    return await _loadData(_usersKey);
  }

  /// @brief Save workout/training assignments to storage
  /// @param trainings List of training objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveTrainings(List<Map<String, dynamic>> trainings) async {
    await _saveData(_trainingsKey, trainings);
  }

  /// @brief Load workout/training assignments from storage
  /// @return Future containing list of training JSON objects
  Future<List<Map<String, dynamic>>> loadTrainings() async {
    return await _loadData(_trainingsKey);
  }

  /// @brief Save fitness goals to storage
  /// @param goals List of goal objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveGoals(List<Map<String, dynamic>> goals) async {
    await _saveData(_goalsKey, goals);
  }

  /// @brief Load fitness goals from storage
  /// @return Future containing list of goal JSON objects
  Future<List<Map<String, dynamic>>> loadGoals() async {
    return await _loadData(_goalsKey);
  }

  /// @brief Save body measurements to storage
  /// @param measurements List of measurement objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveMeasurements(List<Map<String, dynamic>> measurements) async {
    await _saveData(_measurementsKey, measurements);
  }

  /// @brief Load body measurements from storage
  /// @return Future containing list of measurement JSON objects
  Future<List<Map<String, dynamic>>> loadMeasurements() async {
    return await _loadData(_measurementsKey);
  }

  /// @brief Save daily step counts to storage
  /// @param steps List of step entry objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveSteps(List<Map<String, dynamic>> steps) async {
    await _saveData(_stepsKey, steps);
  }

  /// @brief Load daily step counts from storage
  /// @return Future containing list of step entry JSON objects
  Future<List<Map<String, dynamic>>> loadSteps() async {
    return await _loadData(_stepsKey);
  }

  /// @brief Save exercise history/logs to storage
  /// @param history List of exercise history objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveExerciseHistory(List<Map<String, dynamic>> history) async {
    await _saveData(_exerciseHistoryKey, history);
  }

  /// @brief Load exercise history/logs from storage
  /// @return Future containing list of exercise history JSON objects
  Future<List<Map<String, dynamic>>> loadExerciseHistory() async {
    return await _loadData(_exerciseHistoryKey);
  }

  /// @brief Save workout templates to storage
  /// @param templates List of template objects serialized to JSON
  /// @return Future that completes when save finishes
  Future<void> saveTemplates(List<Map<String, dynamic>> templates) async {
    await _saveData(_templatesKey, templates);
  }

  /// @brief Load workout templates from storage
  /// @return Future containing list of template JSON objects
  Future<List<Map<String, dynamic>>> loadTemplates() async {
    return await _loadData(_templatesKey);
  }

  /// @brief Clear all stored data
  /// @details Removes all data from SharedPreferences. Useful for testing/debugging
  /// or when user wants to reset the app to initial state
  /// @return Future that completes when all data is cleared
  Future<void> clearAllData() async {
    try {
      // List of all storage keys to clear
      final keys = [
        _usersKey,
        _trainingsKey,
        _goalsKey,
        _measurementsKey,
        _stepsKey,
        _exerciseHistoryKey,
        _templatesKey,
      ];

      // Remove each key from SharedPreferences
      for (final key in keys) {
        await _prefs.remove(key);
        print('Deleted $key');
      }
      print('All data cleared');
    } catch (e) {
      // Log any errors during clear operation
      print('Error clearing data: $e');
    }
  }
}
