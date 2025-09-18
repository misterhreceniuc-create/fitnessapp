import '../models/user_model.dart';
import 'auth_service.dart';
import '../../core/dependency_injection/injection_container.dart';

class UserService {
  final AuthService _authService = sl.get<AuthService>();

  Future<List<UserModel>> getAllUsers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _authService.getAllUsers();
  }

  Future<List<UserModel>> getTrainees(String trainerId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // For demo purposes, return some mock trainees
    final mockTrainees = [
      UserModel(
        id: 'trainee1',
        name: 'John Doe',
        email: 'john.doe@email.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        trainerId: trainerId,
      ),
      UserModel(
        id: 'trainee2',
        name: 'Jane Smith',
        email: 'jane.smith@email.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        trainerId: trainerId,
      ),
      UserModel(
        id: 'trainee3',
        name: 'Mike Johnson',
        email: 'mike.johnson@email.com',
        role: UserRole.trainee,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        trainerId: trainerId,
      ),
    ];
    
    return mockTrainees;
  }

  Future<List<UserModel>> getTrainers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _authService.getAllUsers()
        .where((user) => user.role == UserRole.trainer)
        .toList();
  }

  Future<UserModel?> getUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      return _authService.getAllUsers().firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }
}