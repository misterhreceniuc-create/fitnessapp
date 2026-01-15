/// @file measurement_model.dart
/// @brief Defines the data model for body measurements and weight tracking
/// @details This file contains the MeasurementModel class which represents
/// a snapshot of a trainee's body measurements at a specific point in time.
/// It includes weight and various body part measurements (e.g., chest, waist,
/// arms) stored in a flexible key-value format.

// ==================== lib/shared/models/measurement_model.dart ====================

/// @class MeasurementModel
/// @brief Data model representing a trainee's body measurements at a specific date
/// @details The MeasurementModel class encapsulates all measurement data for a trainee
/// including their weight and various body part measurements. This model supports
/// tracking progress over time by storing measurements with timestamps. Body measurements
/// are stored in a flexible Map structure allowing for custom measurement types
/// (e.g., "chest": 100.0, "waist": 85.0, "biceps": 35.0).
///
/// This model is used by the measurement tracking system to:
/// - Record periodic body measurements for trainees
/// - Track weight changes over time
/// - Monitor body composition progress
/// - Generate progress reports and visualizations
class MeasurementModel {
  /// @brief Unique identifier for this measurement record
  final String id;

  /// @brief Unique identifier of the trainee these measurements belong to
  final String traineeId;

  /// @brief The date and time when these measurements were recorded
  final DateTime date;

  /// @brief The trainee's weight in kilograms at the time of measurement
  final double weight;

  /// @brief Map of body part names to their measurements in centimeters
  /// @details Keys are body part names (e.g., "chest", "waist", "arms", "thighs")
  /// and values are the measurements in centimeters. This flexible structure
  /// allows different measurement protocols without changing the data model.
  final Map<String, double> bodyMeasurements;

  /// @brief Constructor for creating a new measurement model instance
  /// @details Creates a MeasurementModel with all required fields. All parameters
  /// must be provided as there are no default values.
  /// @param id Unique identifier for this measurement record
  /// @param traineeId Unique identifier of the trainee
  /// @param date Date and time of measurement
  /// @param weight Trainee's weight in kilograms
  /// @param bodyMeasurements Map of body part measurements in centimeters
  MeasurementModel({
    required this.id,
    required this.traineeId,
    required this.date,
    required this.weight,
    required this.bodyMeasurements,
  });

  /// @brief Factory constructor to create a MeasurementModel from JSON data
  /// @details Deserializes a JSON map into a MeasurementModel instance. This is used
  /// when loading measurement data from storage or receiving data from an API.
  /// The date field is parsed from ISO 8601 string format. The weight is explicitly
  /// converted to double to handle both int and double JSON values. Body measurements
  /// map is converted to ensure proper typing of all values as doubles.
  /// @param json Map containing the JSON representation of a measurement
  /// @return A new MeasurementModel instance populated with data from the JSON map
  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    return MeasurementModel(
      // Extract the unique identifier
      id: json['id'],
      // Extract the trainee identifier
      traineeId: json['traineeId'],
      // Parse the ISO 8601 date string into a DateTime object
      date: DateTime.parse(json['date']),
      // Convert weight to double (handles both int and double from JSON)
      weight: json['weight'].toDouble(),
      // Convert body measurements map to ensure all values are doubles
      bodyMeasurements: Map<String, double>.from(json['bodyMeasurements']),
    );
  }

  /// @brief Converts this MeasurementModel instance to a JSON-serializable map
  /// @details Serializes the measurement model into a map that can be converted to JSON.
  /// This is used when saving measurement data to storage or sending data to an API.
  /// The date is converted to ISO 8601 string format for consistent date representation.
  /// @return A map containing all measurement fields in JSON-compatible format
  Map<String, dynamic> toJson() {
    return {
      // Unique identifier for the measurement record
      'id': id,
      // Reference to the trainee this measurement belongs to
      'traineeId': traineeId,
      // Date converted to ISO 8601 string format (e.g., "2025-01-13T10:30:00.000Z")
      'date': date.toIso8601String(),
      // Weight in kilograms
      'weight': weight,
      // Map of body part measurements (keys: body part names, values: measurements in cm)
      'bodyMeasurements': bodyMeasurements,
    };
  }
}