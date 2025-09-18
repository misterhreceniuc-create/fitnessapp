// ==================== lib/shared/models/user_model.dart ====================
enum UserRole { admin, trainer, trainee }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? trainerId;
  final List<String>? traineeIds;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.trainerId,
    this.traineeIds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      createdAt: DateTime.parse(json['createdAt']),
      trainerId: json['trainerId'],
      traineeIds: json['traineeIds']?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'trainerId': trainerId,
      'traineeIds': traineeIds,
    };
  }
}