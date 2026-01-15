/// @file auth_service.dart
/// @brief Authentication service for the fitness training platform
/// @details Handles user authentication, registration, session management, and user CRUD operations.
/// Uses SharedPreferences for persistent storage of the current user session and LocalStorageService
/// for maintaining the user database. Provides mock authentication with default users for development.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';
import 'user_service.dart';
import '../../core/dependency_injection/injection_container.dart';

/// @class AuthService
/// @brief Core authentication and user management service
/// @details Manages user authentication lifecycle including login, registration, logout, and session persistence.
/// Maintains an in-memory list of users synchronized with LocalStorageService for persistence.
/// Provides default mock users (admin, trainer, trainees) for development and testing.
/// Uses SharedPreferences to persist the currently authenticated user across app sessions.
class AuthService {
  /// @brief Local storage service for persisting user data
  final LocalStorageService _storage;

  /// @brief User service for user-related operations
  final UserService _userService;

  /// @brief SharedPreferences instance for session management
  final SharedPreferences _prefs = sl.get<SharedPreferences>();

  /// @brief Storage key for the current authenticated user in SharedPreferences
  static const String _userKey = 'current_user';

  /// @brief In-memory list of all registered users
  List<UserModel> _users = [];

  /// @brief Constructor for AuthService
  /// @details Initializes the service with required dependencies for storage and user operations
  /// @param _storage LocalStorageService instance for data persistence
  /// @param _userService UserService instance for user management operations
  AuthService(this._storage, this._userService);

  /// @brief Loads user data from persistent storage
  /// @details Retrieves all users from LocalStorageService and populates the in-memory user list.
  /// If no users exist in storage, initializes the system with default mock users (admin, trainer, trainees).
  /// This method should be called during app initialization to restore user data.
  /// @return Future<void> Completes when users are loaded and initialized
  Future<void> loadFromStorage() async {
    final usersData = await _storage.loadUsers();
    if (usersData.isEmpty) {
      // Initialize with default users if no data exists in storage
      _users = _getDefaultUsers();
      await saveToStorage();
      print('Initialized with ${_users.length} default users');
    } else {
      // Deserialize user data from JSON and populate in-memory list
      _users = usersData.map((json) => UserModel.fromJson(json)).toList();
      print('Loaded ${_users.length} users from storage');
    }
  }

  /// @brief Saves all users to persistent storage
  /// @details Serializes the in-memory user list to JSON and persists it via LocalStorageService.
  /// Should be called after any modifications to the user list (registration, updates, deletions).
  /// @return Future<void> Completes when user data is successfully persisted
  Future<void> saveToStorage() async {
    // Serialize all users to JSON format
    final usersData = _users.map((user) => user.toJson()).toList();
    await _storage.saveUsers(usersData);
  }

  /// @brief Creates the default set of mock users for system initialization
  /// @details Generates a predefined list of users for development and testing purposes:
  /// - 1 Admin user (admin@fitness.com, ID: '1')
  /// - 1 Trainer user (trainer@fitness.com, ID: '2') with 3 assigned trainees
  /// - 3 Trainee users (john.doe@fitness.com, jane.smith@fitness.com, mike.johnson@fitness.com)
  ///   all assigned to the default trainer with varying registration dates
  /// @return List<UserModel> List of 5 default users with complete profile data
  List<UserModel> _getDefaultUsers() {
    return [
      // Admin user for system management
      UserModel(
        id: '1',
        name: 'Admin User',
        email: 'admin@fitness.com',
        role: UserRole.admin,
        createdAt: DateTime.now(),
        password: 'admin123',
      ),
      // Trainer user with 3 assigned trainees
      UserModel(
        id: '2',
        name: 'John Trainer',
        email: 'trainer@fitness.com',
        role: UserRole.trainer,
        createdAt: DateTime.now(),
        traineeIds: ['trainee1', 'trainee2', 'trainee3'],
        password: 'trainer123',
      ),
      // Trainee 1: Registered 30 days ago
      UserModel(
        id: 'trainee1',
        name: 'John Doe',
        email: 'john.doe@fitness.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        trainerId: '2',
        password: 'trainee123',
      ),
      // Trainee 2: Registered 45 days ago
      UserModel(
        id: 'trainee2',
        name: 'Jane Smith',
        email: 'jane.smith@fitness.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        trainerId: '2',
        password: 'trainee123',
      ),
      // Trainee 3: Registered 15 days ago
      UserModel(
        id: 'trainee3',
        name: 'Mike Johnson',
        email: 'mike.johnson@fitness.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        trainerId: '2',
        password: 'trainee123',
      ),
    ];
  }

