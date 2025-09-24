import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../shared/services/user_service.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../shared/services/template_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../routing/route_names.dart';
import '../widgets/workout_creation_wizard.dart';
import '../widgets/workout_creation_mode_dialog.dart';
import '../widgets/recurrence_edit_dialog.dart';
import '../widgets/recurrence_deletion_dialog.dart';


class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> with SingleTickerProviderStateMixin {
  final UserService _userService = sl.get<UserService>();
  final TrainingService _trainingService = sl.get<TrainingService>();
  final TemplateService _templateService = sl.get<TemplateService>();

  late TabController _tabController;
  List<UserModel> _trainees = [];
  List<TrainingModel> _trainings = [];
  bool _isLoading = true;

  // ...existing code...

  void _editWorkout(TrainingModel training) async {
    // Check if this is a recurring workout
    if (training.isRecurring) {
      // Show recurrence edit dialog to choose scope
      await showDialog(
        context: context,
        builder: (context) => RecurrenceEditDialog(
          training: training,
          onScopeSelected: (scope) {
            Navigator.pop(context);
            _showEditWorkoutDialog(training, scope);
          },
        ),
      );
    } else {
      // Single workout, edit directly
      _showEditWorkoutDialog(training, EditScope.single);
    }
  }

  void _showEditWorkoutDialog(TrainingModel training, EditScope editScope) async {
    await showDialog(
      context: context,
      builder: (context) => WorkoutCreationWizard(
        trainees: _trainees,
        initialWorkout: training,
        onWorkoutCreated: (editedWorkout) async {
          if (editScope == EditScope.single) {
            // Update single workout
            final updated = training.copyWith(
              name: editedWorkout.name,
              description: editedWorkout.description,
              exercises: editedWorkout.exercises,
              scheduledDate: editedWorkout.scheduledDate,
              difficulty: editedWorkout.difficulty,
              estimatedDuration: editedWorkout.estimatedDuration,
              category: editedWorkout.category,
              notes: editedWorkout.notes,
              traineeId: editedWorkout.traineeId,
            );
            await _trainingService.updateTraining(updated);
            setState(() {
              final idx = _trainings.indexWhere((t) => t.id == training.id);
              if (idx != -1) _trainings[idx] = updated;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Workout "${updated.name}" updated')),
              );
            }
          } else {
            // Update all workouts in recurrence group
            final templateTraining = training.copyWith(
              name: editedWorkout.name,
              description: editedWorkout.description,
              exercises: editedWorkout.exercises,
              difficulty: editedWorkout.difficulty,
              estimatedDuration: editedWorkout.estimatedDuration,
              category: editedWorkout.category,
              notes: editedWorkout.notes,
            );

            final updatedTrainings = await _trainingService.updateRecurrenceGroup(
              training.recurrenceGroupId!,
              templateTraining,
            );

            setState(() {
              for (final updatedTraining in updatedTrainings) {
                final idx = _trainings.indexWhere((t) => t.id == updatedTraining.id);
                if (idx != -1) _trainings[idx] = updatedTraining;
              }
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Updated ${updatedTrainings.length} workouts in the series'),
                ),
              );
            }
          }
        },
      ),
    );
  }


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
            icon: const Icon(Icons.library_books),
            onPressed: _openTemplates,
            tooltip: 'Templates',
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  training.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (training.isRecurring)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat, size: 12, color: Colors.purple.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        training.recurrenceDisplayText,
                                        style: TextStyle(
                                          color: Colors.purple.shade600,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
                                  PopupMenuItem(
                                    value: 'edit',
                                    enabled: !training.isCompleted,
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: training.isCompleted ? Colors.grey : null),
                                        SizedBox(width: 8),
                                        Text('Edit', style: TextStyle(color: training.isCompleted ? Colors.grey : null)),
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
                                    case 'edit':
                                      _editWorkout(training);
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
    print('=== NEW WORKOUT BUTTON CLICKED ===');
    print('Trainees count: ${_trainees.length}');

    if (_trainees.isEmpty) {
      print('❌ No trainees available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trainees available. The system has mock trainees, but they may not be loaded.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('✅ Opening WorkoutCreationModeDialog');
    try {
      showDialog(
        context: context,
        builder: (context) => WorkoutCreationModeDialog(
          onModeSelected: (mode, {selectedTemplate}) {
            print('=== MODE SELECTED ===');
            print('Mode: $mode');
            print('Selected Template: ${selectedTemplate?.name ?? 'None'}');
            _handleWorkoutCreation(mode, selectedTemplate: selectedTemplate);
          },
        ),
      );
    } catch (e) {
      print('❌ Error opening dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleWorkoutCreation(WorkoutCreationMode mode, {WorkoutTemplate? selectedTemplate}) {
    print('=== HANDLE WORKOUT CREATION ===');
    print('Mode: $mode');
    print('Template: ${selectedTemplate?.name ?? 'None'}');

    // Use Future.delayed to ensure the previous dialog is properly closed
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mode == WorkoutCreationMode.fromScratch) {
        print('Creating workout from scratch');
        _showTraineeSelectionForNewWorkout();
      } else if (mode == WorkoutCreationMode.fromTemplate && selectedTemplate != null) {
        print('Creating workout from template: ${selectedTemplate.name}');
        _showTraineeSelectionForTemplate(selectedTemplate);
      } else {
        print('❌ Invalid mode or missing template');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid workout creation mode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _showTraineeSelectionForNewWorkout() {
    print('📋 Showing trainee selection dialog for new workout');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Workout'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a trainee to create a workout for:'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _trainees.length,
                  itemBuilder: (context, index) {
                    final trainee = _trainees[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(trainee.name[0]),
                        ),
                        title: Text(trainee.name),
                        subtitle: Text('ID: ${trainee.id}'),
                        onTap: () {
                          print('🎯 Trainee selected: ${trainee.name} (${trainee.id})');
                          Navigator.pop(context);
                          _createBasicWorkoutForTrainee(trainee);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showTraineeSelectionForTemplate(WorkoutTemplate template) {
    print('📋 Showing trainee selection dialog for template: ${template.name}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use Template: ${template.name}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a trainee to create this workout for:'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _trainees.length,
                  itemBuilder: (context, index) {
                    final trainee = _trainees[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(trainee.name[0]),
                        ),
                        title: Text(trainee.name),
                        subtitle: Text('ID: ${trainee.id}'),
                        onTap: () {
                          print('🎯 Trainee selected for template: ${trainee.name} (${trainee.id})');
                          Navigator.pop(context);
                          _createWorkoutFromTemplateForTrainee(template, trainee);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createBasicWorkoutForTrainee(UserModel trainee) {
    print('🎨 Opening WorkoutCreationWizard for: ${trainee.name}');

    // Use the old WorkoutCreationWizard mechanism for "Create from scratch"
    showDialog(
      context: context,
      builder: (context) {
        print('🎨 Building WorkoutCreationWizard dialog');
        return WorkoutCreationWizard(
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

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Custom workout "${workout.name}" created for ${trainee.name}!'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }

                print('✅ Custom workout created successfully: ${createdWorkout.id}');
              } catch (e) {
                print('❌ Error creating custom workout: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating workout: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        );
      },
    );
  }

  Future<void> _createWorkoutFromTemplateForTrainee(WorkoutTemplate template, UserModel trainee) async {
    print('Creating workout from template: ${template.name} for ${trainee.name}');

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    try {
      // Convert template to workout
      final workout = template.toTrainingModel(
        traineeId: trainee.id,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      ).copyWith(trainerId: currentUser.id); // Ensure the current trainer is assigned

      final createdWorkout = await _trainingService.createTraining(workout);

      setState(() {
        _trainings.add(createdWorkout);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Workout "${template.name}" created for ${trainee.name}!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      print('✅ Workout created successfully: ${createdWorkout.id}');

    } catch (e) {
      print('❌ Error creating workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test workout created for Mike Johnson! Now login as Mike to see it.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
      
      print('=== TEST WORKOUT CREATED ===');
      print('Workout: ${createdWorkout.name}');
      print('Assigned to: ${createdWorkout.traineeId}');
      print('Trainer: ${createdWorkout.trainerId}');
      print('Exercises: ${createdWorkout.exercises.length}');
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating test workout: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      builder: (context) => WorkoutCreationModeDialog(
        onModeSelected: (mode, {selectedTemplate}) {
          _handleWorkoutCreation(mode, selectedTemplate: selectedTemplate);
        },
      ),
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
    print('=== CREATE WORKOUT FOR TRAINEE BUTTON CLICKED ===');
    print('Trainee: ${trainee.name} (${trainee.id})');

    // Show workout creation mode dialog, but skip trainee selection
    showDialog(
      context: context,
      builder: (context) => WorkoutCreationModeDialog(
        onModeSelected: (mode, {selectedTemplate}) {
          print('=== MODE SELECTED FOR TRAINEE ===');
          print('Mode: $mode');
          print('Template: ${selectedTemplate?.name ?? 'None'}');
          print('Pre-selected trainee: ${trainee.name}');
          _handleWorkoutCreationForTrainee(trainee, mode, selectedTemplate: selectedTemplate);
        },
      ),
    );
  }

  void _handleWorkoutCreationForTrainee(UserModel trainee, WorkoutCreationMode mode, {WorkoutTemplate? selectedTemplate}) {
    print('=== HANDLE WORKOUT CREATION FOR TRAINEE ===');
    print('Mode: $mode');
    print('Template: ${selectedTemplate?.name ?? 'None'}');
    print('Trainee: ${trainee.name} (${trainee.id})');

    // Use Future.delayed to ensure the previous dialog is properly closed, then directly create workout
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mode == WorkoutCreationMode.fromScratch) {
        print('Creating workout from scratch for ${trainee.name}');
        _createBasicWorkoutForTrainee(trainee);
      } else if (mode == WorkoutCreationMode.fromTemplate && selectedTemplate != null) {
        print('Creating workout from template: ${selectedTemplate.name} for ${trainee.name}');
        _createWorkoutFromTemplateForTrainee(selectedTemplate, trainee);
      } else {
        print('❌ Invalid mode or missing template');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid workout creation mode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${exercise.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    // Proposed Effort (trainer input)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proposed Effort:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '${exercise.sets} sets × ${exercise.reps} reps${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (exercise.actualSets.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                        child: Text('Actual Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      for (int i = 0; i < exercise.actualSets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0, top: 2.0, bottom: 2.0),
                          child: Text(
                            'Set ${i + 1}: ${exercise.actualSets[i].reps} reps, ${exercise.actualSets[i].kg} kg',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ]
                  ],
                ),
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

  void _duplicateWorkout(TrainingModel training) async {
    final duplicated = TrainingModel(
      id: const Uuid().v4(),
      name: training.name + " (Copy)",
      description: training.description,
      traineeId: training.traineeId,
      trainerId: training.trainerId,
      exercises: training.exercises,
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      difficulty: training.difficulty,
      estimatedDuration: training.estimatedDuration,
      category: training.category,
      notes: training.notes,
    );
    await TrainingService().createTraining(duplicated);
    setState(() {
      _trainings.add(duplicated);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout duplicated as "${duplicated.name}"')),
      );
    }
  }

  void _deleteWorkout(TrainingModel training) async {
    // Check if this is a recurring workout
    if (training.isRecurring) {
      // Show recurrence deletion dialog to choose scope
      await showDialog(
        context: context,
        builder: (context) => RecurrenceDeletionDialog(
          training: training,
          onScopeSelected: (scope) {
            Navigator.pop(context);
            _showDeleteConfirmationDialog(training, scope);
          },
        ),
      );
    } else {
      // Single workout, delete directly
      _showDeleteConfirmationDialog(training, DeletionScope.single);
    }
  }

  void _showDeleteConfirmationDialog(TrainingModel training, DeletionScope deletionScope) async {
    final isDeleteAll = deletionScope == DeletionScope.all;
    final workoutCount = isDeleteAll ? training.totalRecurrences : 1;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Confirm Deletion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDeleteAll
                ? 'Are you sure you want to delete all ${workoutCount} workouts in this recurring series?'
                : 'Are you sure you want to delete "${training.name}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (isDeleteAll) {
                // Delete all workouts in recurrence group
                final deletedIds = await _trainingService.deleteRecurrenceGroup(
                  training.recurrenceGroupId!
                );

                setState(() {
                  _trainings.removeWhere((t) => deletedIds.contains(t.id));
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted ${deletedIds.length} workouts from the series'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                // Delete single workout
                await _trainingService.deleteTraining(training.id);

                setState(() {
                  _trainings.removeWhere((t) => t.id == training.id);
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Workout "${training.name}" deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isDeleteAll ? 'Delete All' : 'Delete'),
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

  void _openTemplates() {
    context.go(RouteNames.templates);
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