import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../shared/services/nutrition_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../routing/route_names.dart';
import '../widgets/workout_session_dialog.dart';

class TraineeDashboardPage extends StatefulWidget {
  const TraineeDashboardPage({super.key});

  @override
  State<TraineeDashboardPage> createState() => _TraineeDashboardPageState();
}

class _TraineeDashboardPageState extends State<TraineeDashboardPage> with SingleTickerProviderStateMixin {
  final TrainingService _trainingService = sl.get<TrainingService>();
  final NutritionService _nutritionService = sl.get<NutritionService>();
  
  late TabController _tabController;
  List<TrainingModel> _trainings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      print('=== TRAINEE DEBUG INFO ===');
      print('Current User ID: ${currentUser.id}');
      print('Current User Name: ${currentUser.name}');
      print('Current User Email: ${currentUser.email}');
      
      try {
        final trainings = await _trainingService.getTrainingsForTrainee(currentUser.id);
        print('Found ${trainings.length} trainings for this user');
        
        for (var training in trainings) {
          print('- Training: ${training.name} (ID: ${training.id})');
          print('  Assigned to trainee ID: ${training.traineeId}');
          print('  Scheduled: ${training.scheduledDate}');
        }

        setState(() {
          _trainings = trainings;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startWorkout(TrainingModel training) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkoutSessionDialog(
        training: training,
        onWorkoutUpdated: (updatedTraining) async {
          await _trainingService.updateTraining(updatedTraining);
          setState(() {
            final index = _trainings.indexWhere((t) => t.id == training.id);
            if (index != -1) {
              _trainings[index] = updatedTraining;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${currentUser?.name ?? 'User'}'),
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
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Workouts'),
            Tab(icon: Icon(Icons.restaurant), text: 'Nutrition'),
            Tab(icon: Icon(Icons.trending_up), text: 'Goals'),
            Tab(icon: Icon(Icons.analytics), text: 'Progress'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWorkoutsTab(),
                _buildNutritionTab(),
                _buildGoalsTab(),
                _buildProgressTab(),
              ],
            ),
    );
  }

  Widget _buildWorkoutsTab() {
    final currentUser = context.read<AuthProvider>().currentUser;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Information:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  Text('My User ID: ${currentUser?.id}'),
                  Text('My Name: ${currentUser?.name}'),
                  Text('My Email: ${currentUser?.email}'),
                  Text('Workouts found: ${_trainings.length}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            print('=== MANUAL DEBUG CHECK ===');
                            print('Current user ID: ${currentUser?.id}');
                            
                            final trainings = await _trainingService.getTrainingsForTrainee(currentUser!.id);
                            print('Trainings found: ${trainings.length}');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Debug: Found ${trainings.length} workouts for user ${currentUser.id}'),
                                  backgroundColor: trainings.length > 0 ? Colors.green : Colors.red,
                                ),
                              );
                            }
                            
                            setState(() {
                              _trainings = trainings;
                            });
                          },
                          child: const Text('🔄 Refresh & Debug'),
                        ),
                      ),
                    ],
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
                          'No workouts assigned yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Your trainer will assign workouts soon'),
                        SizedBox(height: 8),
                        Text('Use the Refresh button above to check for new workouts'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _trainings.length,
                    itemBuilder: (context, index) {
                      final training = _trainings[index];
                      return _buildWorkoutCard(training);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(TrainingModel training) {
    final hasStarted = training.exercises.any((e) => e.actualSets.isNotEmpty);
    final isCompleted = training.isCompleted;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted 
              ? Colors.green 
              : hasStarted 
                  ? Colors.orange 
                  : Colors.blue,
          child: Icon(
            isCompleted 
                ? Icons.check 
                : hasStarted 
                    ? Icons.play_arrow 
                    : Icons.fitness_center,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                training.name,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              )
            else if (hasStarted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'IN PROGRESS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(training.description),
            Text('Assigned to ID: ${training.traineeId}'),
            Text(
              'Scheduled: ${training.scheduledDate.toString().split(' ')[0]}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (hasStarted && !isCompleted) ...[
              const SizedBox(height: 4),
              Text(
                'Progress: ${_getWorkoutProgress(training)}',
                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getDifficultyColor(training.difficulty).withValues(alpha: 0.1),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Exercises (${training.exercises.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...training.exercises.map((exercise) {
                  final completedSets = exercise.actualSets.length;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  exercise.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (completedSets > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: completedSets >= exercise.sets ? Colors.green : Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$completedSets/${exercise.sets}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          Text('Target: ${exercise.sets} sets × ${exercise.reps} reps'),
                          if (exercise.weight != null)
                            Text('Weight: ${exercise.weight} kg'),
                          
                          // Show actual results if any
                          if (exercise.actualSets.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Your Results:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            ...exercise.actualSets.asMap().entries.map((entry) {
                              final setIndex = entry.key;
                              final actualSet = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, top: 2),
                                child: Text(
                                  'Set ${setIndex + 1}: ${actualSet.reps} reps × ${actualSet.kg} kg',
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              );
                            }).toList(),
                          ],
                          
                          if (exercise.instructions.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              exercise.instructions,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                
                // Action buttons based on workout state
                if (isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Workout Completed & Submitted!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startWorkout(training),
                          icon: Icon(hasStarted ? Icons.play_arrow : Icons.fitness_center),
                          label: Text(hasStarted ? 'Continue Workout' : 'Start Workout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasStarted ? Colors.orange : Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (training.notes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trainer Notes:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(training.notes!),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWorkoutProgress(TrainingModel training) {
    int totalSets = 0;
    int completedSets = 0;
    
    for (final exercise in training.exercises) {
      totalSets += exercise.sets;
      completedSets += exercise.actualSets.length;
    }
    
    return '$completedSets/$totalSets sets';
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

  Widget _buildNutritionTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today\'s Calories',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '1,250 / 2,000',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 1250 / 2000,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
            ),
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
                    'Nutrition Tracking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Track your meals and calories here'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildGoalCard(
            'Weight Loss',
            'Target: 70 kg',
            'Current: 75 kg',
            5 / 5,
            Colors.blue,
            Icons.monitor_weight,
          ),
          _buildGoalCard(
            'Bench Press',
            'Target: 80 kg',
            'Current: 65 kg',
            15 / 15,
            Colors.orange,
            Icons.fitness_center,
          ),
          _buildGoalCard(
            'Weekly Workouts',
            'Target: 4 workouts/week',
            'This week: 3 completed',
            3 / 4,
            Colors.green,
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(String title, String target, String current, double progress, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(target),
            Text(current, style: TextStyle(color: color)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).clamp(0, 100).toInt()}% Complete',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Workouts', '${_trainings.length}', 'Assigned', Icons.fitness_center, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Completed', '${_trainings.where((t) => t.isCompleted).length}', 'Done', Icons.check, Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Calories', '1,250', 'Today', Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Streak', '7 days', 'Active', Icons.whatshot, Colors.red)),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Progress Charts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Detailed charts would be displayed here'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
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
              leading: Icon(Icons.fitness_center, color: Colors.blue),
              title: Text('New workout assigned'),
              subtitle: Text('Check your workouts tab'),
            ),
            ListTile(
              leading: Icon(Icons.restaurant, color: Colors.orange),
              title: Text('Meal plan updated'),
              subtitle: Text('Check your nutrition goals'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                context.go(RouteNames.login);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}