/// @file goal_model.dart
/// @brief Goal model for fitness training platform
/// @details This file defines the data model for user fitness goals in the training platform.
///          It supports three types of goals: weight-based, measurement-based, and performance-based.
///          Goals track progress from a current value towards a target value with a deadline.
///          Goals are created by trainers for their trainees and can be monitored for completion.
// ==================== lib/shared/models/goal_model.dart ====================

/// @enum GoalType
/// @brief Enumeration of supported goal types in the fitness platform
/// @details Defines three categories of fitness goals:
///          - weight: Goals related to body weight changes (e.g., weight loss, weight gain)
///          - measurement: Goals related to body measurements (e.g., waist size, muscle circumference)
///          - performance: Goals related to exercise performance (e.g., max lift, run time, endurance)
enum GoalType {
  weight,        /// Weight-based goals (body weight tracking)
  measurement,   /// Body measurement goals (circumferences, dimensions)
  performance    /// Performance-based goals (strength, speed, endurance metrics)
}

/// @class GoalModel
/// @brief Represents a fitness goal assigned to a trainee by a trainer
/// @details Immutable data model that encapsulates all information about a fitness goal.
///          Goals track progress from a current value towards a target value with a specific deadline.
///          The model supports JSON serialization/deserialization for data persistence and API communication.
///          Progress is calculated as a percentage of completion based on current vs. target values.
///          Goals are tied to both a trainee (who works towards the goal) and a trainer (who created and monitors the goal).
class GoalModel {
  /// @brief Unique identifier for the goal
  final String id;

  /// @brief Unique identifier of the trainee assigned to this goal
  final String traineeId;

  /// @brief Unique identifier of the trainer who created and manages this goal
  final String trainerId;

  /// @brief Human-readable name/description of the goal
  final String name;

  /// @brief Type category of the goal (weight, measurement, or performance)
  final GoalType type;

  /// @brief Target value to be achieved (numeric goal endpoint)
  final double targetValue;

  /// @brief Current progress value (updated as trainee makes progress)
  final double currentValue;

  /// @brief Unit of measurement for the goal values (e.g., "kg", "cm", "reps")
  final String unit;

  /// @brief Target deadline date for achieving the goal
  final DateTime deadline;

  /// @brief Completion status flag (true if goal has been achieved)
  final bool isCompleted;

  /// @brief Timestamp when the goal was created
  final DateTime createdAt;

  /// @brief Constructor for creating a GoalModel instance
  /// @details Initializes a goal with all required fields. The isCompleted field defaults to false
  ///          if not provided, assuming newly created goals start in an incomplete state.
  /// @param id Unique identifier for the goal
  /// @param traineeId ID of the trainee assigned to this goal
  /// @param trainerId ID of the trainer who created this goal
  /// @param name Human-readable goal name/description
  /// @param type Category of the goal (weight, measurement, or performance)
  /// @param targetValue Numeric target to achieve
  /// @param currentValue Current progress value
  /// @param unit Unit of measurement for values (e.g., "kg", "cm", "reps")
  /// @param deadline Target date for goal completion
  /// @param isCompleted Optional completion status (defaults to false)
  /// @param createdAt Timestamp of goal creation
  GoalModel({
    required this.id,
    required this.traineeId,
    required this.trainerId,
    required this.name,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.deadline,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// @brief Factory constructor for deserializing a GoalModel from JSON
  /// @details Creates a GoalModel instance from a JSON map. Performs type conversions and parsing:
  ///          - Converts GoalType from string to enum by matching enum names
  ///          - Converts numeric values to double type
  ///          - Parses ISO 8601 date strings to DateTime objects
  ///          - Handles missing isCompleted field with false default
  /// @param json Map containing goal data in JSON format
  /// @return A new GoalModel instance populated with data from the JSON map
  /// @throws FormatException if date strings are not valid ISO 8601 format
  /// @throws StateError if GoalType string doesn't match any enum value
  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'],
      traineeId: json['traineeId'],
      trainerId: json['trainerId'],
      name: json['name'],
      // Convert string representation back to GoalType enum
      type: GoalType.values.firstWhere((e) => e.name == json['type']),
      // Ensure numeric values are stored as doubles
      targetValue: json['targetValue'].toDouble(),
      currentValue: json['currentValue'].toDouble(),
      unit: json['unit'],
      // Parse ISO 8601 date strings to DateTime objects
      deadline: DateTime.parse(json['deadline']),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  /// @brief Serializes the GoalModel instance to a JSON map
  /// @details Converts all fields to JSON-compatible types for storage or API transmission:
  ///          - Converts GoalType enum to its string name representation
  ///          - Converts DateTime objects to ISO 8601 formatted strings
  ///          - All other primitive types (String, double, bool) are stored directly
  /// @return A Map<String, dynamic> containing all goal data in JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      'trainerId': trainerId,
      'name': name,
      'type': type.name,  // Convert enum to string representation
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'deadline': deadline.toIso8601String(),  // Convert DateTime to ISO 8601 string
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),  // Convert DateTime to ISO 8601 string
    };
  }

  /// @brief Calculates the current progress towards the goal as a percentage
  /// @details Computes the completion percentage by dividing current value by target value
  ///          and multiplying by 100. The result is clamped between 0 and 100 to handle
  ///          edge cases where current value exceeds target or is negative.
  ///          Returns 0 if target value is 0 to prevent division by zero errors.
  /// @return A double representing progress percentage (0.0 to 100.0)
  double get progressPercentage {
    // Prevent division by zero if target is not set or is zero
    if (targetValue == 0) return 0;

    // Calculate percentage and clamp to valid range [0, 100]
    // Clamping handles cases where currentValue exceeds targetValue (over-achievement)
    // or is negative (regression)
    return (currentValue / targetValue * 100).clamp(0, 100);
  }
}