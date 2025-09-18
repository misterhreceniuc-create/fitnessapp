// ==================== lib/shared/services/nutrition_service.dart ====================
import 'package:uuid/uuid.dart';
import '../models/nutrition_model.dart';

class NutritionService {
  final List<NutritionPlanModel> _mockNutritionPlans = [];
  final List<NutritionEntryModel> _mockNutritionEntries = [];

  Future<List<NutritionPlanModel>> getNutritionPlansForTrainee(String traineeId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockNutritionPlans.where((plan) => plan.traineeId == traineeId).toList();
  }

  Future<NutritionPlanModel> createNutritionPlan(NutritionPlanModel plan) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newPlan = NutritionPlanModel(
      id: const Uuid().v4(),
      traineeId: plan.traineeId,
      trainerId: plan.trainerId,
      name: plan.name,
      dailyCalories: plan.dailyCalories,
      macros: plan.macros,
      meals: plan.meals,
      createdAt: DateTime.now(),
    );
    _mockNutritionPlans.add(newPlan);
    return newPlan;
  }

  Future<NutritionEntryModel> logNutrition(NutritionEntryModel entry) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newEntry = NutritionEntryModel(
      id: const Uuid().v4(),
      traineeId: entry.traineeId,
      date: entry.date,
      consumedFoods: entry.consumedFoods,
      totalCalories: entry.totalCalories,
    );
    _mockNutritionEntries.add(newEntry);
    return newEntry;
  }

  Future<List<NutritionEntryModel>> getNutritionEntries(String traineeId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockNutritionEntries.where((entry) => 
      entry.traineeId == traineeId && 
      entry.date.year == date.year &&
      entry.date.month == date.month &&
      entry.date.day == date.day
    ).toList();
  }
}