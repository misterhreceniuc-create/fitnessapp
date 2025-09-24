import '../models/training_template_model.dart';
import '../models/training_model.dart';
import 'package:uuid/uuid.dart';

class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  final List<WorkoutTemplate> _templates = [];

  // Initialize with some mock templates for testing
  void _initializeMockTemplates() {
    if (_templates.isEmpty) {
      _templates.addAll([
        WorkoutTemplate(
          id: const Uuid().v4(),
          name: 'Upper Body Strength',
          description: 'A comprehensive upper body workout focusing on chest, shoulders, and arms',
          difficulty: 'intermediate',
          estimatedDuration: 45,
          category: 'strength',
          exercises: [
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'Push-ups',
              category: 'strength',
              targetMuscle: 'chest',
              equipment: 'bodyweight',
              instructions: 'Start in plank position, lower body until chest nearly touches floor, push back up.',
              difficultyLevel: 'beginner',
              tips: ['Keep core tight', 'Maintain straight line from head to heels'],
            ),
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'Shoulder Press',
              category: 'strength',
              targetMuscle: 'shoulders',
              equipment: 'dumbbells',
              instructions: 'Press weights overhead, lower with control.',
              difficultyLevel: 'intermediate',
              tips: ['Keep core engaged', 'Press straight up'],
            ),
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'Bicep Curls',
              category: 'strength',
              targetMuscle: 'biceps',
              equipment: 'dumbbells',
              instructions: 'Curl weights up keeping elbows at sides.',
              difficultyLevel: 'beginner',
              tips: ['Control the descent', 'Keep elbows stationary'],
            ),
          ],
          createdBy: '2', // Trainer ID
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          isPublic: false,
          tags: ['strength', 'upper-body', 'muscle-building'],
          notes: 'Perfect for building upper body strength and muscle mass',
        ),
        WorkoutTemplate(
          id: const Uuid().v4(),
          name: 'HIIT Cardio Blast',
          description: 'High-intensity interval training for cardiovascular fitness',
          difficulty: 'advanced',
          estimatedDuration: 30,
          category: 'cardio',
          exercises: [
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'Jumping Jacks',
              category: 'cardio',
              targetMuscle: 'full-body',
              equipment: 'bodyweight',
              instructions: 'Jump feet wide while raising arms overhead, return to start.',
              difficultyLevel: 'beginner',
              tips: ['Land softly', 'Keep consistent rhythm'],
            ),
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'Burpees',
              category: 'cardio',
              targetMuscle: 'full-body',
              equipment: 'bodyweight',
              instructions: 'Squat down, jump back to plank, push-up, jump feet forward, jump up.',
              difficultyLevel: 'advanced',
              tips: ['Maintain form even when tired', 'Breathe consistently'],
            ),
            ExerciseTemplate(
              id: const Uuid().v4(),
              name: 'High Knees',
              category: 'cardio',
              targetMuscle: 'legs',
              equipment: 'bodyweight',
              instructions: 'Run in place bringing knees up high.',
              difficultyLevel: 'intermediate',
              tips: ['Keep core engaged', 'Pump arms actively'],
            ),
          ],
          createdBy: '2', // Trainer ID
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          isPublic: true,
          tags: ['cardio', 'hiit', 'fat-burn'],
          notes: 'High-intensity intervals for maximum calorie burn',
        ),
      ]);
    }
  }

  Future<List<WorkoutTemplate>> getTemplatesForTrainer(String trainerId) async {
    _initializeMockTemplates();
    // Filter templates created by this trainer
    return _templates.where((template) => template.createdBy == trainerId).toList();
  }

  Future<List<WorkoutTemplate>> getPublicTemplates() async {
    _initializeMockTemplates();
    // Get all public templates
    return _templates.where((template) => template.isPublic).toList();
  }

  Future<WorkoutTemplate> createTemplate(WorkoutTemplate template) async {
    _templates.add(template);
    return template;
  }

  Future<WorkoutTemplate> updateTemplate(WorkoutTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template;
      return template;
    }
    throw Exception('Template not found');
  }

  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((template) => template.id == templateId);
  }

  Future<WorkoutTemplate?> getTemplateById(String templateId) async {
    try {
      return _templates.firstWhere((template) => template.id == templateId);
    } catch (e) {
      return null;
    }
  }

  Future<List<WorkoutTemplate>> searchTemplates({
    String? query,
    String? category,
    String? difficulty,
    List<String>? tags,
  }) async {
    var results = _templates.where((template) => template.isPublic).toList();

    if (query != null && query.isNotEmpty) {
      results = results.where((template) =>
          template.name.toLowerCase().contains(query.toLowerCase()) ||
          template.description.toLowerCase().contains(query.toLowerCase())).toList();
    }

    if (category != null && category.isNotEmpty) {
      results = results.where((template) => template.category == category).toList();
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      results = results.where((template) => template.difficulty == difficulty).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((template) =>
          tags.any((tag) => template.tags.contains(tag))).toList();
    }

    return results;
  }
}