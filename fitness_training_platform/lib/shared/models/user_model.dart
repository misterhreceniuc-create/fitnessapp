// ==================== lib/shared/models/user_model.dart ====================

/// @file user_model.dart
/// @brief User data model and role definitions for the fitness training platform
/// @details This file contains the core user data model and role enumeration that
/// represents all user types in the application (admin, trainer, trainee). It handles
/// user data serialization/deserialization and manages relationships between trainers
/// and trainees through ID references.

/// @enum UserRole
/// @brief Enumeration of user role types in the fitness training platform
/// @details Defines three distinct user roles with different access levels and capabilities:
/// - admin: System administrators with full access to manage all users and system settings
/// - trainer: Fitness trainers who can create workouts, manage trainees, and view progress
/// - trainee: End users who receive workout assignments and track their fitness progress
enum UserRole { admin, trainer, trainee }

/// @class UserModel
/// @brief Represents a user entity in the fitness training platform
/// @details This model encapsulates all user data including personal information, role,
/// and relationship data between trainers and trainees. The model supports three user types
/// (admin, trainer, trainee) with role-specific fields:
/// - Trainers have a traineeIds list containing IDs of assigned trainees
/// - Trainees have a trainerId reference to their assigned trainer
/// - Admins use neither field (both null)
///
/// The model provides JSON serialization for data persistence and network communication,
/// supporting the mock data storage pattern used throughout the application.
class UserModel {
  /// @brief Unique identifier for the user
  /// @details Used as the primary key for user lookups and relationship references.
  /// Generated as a string to support various ID generation strategies.
  final String id;

  /// @brief Full name of the user
  /// @details Display name used throughout the UI. No specific format enforced.
  final String name;

  /// @brief Email address of the user
  /// @details Used for login authentication and as a unique identifier.
  /// Must be unique across all users in the system.
  final String email;

  /// @brief Role of the user in the system
  /// @details Determines access permissions and available features.
  /// See UserRole enum for available role types.
  final UserRole role;

  /// @brief Timestamp when the user account was created
  /// @details Used for account tracking and sorting. Stored in UTC format
  /// and serialized as ISO8601 string for JSON persistence.
  final DateTime createdAt;

  /// @brief Reference to the trainer assigned to this user (trainee only)
  /// @details Only populated for trainee role users. Contains the ID of the
  /// trainer responsible for this trainee's workout programs. Null for
  /// admin and trainer roles.
  final String? trainerId;

  /// @brief List of trainee IDs assigned to this user (trainer only)
  /// @details Only populated for trainer role users. Contains IDs of all
  /// trainees assigned to this trainer. Null for admin and trainee roles.
  /// Used to establish trainer-trainee relationships and filter workout assignments.
  final List<String>? traineeIds;

  /// @brief User's password (plain text for development only)
  /// @details SECURITY WARNING: Stored as plain text for mock/development purposes.
  /// In production, this should be replaced with a hashed password field.
  /// Nullable for backward compatibility with existing users loaded from storage.
  final String? password;

  /// @brief Constructor for creating a UserModel instance
  /// @details Creates a new user model with all required and optional fields.
  /// Validates that role-specific fields are used appropriately:
  /// - trainerId should only be set for trainee role
  /// - traineeIds should only be set for trainer role
  ///
  /// @param id Unique identifier for the user (required)
  /// @param name Full name of the user (required)
  /// @param email Email address for authentication (required)
  /// @param role User's role in the system (required)
  /// @param createdAt Account creation timestamp (required)
  /// @param trainerId Optional trainer ID reference (trainee only)
  /// @param traineeIds Optional list of assigned trainee IDs (trainer only)
  /// @param password Optional password (plain text for development only)
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.trainerId,
    this.traineeIds,
    this.password,
  });

  /// @brief Factory constructor to create UserModel from JSON data
  /// @details Deserializes a JSON map into a UserModel instance. Handles type conversion
  /// for all fields including:
  /// - Role string to UserRole enum conversion
  /// - ISO8601 string to DateTime parsing
  /// - Dynamic list casting to List<String> for traineeIds
  ///
  /// This method is used when loading user data from SharedPreferences or mock API responses.
  ///
  /// @param json Map containing user data with keys matching field names
  /// @return UserModel instance populated with data from JSON
  /// @throws FormatException if createdAt string is not valid ISO8601 format
  /// @throws StateError if role string doesn't match any UserRole enum value
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'], // Extract user ID string
      name: json['name'], // Extract user name string
      email: json['email'], // Extract email string
      // Convert role string to UserRole enum by matching enum name
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      // Parse ISO8601 datetime string to DateTime object
      createdAt: DateTime.parse(json['createdAt']),
      trainerId: json['trainerId'], // Optional trainer reference (null if not present)
      // Cast dynamic list to List<String>, null-safe operation
      traineeIds: json['traineeIds']?.cast<String>(),
      password: json['password'], // Optional password field (null if not present)
    );
  }

  /// @brief Converts UserModel instance to JSON map
  /// @details Serializes all user fields into a JSON-compatible map structure.
  /// Performs necessary type conversions:
  /// - UserRole enum to string using .name property
  /// - DateTime to ISO8601 string format for standard datetime serialization
  ///
  /// The resulting map can be stored in SharedPreferences, sent over network,
  /// or used with the fromJson factory for round-trip serialization.
  ///
  /// @return Map<String, dynamic> containing all user data in JSON-compatible format.
  /// All fields use their original keys for consistency with fromJson method.
  Map<String, dynamic> toJson() {
    return {
      'id': id, // User unique identifier
      'name': name, // User display name
      'email': email, // User email for authentication
      'role': role.name, // Convert enum to string (e.g., "trainer", "trainee")
      'createdAt': createdAt.toIso8601String(), // Convert DateTime to ISO8601 string
      'trainerId': trainerId, // Optional trainer reference (null preserved)
      'traineeIds': traineeIds, // Optional trainee list (null preserved)
      'password': password, // Optional password (null preserved)
    };
  }

  /// @brief Creates a copy of this UserModel with optionally modified fields
  /// @details Implements the immutable update pattern. Returns a new UserModel
  /// instance with specified fields replaced while preserving other fields.
  /// Useful for updating user data without mutating the original object.
  ///
  /// @param id New user ID (optional)
  /// @param name New name (optional)
  /// @param email New email (optional)
  /// @param role New role (optional)
  /// @param createdAt New creation timestamp (optional)
  /// @param trainerId New trainer reference (optional)
  /// @param traineeIds New trainee list (optional)
  /// @param password New password (optional)
  /// @return New UserModel instance with updated values
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    String? trainerId,
    List<String>? traineeIds,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      trainerId: trainerId ?? this.trainerId,
      traineeIds: traineeIds ?? this.traineeIds,
      password: password ?? this.password,
    );
  }
}