  /// @brief Authenticates a user with email and password
  /// @details Performs mock authentication by searching for a user with the matching email.
  /// Note: Password validation is not implemented in this mock version.
  /// Simulates network delay with a 1-second artificial delay.
  /// On successful authentication, saves the user session to SharedPreferences.
  /// @param email User's email address for authentication
  /// @param password User's password (not validated in mock implementation)
  /// @return Future<UserModel> The authenticated user object
  /// @throws Exception if no user is found with the provided email
  Future<UserModel> login(String email, String password) async {
    // Simulate network delay for realistic behavior
    await Future.delayed(const Duration(seconds: 1));

    print('Attempting login with: $email');

    // Search for user by email (password validation not implemented in mock)
    final user = _users.firstWhere(
      (user) => user.email == email,
      orElse: () => throw Exception('Invalid email or password'),
    );

    print('Login completed. Authenticated: true');
    print('User role: ${user.role}');

    // Persist authenticated user session
    await _saveCurrentUser(user);
    return user;
  }

  /// @brief Registers a new user in the system
  /// @details Creates a new user account with the provided credentials and role.
  /// Validates that the email is not already registered in the system.
  /// Generates a unique UUID for the new user and sets creation timestamp.
  /// Simulates network delay with a 1-second artificial delay.
  /// Saves the new user to storage and establishes an authenticated session.
  /// @param name Full name of the user
  /// @param email Email address for the user (must be unique)
  /// @param password User's password (stored but not validated in mock implementation)
  /// @param role User role (admin, trainer, or trainee)
  /// @return Future<UserModel> The newly created user object
  /// @throws Exception if a user with the provided email already exists
  Future<UserModel> register(String name, String email, String password, UserRole role) async {
    // Simulate network delay for realistic behavior
    await Future.delayed(const Duration(seconds: 1));

    // Validate email uniqueness
    final existingUser = _users.where((user) => user.email == email);
    if (existingUser.isNotEmpty) {
      throw Exception('User with this email already exists');
    }

    // Create new user with generated UUID and current timestamp
    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      password: password,
    );

    // Add to user list and persist to storage
    _users.add(newUser);
    await saveToStorage();

