// ==================== lib/shared/models/goal_model.dart ====================
enum GoalType { weight, measurement, performance }

class GoalModel {
  final String id;
  final String traineeId;
  final String trainerId;
  final String name;
  final GoalType type;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime deadline;
  final bool isCompleted;
  final DateTime createdAt;

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

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'],
      traineeId: json['traineeId'],
      trainerId: json['trainerId'],
      name: json['name'],
      type: GoalType.values.firstWhere((e) => e.name == json['type']),
      targetValue: json['targetValue'].toDouble(),
      currentValue: json['currentValue'].toDouble(),
      unit: json['unit'],
      deadline: DateTime.parse(json['deadline']),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      'trainerId': trainerId,
      'name': name,
      'type': type.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'deadline': deadline.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  double get progressPercentage {
    if (targetValue == 0) return 0;
    return (currentValue / targetValue * 100).clamp(0, 100);
  }
}