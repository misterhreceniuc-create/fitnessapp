// ==================== lib/shared/models/nutrition_model.dart ====================
class NutritionPlanModel {
  final String id;
  final String traineeId;
  final String trainerId;
  final String name;
  final int dailyCalories;
  final Map<String, int> macros;
  final List<MealModel> meals;
  final DateTime createdAt;

  NutritionPlanModel({
    required this.id,
    required this.traineeId,
    required this.trainerId,
    required this.name,
    required this.dailyCalories,
    required this.macros,
    required this.meals,
    required this.createdAt,
  });

  factory NutritionPlanModel.fromJson(Map<String, dynamic> json) {
    return NutritionPlanModel(
      id: json['id'],
      traineeId: json['traineeId'],
      trainerId: json['trainerId'],
      name: json['name'],
      dailyCalories: json['dailyCalories'],
      macros: Map<String, int>.from(json['macros']),
      meals: (json['meals'] as List)
          .map((e) => MealModel.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      'trainerId': trainerId,
      'name': name,
      'dailyCalories': dailyCalories,
      'macros': macros,
      'meals': meals.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class MealModel {
  final String id;
  final String name;
  final List<FoodItemModel> foods;
  final int calories;

  MealModel({
    required this.id,
    required this.name,
    required this.foods,
    required this.calories,
  });

  factory MealModel.fromJson(Map<String, dynamic> json) {
    return MealModel(
      id: json['id'],
      name: json['name'],
      foods: (json['foods'] as List)
          .map((e) => FoodItemModel.fromJson(e))
          .toList(),
      calories: json['calories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'foods': foods.map((e) => e.toJson()).toList(),
      'calories': calories,
    };
  }
}

class FoodItemModel {
  final String name;
  final double quantity;
  final String unit;
  final int calories;

  FoodItemModel({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    return FoodItemModel(
      name: json['name'],
      quantity: json['quantity'].toDouble(),
      unit: json['unit'],
      calories: json['calories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
    };
  }
}

class NutritionEntryModel {
  final String id;
  final String traineeId;
  final DateTime date;
  final List<FoodItemModel> consumedFoods;
  final int totalCalories;

  NutritionEntryModel({
    required this.id,
    required this.traineeId,
    required this.date,
    required this.consumedFoods,
    required this.totalCalories,
  });

  factory NutritionEntryModel.fromJson(Map<String, dynamic> json) {
    return NutritionEntryModel(
      id: json['id'],
      traineeId: json['traineeId'],
      date: DateTime.parse(json['date']),
      consumedFoods: (json['consumedFoods'] as List)
          .map((e) => FoodItemModel.fromJson(e))
          .toList(),
      totalCalories: json['totalCalories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      'date': date.toIso8601String(),
      'consumedFoods': consumedFoods.map((e) => e.toJson()).toList(),
      'totalCalories': totalCalories,
    };
  }
}