    // Automatically log in the newly registered user
    await _saveCurrentUser(newUser);
    return newUser;
  }

  /// @brief Creates a new user (admin operation)
  /// @details Creates a new user account with the provided credentials without auto-login.
  /// This method is specifically for admin operations to create users of any role.
  /// Validates that the email is not already registered in the system.
  /// If creating a trainee with a trainerId, establishes the bidirectional trainer-trainee relationship.
  /// Simulates network delay with a 500ms artificial delay.
  /// @param name Full name of the user
  /// @param email Email address for the user (must be unique)
  /// @param password User's password (stored in plain text for mock implementation)
  /// @param role User role (admin, trainer, or trainee)
  /// @param trainerId Optional trainer ID for trainee assignment
  /// @return Future<UserModel> The newly created user object
  /// @throws Exception if a user with the provided email already exists
  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? trainerId,
  }) async {
    // Simulate network delay for realistic behavior
    await Future.delayed(const Duration(milliseconds: 500));

    // Validate email uniqueness
    final existingUser = _users.where((user) => user.email == email);
    if (existingUser.isNotEmpty) {
      throw Exception('User with this email already exists');
    }

    // Create new user with generated UUID and current timestamp
    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      password: password,
      trainerId: trainerId,
    );

    // Add to user list and persist to storage
    _users.add(newUser);

    // If trainee with trainer assignment, establish bidirectional relationship
    if (role == UserRole.trainee && trainerId != null) {
      await _assignTraineeToTrainer(newUser.id, trainerId);
    }

    await saveToStorage();
    print('Created new ${role.name} user: $name ($email)');
    return newUser;
  }

  /// @brief Assigns a trainee to a trainer (bidirectional relationship)
  /// @details Updates the trainer's traineeIds list to include the new trainee.
  /// Maintains the bidirectional relationship between trainer and trainee.
  /// Private helper method used internally by createUser().
  /// @param traineeId The ID of the trainee to assign
  /// @param trainerId The ID of the trainer to assign to
  /// @return Future<void> Completes when the relationship is established
  /// @throws Exception if the trainer is not found
  Future<void> _assignTraineeToTrainer(String traineeId, String trainerId) async {
    // Find the trainer
    final trainerIndex = _users.indexWhere((u) => u.id == trainerId);
    if (trainerIndex == -1) {
      throw Exception('Trainer not found');
    }

    final trainer = _users[trainerIndex];

    // Update trainer's traineeIds list
    final updatedTraineeIds = List<String>.from(trainer.traineeIds ?? []);
    if (!updatedTraineeIds.contains(traineeId)) {
      updatedTraineeIds.add(traineeId);

      // Update trainer with new trainee list
      _users[trainerIndex] = trainer.copyWith(traineeIds: updatedTraineeIds);
      print('Assigned trainee $traineeId to trainer $trainerId');
    }
  }

  /// @brief Logs out the current authenticated user
  /// @details Clears the user session by removing the current user data from SharedPreferences.
  /// Does not affect the user list in storage, only terminates the active session.
  /// @return Future<void> Completes when the session is cleared
  Future<void> logout() async {
    await _prefs.remove(_userKey);
  }

  /// @brief Retrieves the currently authenticated user
  /// @details Fetches the user session data from SharedPreferences and deserializes it.
  /// Used to restore user session across app launches and check authentication state.
  /// @return Future<UserModel?> The authenticated user object, or null if no user is logged in
  Future<UserModel?> getCurrentUser() async {
    final userJson = _prefs.getString(_userKey);
    if (userJson != null) {
      // Deserialize user from JSON stored in SharedPreferences
      return UserModel.fromJson(json.decode(userJson));
    }
    return null;
  }

  /// @brief Persists the current user session
  /// @details Saves the authenticated user to SharedPreferences in JSON format.
  /// Private method called internally by login() and register() to establish sessions.
  /// @param user The user object to persist as the current session
  /// @return Future<void> Completes when the user is saved to SharedPreferences
  Future<void> _saveCurrentUser(UserModel user) async {
    await _prefs.setString(_userKey, json.encode(user.toJson()));
  }

  /// @brief Retrieves all registered users in the system
  /// @details Returns the complete in-memory list of users.
  /// Used primarily by admin features for user management operations.
  /// @return List<UserModel> List of all registered users
  List<UserModel> getAllUsers() {
    return _users;
  }

  /// @brief Updates an existing user's information
  /// @details Searches for the user by ID and replaces their data with the updated version.
  /// If the user is found, persists the changes to storage.
  /// Silently fails if the user ID does not exist (no exception thrown).
  /// @param user The updated user object with the same ID as the existing user
  /// @return Future<void> Completes when the user is updated and saved
  Future<void> updateUser(UserModel user) async {
    // Find user index by ID
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      // Replace existing user with updated version
      _users[index] = user;
      await saveToStorage();
    }
  }

  /// @brief Deletes a user from the system
  /// @details Removes the user with the specified ID from the user list and persists changes.
  /// Used for admin operations to remove user accounts from the system.
  /// Silently succeeds even if the user ID does not exist.
  /// @param userId The unique identifier of the user to delete
  /// @return Future<void> Completes when the user is deleted and changes are saved
  Future<void> deleteUser(String userId) async {
    // Remove user by ID from the list
    _users.removeWhere((u) => u.id == userId);
    await saveToStorage();
  }
}
