/// @file steps_model.dart
/// @brief Data model for tracking daily step counts
/// @details This file defines the StepsModel class which represents a trainee's
/// step count data for a specific date. It supports both manual entry and automatic
/// health data integration, allowing comprehensive activity tracking within the
/// fitness training platform.

/// @class StepsModel
/// @brief Represents a daily step count record for a trainee
/// @details This model encapsulates step count information including the associated
/// trainee, date of recording, total steps taken, and the source of the data
/// (manual entry vs. health data integration). The model provides serialization
/// capabilities for data persistence and network communication through JSON
/// conversion methods. Step data can be used for activity tracking, goal monitoring,
/// and generating progress reports.
class StepsModel {
  /// @brief Unique identifier for this step record
  final String id;

  /// @brief ID of the trainee associated with this step count
  final String traineeId;

  /// @brief Date when the steps were recorded
  final DateTime date;

  /// @brief Total number of steps taken on the recorded date
  final int steps;

  /// @brief Indicates the source of the step data
  /// @details true if manually entered by user, false if automatically imported
  /// from health data integration (e.g., fitness tracker, health app)
  final bool isManual;

  /// @brief Constructs a new StepsModel instance
  /// @details Creates an immutable step record with all required fields.
  /// All parameters must be provided as there are no default values.
  /// @param id Unique identifier for this step record
  /// @param traineeId ID of the trainee who recorded these steps
  /// @param date The date when these steps were taken
  /// @param steps The total step count for the day
  /// @param isManual Whether this data was manually entered (true) or from health data (false)
  StepsModel({
    required this.id,
    required this.traineeId,
    required this.date,
    required this.steps,
    required this.isManual,
  });

  /// @brief Creates a StepsModel instance from a JSON map
  /// @details Deserializes a JSON map into a StepsModel object. The date field
  /// is parsed from ISO 8601 string format. If the 'isManual' field is missing
  /// from the JSON, it defaults to false (assuming health data integration).
  /// @param json Map containing the serialized step data with keys:
  ///   - 'id': String identifier
  ///   - 'traineeId': String trainee identifier
  ///   - 'date': ISO 8601 formatted date string
  ///   - 'steps': Integer step count
  ///   - 'isManual': Boolean indicating data source (optional, defaults to false)
  /// @return A new StepsModel instance populated with data from the JSON map
  factory StepsModel.fromJson(Map<String, dynamic> json) {
    return StepsModel(
      id: json['id'],
      traineeId: json['traineeId'],
      // Parse ISO 8601 date string into DateTime object
      date: DateTime.parse(json['date']),
      steps: json['steps'],
      // Default to false if isManual field is not present (assumes health data)
      isManual: json['isManual'] ?? false,
    );
  }

  /// @brief Converts this StepsModel instance to a JSON map
  /// @details Serializes the model into a JSON-compatible map structure suitable
  /// for data persistence, API communication, or local storage. The date is
  /// converted to ISO 8601 string format for consistent date representation
  /// across different platforms and time zones.
  /// @return A Map<String, dynamic> containing all fields in JSON-serializable format:
  ///   - 'id': String identifier
  ///   - 'traineeId': String trainee identifier
  ///   - 'date': ISO 8601 formatted date string
  ///   - 'steps': Integer step count
  ///   - 'isManual': Boolean indicating data source
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      // Convert DateTime to ISO 8601 string for consistent serialization
      'date': date.toIso8601String(),
      'steps': steps,
      'isManual': isManual,
    };
  }
}
