import '../models/training_model.dart';

class ExerciseLibraryService {
  static final List<ExerciseTemplate> _exercises = [
    // Chest Exercises
    ExerciseTemplate(
      id: '1',
      name: 'Push-ups',
      category: 'strength',
      targetMuscle: 'chest',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Start in plank position, lower body until chest nearly touches floor, push back up.',
      tips: ['Keep core tight', 'Full range of motion', 'Control the movement'],
    ),
    ExerciseTemplate(
      id: '2',
      name: 'Bench Press',
      category: 'strength',
      targetMuscle: 'chest',
      equipment: 'barbell',
      difficultyLevel: 'intermediate',
      instructions: 'Lie on bench, grip bar slightly wider than shoulders, lower to chest, press up.',
      tips: ['Keep feet on ground', 'Squeeze shoulder blades', 'Control the descent'],
    ),
    ExerciseTemplate(
      id: '3',
      name: 'Dumbbell Flyes',
      category: 'strength',
      targetMuscle: 'chest',
      equipment: 'dumbbell',
      difficultyLevel: 'intermediate',
      instructions: 'Lie on bench, arms slightly bent, lower dumbbells in arc motion, squeeze chest.',
      tips: ['Slight bend in elbows', 'Feel the stretch', 'Squeeze at the top'],
    ),

    // Leg Exercises
    ExerciseTemplate(
      id: '4',
      name: 'Squats',
      category: 'strength',
      targetMuscle: 'legs',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Stand with feet shoulder-width apart, sit back and down, keep chest up.',
      tips: ['Keep knees behind toes', 'Weight in heels', 'Full depth if possible'],
    ),
    ExerciseTemplate(
      id: '5',
      name: 'Lunges',
      category: 'strength',
      targetMuscle: 'legs',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Step forward, lower hips until both knees at 90 degrees, push back up.',
      tips: ['Keep torso upright', 'Step far enough forward', 'Control the movement'],
    ),
    ExerciseTemplate(
      id: '6',
      name: 'Deadlifts',
      category: 'strength',
      targetMuscle: 'legs',
      equipment: 'barbell',
      difficultyLevel: 'advanced',
      instructions: 'Stand with bar over mid-foot, bend at hips and knees, grip bar, stand up straight.',
      tips: ['Keep back straight', 'Bar close to body', 'Drive through heels'],
    ),

    // Back Exercises
    ExerciseTemplate(
      id: '7',
      name: 'Pull-ups',
      category: 'strength',
      targetMuscle: 'back',
      equipment: 'pullup_bar',
      difficultyLevel: 'intermediate',
      instructions: 'Hang from bar, pull body up until chin over bar, lower with control.',
      tips: ['Full range of motion', 'Don\'t swing', 'Squeeze shoulder blades'],
    ),
    ExerciseTemplate(
      id: '8',
      name: 'Bent-over Rows',
      category: 'strength',
      targetMuscle: 'back',
      equipment: 'barbell',
      difficultyLevel: 'intermediate',
      instructions: 'Bend forward at hips, pull bar to lower chest, squeeze shoulder blades.',
      tips: ['Keep back straight', 'Pull to sternum', 'Control the weight'],
    ),

    // Core Exercises
    ExerciseTemplate(
      id: '9',
      name: 'Plank',
      category: 'strength',
      targetMuscle: 'core',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Hold push-up position, keep body straight from head to heels.',
      tips: ['Don\'t let hips sag', 'Breathe normally', 'Engage core'],
    ),
    ExerciseTemplate(
      id: '10',
      name: 'Crunches',
      category: 'strength',
      targetMuscle: 'core',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Lie on back, knees bent, lift shoulder blades off ground.',
      tips: ['Don\'t pull on neck', 'Focus on abs', 'Controlled movement'],
    ),

    // Cardio Exercises
    ExerciseTemplate(
      id: '11',
      name: 'Jumping Jacks',
      category: 'cardio',
      targetMuscle: 'full_body',
      equipment: 'bodyweight',
      difficultyLevel: 'beginner',
      instructions: 'Jump feet apart while raising arms overhead, jump back to starting position.',
      tips: ['Land softly', 'Keep rhythm', 'Stay light on feet'],
    ),
    ExerciseTemplate(
      id: '12',
      name: 'Burpees',
      category: 'cardio',
      targetMuscle: 'full_body',
      equipment: 'bodyweight',
      difficultyLevel: 'advanced',
      instructions: 'Squat down, jump back to plank, do push-up, jump feet forward, jump up.',
      tips: ['Maintain form when tired', 'Breathe consistently', 'Modify if needed'],
    ),
    ExerciseTemplate(
      id: '13',
      name: 'Mountain Climbers',
      category: 'cardio',
      targetMuscle: 'full_body',
      equipment: 'bodyweight',
      difficultyLevel: 'intermediate',
      instructions: 'Start in plank, alternate bringing knees to chest rapidly.',
      tips: ['Keep hips level', 'Fast but controlled', 'Engage core'],
    ),
  ];

  List<ExerciseTemplate> getAllExercises() {
    return List.from(_exercises);
  }

  List<ExerciseTemplate> getExercisesByCategory(String category) {
    return _exercises.where((exercise) => exercise.category == category).toList();
  }

  List<ExerciseTemplate> getExercisesByMuscle(String muscle) {
    return _exercises.where((exercise) => exercise.targetMuscle == muscle).toList();
  }

  List<ExerciseTemplate> getExercisesByEquipment(String equipment) {
    return _exercises.where((exercise) => exercise.equipment == equipment).toList();
  }

  List<ExerciseTemplate> getExercisesByDifficulty(String difficulty) {
    return _exercises.where((exercise) => exercise.difficultyLevel == difficulty).toList();
  }

  ExerciseTemplate? getExerciseById(String id) {
    try {
      return _exercises.firstWhere((exercise) => exercise.id == id);
    } catch (e) {
      return null;
    }
  }

  List<String> getAvailableCategories() {
    return _exercises.map((e) => e.category).toSet().toList();
  }

  List<String> getAvailableMuscles() {
    return _exercises.map((e) => e.targetMuscle).toSet().toList();
  }

  List<String> getAvailableEquipment() {
    return _exercises.map((e) => e.equipment).toSet().toList();
  }

  List<ExerciseTemplate> searchExercises(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises.where((exercise) =>
        exercise.name.toLowerCase().contains(lowerQuery) ||
        exercise.targetMuscle.toLowerCase().contains(lowerQuery) ||
        exercise.category.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}