import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/services/user_service.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../routing/route_names.dart';
import '../widgets/workout_creation_wizard.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> with SingleTickerProviderStateMixin {
  final UserService _userService = sl.get<UserService>();
  final TrainingService _trainingService = sl.get<TrainingService>();
  
  late TabController _tabController;
  List<UserModel> _trainees = [];
  List<TrainingModel> _trainings = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      try {
        final trainees = await _userService.getTrainees(currentUser.id);
        final trainings = await _trainingService.getTrainingsForTrainer(currentUser.id);
        
        print('=== TRAINER DEBUG INFO ===');
        print('Trainer ID: ${currentUser.id}');
        print('Found ${trainees.length} trainees');
        for (var trainee in trainees) {
          print('- Trainee: ${trainee.name} (ID: ${trainee.id})');
        }
        print('Found ${trainings.length} trainings created by this trainer');
        
        setState(() {
          _trainees = trainees;
          _trainings = trainings;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading trainer data: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Trainer Dashboard - ${currentUser?.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Trainees'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
            Tab(icon: Icon(Icons.restaurant), text: 'Nutrition'),
                      ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTraineesTab(),
                _buildWorkoutsTab(),
                _buildNutritionTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewWorkout,
        icon: const Icon(Icons.add),
        label: const Text('New Workout'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTraineesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addTrainee,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Trainee'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Found ${_trainees.length} trainees assigned to you',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _trainees.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No trainees yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Trainees will appear here when assigned to you'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _trainees.length,
                    itemBuilder: (context, index) {
                      final trainee = _trainees[index];
                      final assignedWorkouts = _trainings.where((t) => t.traineeId == trainee.id).length;
                      final completedWorkouts = _trainings.where((t) => t.traineeId == trainee.id && t.isCompleted).length;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(
                              trainee.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(trainee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trainee.email),
                              Text('ID: ${trainee.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Workouts: $assignedWorkouts assigned, $completedWorkouts completed'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _createWorkoutForTrainee(trainee),
                                icon: const Icon(Icons.add, color: Colors.blue),
                                tooltip: 'Create Workout',
                              ),
                              IconButton(
                                onPressed: () => _viewProgress(trainee.name),
                                icon: const Icon(Icons.analytics, color: Colors.orange),
                                tooltip: 'View Progress',
                              ),
                            ],
                          ),
                          onTap: () => _viewTraineeDetails(trainee),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createWorkoutTemplate,
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scheduleWorkout,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Schedule'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createTestWorkout,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Created ${_trainings.length} workouts total',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _trainings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No workouts created yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Create your first workout using the + button or Test button'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _trainings.length,
                    itemBuilder: (context, index) {
                      final training = _trainings[index];
                      final trainee = _getTraineeById(training.traineeId);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: training.isCompleted ? Colors.green : Colors.orange,
                            child: Icon(
                              training.isCompleted ? Icons.check : Icons.fitness_center,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            training.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assigned to: ${trainee?.name ?? 'Unknown'} (${training.traineeId})'),
                              Text('${training.exercises.length} exercises • ${training.estimatedDuration} min'),
                              Text(
                                'Scheduled: ${training.scheduledDate.toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(training.difficulty).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  training.difficulty.toUpperCase(),
                                  style: TextStyle(
                                    color: _getDifficultyColor(training.difficulty),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (training.isCompleted)
                                const Icon(Icons.check_circle, color: Colors.green)
                              else
                                const Icon(Icons.pending, color: Colors.orange),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility),
                                        SizedBox(width: 8),
                                        Text('View Details'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy),
                                        SizedBox(width: 8),
                                        Text('Duplicate'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  switch (value) {
                                    case 'view':
                                      _viewWorkoutDetails(training);
                                      break;
                                    case 'duplicate':
                                      _duplicateWorkout(training);
                                      break;
                                    case 'delete':
                                      _deleteWorkout(training);
                                      break;
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () => _viewWorkoutDetails(training),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createMealPlan,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Create Meal Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nutritionLibrary,
                  icon: const Icon(Icons.library_books),
                  label: const Text('Library'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nutrition Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Create and manage nutrition plans for your trainees'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  UserModel? _getTraineeById(String traineeId) {
    try {
      return _trainees.firstWhere((trainee) => trainee.id == traineeId);
    } catch (e) {
      return null;
    }
  }

  String _getTraineeName(String traineeId) {
    final trainee = _getTraineeById(traineeId);
    return trainee?.name ?? 'Unknown';
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Action methods
  void _createNewWorkout() {
    if (_trainees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trainees available. The system has mock trainees, but they may not be loaded.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => WorkoutCreationWizard(
        trainees: _trainees,
        onWorkoutCreated: (workout) async {
          final currentUser = context.read<AuthProvider>().currentUser;
          if (currentUser != null) {
            try {
              final newWorkout = workout.copyWith(trainerId: currentUser.id);
              final createdWorkout = await _trainingService.createTraining(newWorkout);
              
              setState(() {
                _trainings.add(createdWorkout);
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Workout "${workout.name}" assigned to ${_getTraineeName(workout.traineeId)}!',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () => _viewWorkoutDetails(createdWorkout),
                  ),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error creating workout: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  // TEST WORKOUT METHOD - This creates a workout directly for Mike Johnson
  void _createTestWorkout() {
    final testWorkout = TrainingModel(
      id: const Uuid().v4(),
      name: 'Test Workout for Mike',
      description: 'This is a test workout to verify the system works',
      traineeId: 'trainee3', // Mike Johnson's ID from auth_service
      trainerId: '2', // Trainer's ID from auth_service
      exercises: [
        ExerciseModel(
          id: const Uuid().v4(),
          name: 'Push-ups',
          sets: 3,
          reps: 10,
          category: 'strength',
          targetMuscle: 'chest',
          equipment: 'bodyweight',
          instructions: 'Start in plank position, lower body until chest nearly touches floor, push back up.',
          restTimeSeconds: 60,
        ),
        ExerciseModel(
          id: const Uuid().v4(),
          name: 'Squats',
          sets: 3,
          reps: 15,
          category: 'strength',
          targetMuscle: 'legs',
          equipment: 'bodyweight',
          instructions: 'Stand with feet shoulder-width apart, sit back and down, keep chest up.',
          restTimeSeconds: 60,
        ),
        ExerciseModel(
          id: const Uuid().v4(),
          name: 'Plank',
          sets: 3,
          reps: 1, // 1 rep = hold for time
          category: 'strength',
          targetMuscle: 'core',
          equipment: 'bodyweight',
          instructions: 'Hold push-up position, keep body straight from head to heels. Hold for 30-60 seconds.',
          restTimeSeconds: 60,
        ),
      ],
      scheduledDate: DateTime.now(),
      difficulty: 'beginner',
      estimatedDuration: 30,
      category: 'strength',
      notes: 'This is a test workout created by the trainer to verify that workouts appear correctly for trainees.',
    );

    _trainingService.createTraining(testWorkout).then((createdWorkout) {
      setState(() {
        _trainings.add(createdWorkout);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test workout created for Mike Johnson! Now login as Mike to see it.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      
      print('=== TEST WORKOUT CREATED ===');
      print('Workout: ${createdWorkout.name}');
      print('Assigned to: ${createdWorkout.traineeId}');
      print('Trainer: ${createdWorkout.trainerId}');
      print('Exercises: ${createdWorkout.exercises.length}');
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating test workout: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _addTrainee() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add trainee feature - coming soon!')),
    );
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
    });
    _loadData();
  }

  void _createWorkoutTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create template feature - coming soon!')),
    );
  }

  void _scheduleWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule workout feature - coming soon!')),
    );
  }

  void _createMealPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create meal plan feature - coming soon!')),
    );
  }

  void _nutritionLibrary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nutrition library feature - coming soon!')),
    );
  }

  void _viewProgress(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$name Progress'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📊 Progress charts and statistics would be shown here.'),
            SizedBox(height: 16),
            Text('• Workout completion rate'),
            Text('• Strength progression'),
            Text('• Weight changes'),
            Text('• Goal achievements'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _viewTraineeDetails(UserModel trainee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trainee.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email: ${trainee.email}'),
            Text('🆔 ID: ${trainee.id}'),
            Text('👤 Role: ${trainee.role.name.toUpperCase()}'),
            Text('📅 Member since: ${trainee.createdAt.toString().split(' ')[0]}'),
            const SizedBox(height: 16),
            const Text('Workout Statistics:'),
            Text('• Assigned workouts: ${_trainings.where((t) => t.traineeId == trainee.id).length}'),
            Text('• Completed: ${_trainings.where((t) => t.traineeId == trainee.id && t.isCompleted).length}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createWorkoutForTrainee(trainee);
            },
            child: const Text('Create Workout'),
          ),
        ],
      ),
    );
  }

  void _createWorkoutForTrainee(UserModel trainee) {
    showDialog(
      context: context,
      builder: (context) => WorkoutCreationWizard(
        trainees: [trainee], // Pre-select this trainee
        onWorkoutCreated: (workout) async {
          final currentUser = context.read<AuthProvider>().currentUser;
          if (currentUser != null) {
            try {
              final newWorkout = workout.copyWith(trainerId: currentUser.id);
              final createdWorkout = await _trainingService.createTraining(newWorkout);
              
              setState(() {
                _trainings.add(createdWorkout);
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Workout "${workout.name}" created for ${trainee.name}!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _viewWorkoutDetails(TrainingModel training) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(training.name),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${training.description}'),
              Text('Assigned to: ${_getTraineeName(training.traineeId)} (${training.traineeId})'),
              Text('Difficulty: ${training.difficulty.toUpperCase()}'),
              Text('Duration: ${training.estimatedDuration} minutes'),
              Text('Scheduled: ${training.scheduledDate.toString().split(' ')[0]}'),
              Text('Status: ${training.isCompleted ? "✅ Completed" : "⏳ Pending"}'),
              if (training.completedAt != null)
                Text('Completed: ${training.completedAt.toString().split(' ')[0]}'),
              const SizedBox(height: 16),
              const Text('Exercises:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...training.exercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${exercise.name} - ${exercise.sets}×${exercise.reps}${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}'),
              )),
              if (training.notes != null) ...[
                const SizedBox(height: 12),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(training.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _duplicateWorkout(TrainingModel training) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicating "${training.name}" - feature coming soon!')),
    );
  }

  void _deleteWorkout(TrainingModel training) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "${training.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _trainings.removeWhere((t) => t.id == training.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Workout "${training.name}" deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('John completed "Upper Body Strength"'),
              subtitle: Text('2 hours ago'),
            ),
            ListTile(
              leading: Icon(Icons.message, color: Colors.blue),
              title: Text('New message from Jane'),
              subtitle: Text('Asked about rest days'),
            ),
            ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text('Mike missed yesterday\'s workout'),
              subtitle: Text('Consider following up'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
              context.go(RouteNames.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}