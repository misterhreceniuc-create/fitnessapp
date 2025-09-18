import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../../core/dependency_injection/injection_container.dart';

class AuthService {
  final SharedPreferences _prefs = sl.get<SharedPreferences>();
  static const String _userKey = 'current_user';
  static const String _usersKey = 'all_users';
  
  // Mock users for demonstration - ADD MIKE JOHNSON HERE
  final List<UserModel> _mockUsers = [
    UserModel(
      id: '1',
      name: 'Admin User',
      email: 'admin@fitness.com',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '2',
      name: 'John Trainer',
      email: 'trainer@fitness.com',
      role: UserRole.trainer,
      createdAt: DateTime.now(),
      traineeIds: ['3', 'trainee1', 'trainee2', 'trainee3'],
    ),
    UserModel(
      id: '3',
      name: 'Jane Trainee',
      email: 'trainee@fitness.com',
      role: UserRole.trainee,
      createdAt: DateTime.now(),
      trainerId: '2',
    ),
    // ADD THESE NEW TRAINEE USERS
    UserModel(
      id: 'trainee1',
      name: 'John Doe',
      email: 'john.doe@fitness.com',
      role: UserRole.trainee,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      trainerId: '2',
    ),
    UserModel(
      id: 'trainee2',
      name: 'Jane Smith',
      email: 'jane.smith@fitness.com',
      role: UserRole.trainee,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      trainerId: '2',
    ),
    UserModel(
      id: 'trainee3',
      name: 'Mike Johnson',
      email: 'mike.johnson@fitness.com',
      role: UserRole.trainee,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      trainerId: '2',
    ),
  ];

  // ... rest of the existing methods stay the same ...
  
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    final user = _mockUsers.firstWhere(
      (user) => user.email == email,
      orElse: () => throw Exception('Invalid email or password'),
    );
    
    await _saveCurrentUser(user);
    return user;
  }

  Future<UserModel> register(String name, String email, String password, UserRole role) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    // Check if user already exists
    final existingUser = _mockUsers.where((user) => user.email == email);
    if (existingUser.isNotEmpty) {
      throw Exception('User with this email already exists');
    }
    
    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
    
    _mockUsers.add(newUser);
    await _saveCurrentUser(newUser);
    return newUser;
  }

  Future<void> logout() async {
    await _prefs.remove(_userKey);
  }

  Future<UserModel?> getCurrentUser() async {
    final userJson = _prefs.getString(_userKey);
    if (userJson != null) {
      return UserModel.fromJson(json.decode(userJson));
    }
    return null;
  }

  Future<void> _saveCurrentUser(UserModel user) async {
    await _prefs.setString(_userKey, json.encode(user.toJson()));
  }

  List<UserModel> getAllUsers() {
    return _mockUsers;
  }
}