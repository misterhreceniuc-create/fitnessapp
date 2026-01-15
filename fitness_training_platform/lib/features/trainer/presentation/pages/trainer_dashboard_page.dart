/// @file trainer_dashboard_page.dart
/// @brief Trainer dashboard interface for managing workouts, trainees, and goals
/// @details This file contains the main dashboard interface for fitness trainers.
/// The dashboard is organized into four tabs: Trainees (managing trainer-trainee
/// relationships), Assigned Workouts (creating, editing, and monitoring workouts),
/// Assigned Goals (creating and tracking trainee fitness goals), and Assigned
/// Nutrition Plans. The page integrates with multiple services (UserService,
/// TrainingService, TemplateService, GoalService) to provide comprehensive
/// workout and trainee management functionality. It supports both single and
/// recurring workout creation, bulk operations, progress tracking, and goal
/// management for multiple trainees.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/services/localization_service.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../shared/models/goal_model.dart';
import '../../../../shared/models/nutrition_model.dart';
import '../../../../shared/services/user_service.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../shared/services/template_service.dart';
import '../../../../shared/services/goal_service.dart';
import '../../../../shared/services/nutrition_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../routing/route_names.dart';
import '../widgets/workout_creation_wizard.dart';
import '../widgets/workout_creation_mode_dialog.dart';
import '../widgets/recurrence_edit_dialog.dart';
import '../widgets/recurrence_deletion_dialog.dart';
import '../widgets/progress_report_dialog.dart';
import '../widgets/goal_creation_dialog.dart';
import '../widgets/nutrition_assignment_dialog.dart';
import '../widgets/trainee_nutrition_log_dialog.dart';

/// @class TrainerDashboardPage
/// @brief Stateful widget providing the root trainer dashboard interface
/// @details This is the main entry point for the trainer dashboard. It creates
/// a stateful widget that manages tab-based navigation and coordinates with
/// multiple services for workout and trainee management. The dashboard uses
/// a TabBarView to organize features across four main sections: trainees,
/// workouts, goals, and nutrition planning.
class TrainerDashboardPage extends StatefulWidget {
  /// @brief Constructor for the trainer dashboard page
  /// @details Creates an immutable TrainerDashboardPage widget with no required
  /// parameters. This widget manages tab-based navigation for trainers to access
  /// workout creation, trainee management, and progress tracking features.
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

/// @class _TrainerDashboardPageState
/// @brief State class managing the trainer dashboard UI and data interactions
/// @details This state class implements the complete trainer dashboard functionality
/// including tab navigation, data loading, and all CRUD operations for workouts,
/// trainees, and goals. It uses SingleTickerProviderStateMixin to support smooth
/// tab animations. The class maintains in-memory caches of trainees, trainings,
/// and goals loaded from services, and implements the UI for four main tabs:
/// trainees management, workout creation/editing, goal management, and nutrition
/// planning. It coordinates multiple service interactions through dependency
/// injection and handles complex workflows like recurring workout management,
/// progress reporting, and bulk operations.
class _TrainerDashboardPageState extends State<TrainerDashboardPage> with SingleTickerProviderStateMixin {
  /// @brief Service for managing user data and trainee relationships
  final UserService _userService = sl.get<UserService>();

  /// @brief Service for CRUD operations on training sessions and workouts
  final TrainingService _trainingService = sl.get<TrainingService>();

  /// @brief Service for managing workout templates and template operations
  final TemplateService _templateService = sl.get<TemplateService>();

  /// @brief Service for managing fitness goals assigned to trainees
  final GoalService _goalService = sl.get<GoalService>();

  /// @brief Controls the four tabs in the dashboard's TabBarView
  /// @details Manages animations and switching between Trainees, Workouts, Goals,
  /// and Nutrition tabs. Created in initState and disposed in dispose method.
  late TabController _tabController;

  /// @brief In-memory cache of trainees assigned to the current trainer
  /// @details Populated in _loadData() from UserService. Used to display the
  /// trainee list, enable trainee selection for workout creation, and display
  /// trainee-specific statistics in the trainees tab.
  List<UserModel> _trainees = [];

  /// @brief In-memory cache of all workouts created by the current trainer
  /// @details Populated in _loadData() from TrainingService. Includes both single
  /// and recurring workouts. Displayed in the Assigned Workouts tab and used for
  /// filtering operations (e.g., finding workouts for a specific trainee).
  List<TrainingModel> _trainings = [];

  /// @brief In-memory cache of all goals assigned to trainees by the current trainer
  /// @details Populated in _loadData() from GoalService. Used to display progress
  /// tracking and goal management functionality in the Assigned Goals tab.
  List<GoalModel> _goals = [];

  /// @brief In-memory cache of all nutrition plans assigned by the current trainer
  /// @details Populated in _loadData() from NutritionService. Used to display
  /// nutrition plans in the Assigned Nutrition Plan tab.
  List<NutritionPlanModel> _nutritionPlans = [];

  /// @brief Loading state indicator for the entire dashboard
  /// @details When true, the dashboard displays a CircularProgressIndicator
  /// instead of content. Set to true initially and when refresh is triggered,
  /// set to false after _loadData() completes (successfully or with error).
  bool _isLoading = true;

  /// @brief Initiates the edit workflow for a workout
  /// @details Determines whether the workout is recurring and shows appropriate
  /// dialogs. For recurring workouts, displays RecurrenceEditDialog to let the
  /// trainer choose to edit this instance only or all instances. For single
  /// workouts, directly shows the edit dialog.
  /// @param training The training model to edit
  void _editWorkout(TrainingModel training) async {
    // Check if this is a recurring workout to determine edit scope options
    if (training.isRecurring) {
      // Show recurrence edit dialog to choose scope (single or all in series)
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
      // Single workout, edit directly without scope selection
      _showEditWorkoutDialog(training, EditScope.single);
    }
  }

  /// @brief Shows the workout creation/editing dialog with appropriate settings
  /// @details Opens WorkoutCreationWizard with the training data pre-populated
  /// for editing. Handles update logic based on editScope: for single workouts,
  /// updates only the specified workout; for all recurrences, updates the entire
  /// recurring group using TrainingService.updateRecurrenceGroup(). Shows
  /// success/error snackbars and updates the UI cache with modified data.
  /// @param training The training to edit
  /// @param editScope Whether to edit single instance or all recurring workouts
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
              final lang = context.read<LanguageProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(lang.translate('workout_updated', params: {'name': updated.name}))),
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
              final lang = context.read<LanguageProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(lang.translate('updated_workouts_in_series', params: {'count': '${updatedTrainings.length}'})),
                ),
              );
            }
          }
        },
      ),
    );
  }


  /// @brief Initializes the state and loads initial data
  /// @details Creates the TabController with 4 tabs (for tab animation support)
  /// and triggers the initial data load. Called once when the widget is first
  /// created. Sets vsync: this to enable smooth tab animations.
  @override
  void initState() {
    super.initState();
    // Create TabController for managing the 4 dashboard tabs
    _tabController = TabController(length: 4, vsync: this);
    // Load trainees, trainings, and goals from services
    _loadData();
  }

  /// @brief Cleans up resources when the widget is disposed
  /// @details Disposes the TabController to prevent memory leaks. Called when
  /// the widget is permanently removed from the widget tree.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// @brief Loads all dashboard data from services
  /// @details Retrieves the current user from AuthProvider, then loads trainees,
  /// trainings, and goals for the current trainer from their respective services.
  /// Includes debug logging for troubleshooting. Updates _trainees, _trainings,
  /// and _goals lists and sets _isLoading to false. On error, displays an error
  /// snackbar and logs the exception.
  /// @return Future<void> Completes when all data is loaded
  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      try {
        final trainees = await _userService.getTrainees(currentUser.id);
        final trainings = await _trainingService.getTrainingsForTrainer(currentUser.id);
        final goals = await _goalService.getGoalsForTrainer(currentUser.id);

        // Load nutrition plans for all trainees
        final nutritionService = sl.get<NutritionService>();
        List<NutritionPlanModel> allNutritionPlans = [];
        for (var trainee in trainees) {
          final plans = await nutritionService.getNutritionPlansForTrainee(trainee.id);
          allNutritionPlans.addAll(plans);
        }

        print('=== TRAINER DEBUG INFO ===');
        print('Trainer ID: ${currentUser.id}');
        print('Found ${trainees.length} trainees');
        for (var trainee in trainees) {
          print('- Trainee: ${trainee.name} (ID: ${trainee.id})');
        }
        print('Found ${trainings.length} trainings created by this trainer');
        print('Found ${goals.length} goals created by this trainer');
        print('Found ${allNutritionPlans.length} nutrition plans');

        if (mounted) {
          setState(() {
            _trainees = trainees;
            _trainings = trainings;
            _goals = goals;
            _nutritionPlans = allNutritionPlans;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading trainer data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          final lang = context.read<LanguageProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lang.translate('error_loading_data')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// @brief Builds the main dashboard UI with app bar and tabbed content
  /// @details Constructs the Scaffold with AppBar showing trainer name and action
  /// buttons (refresh, templates, notifications, logout). Displays a TabBar with
  /// 4 tabs and a TabBarView that switches between _buildTraineesTab(),
  /// _buildWorkoutsTab(), _buildAssignedGoalsTab(), and _buildNutritionTab().
  /// Shows loading indicator while _isLoading is true. Includes a floating action
  /// button for creating new workouts.
  /// @return Widget The complete trainer dashboard UI
  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${lang.translate('trainer_dashboard')} - ${currentUser?.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
            tooltip: lang.translate('refresh'),
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: _openTemplates,
            tooltip: lang.translate('templates'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
            tooltip: lang.translate('notifications'),
          ),
          const LanguageSwitcher(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: lang.translate('logout'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.people), text: lang.translate('trainees')),
            Tab(icon: const Icon(Icons.fitness_center), text: lang.translate('assigned_workouts')),
            Tab(icon: const Icon(Icons.flag), text: lang.translate('assigned_goals')),
            Tab(icon: const Icon(Icons.restaurant), text: lang.translate('assigned_nutrition')),
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
                _buildAssignedGoalsTab(),
                _buildNutritionTab(),
              ],
            ),
    );
  }

  /// @brief Builds the Trainees tab UI
  /// @details Displays a list of trainees assigned to the current trainer with
  /// their workout statistics. Shows "Add Trainee" and "Refresh" buttons. Each
  /// trainee is displayed as a Card with avatar, name, email, ID, and workout
  /// counts. Includes action buttons for creating workouts and viewing progress.
  /// Shows empty state when no trainees are available.
  /// @return Widget The trainees tab content
  Widget _buildTraineesTab() {
    final lang = context.watch<LanguageProvider>();
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
                  label: Text(lang.translate('add_trainee')),
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
                  label: Text(lang.translate('refresh')),
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
                    lang.translate('found_trainees', params: {'count': '${_trainees.length}'}),
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _trainees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          lang.translate('no_trainees_yet'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(lang.translate('trainees_appear_here')),
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
                              Text(lang.translate('workouts_assigned_completed', params: {
                                'assigned': '$assignedWorkouts',
                                'completed': '$completedWorkouts'
                              })),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _createWorkoutForTrainee(trainee),
                                icon: const Icon(Icons.fitness_center, color: Colors.blue),
                                tooltip: lang.translate('tooltip_create_workout'),
                              ),
                              IconButton(
                                onPressed: () => _assignNutrition(trainee),
                                icon: const Icon(Icons.restaurant_menu, color: Colors.green),
                                tooltip: lang.translate('tooltip_assign_nutrition'),
                              ),
                              IconButton(
                                onPressed: () => _createGoalForTrainee(trainee),
                                icon: const Icon(Icons.flag, color: Colors.purple),
                                tooltip: lang.translate('tooltip_create_goal'),
                              ),
                              IconButton(
                                onPressed: () => _viewProgress(trainee.name),
                                icon: const Icon(Icons.analytics, color: Colors.orange),
                                tooltip: lang.translate('tooltip_view_progress'),
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

  /// @brief Builds the Assigned Workouts tab UI
  /// @details Displays all workouts created by the trainer. Shows buttons for
  /// creating from template, scheduling, and testing. Each workout is displayed
  /// as a Card with name, assignee, exercise count, duration, difficulty badge,
  /// completion status, and a popup menu for view, progress report, edit, duplicate,
  /// and delete actions. Recurring workouts display a recurrence badge. Shows
  /// empty state when no workouts exist.
  /// @return Widget The workouts tab content
  Widget _buildWorkoutsTab() {
    final lang = context.watch<LanguageProvider>();
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
                  label: Text(lang.translate('template')),
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
                  label: Text(lang.translate('schedule')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createTestWorkout,
                  icon: const Icon(Icons.bug_report),
                  label: Text(lang.translate('test')),
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
                    lang.translate('created_workouts_total', params: {'count': '${_trainings.length}'}),
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _trainings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          lang.translate('no_workouts_created_yet'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(lang.translate('create_first_workout')),
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
                              Text('${lang.translate('assigned_to')}: ${trainee?.name ?? lang.translate('unknown_trainee')} (${training.traineeId})'),
                              Text(lang.translate('exercises_duration', params: {
                                'exercises': '${training.exercises.length}',
                                'duration': '${training.estimatedDuration}'
                              })),
                              Text(
                                '${lang.translate('scheduled')}: ${training.scheduledDate.toString().split(' ')[0]}',
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
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.visibility),
                                        const SizedBox(width: 8),
                                        Text(lang.translate('view_details')),
                                      ],
                                    ),
                                  ),
                                  if (training.isCompleted)
                                    PopupMenuItem(
                                      value: 'progress',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.analytics, color: Colors.purple),
                                          const SizedBox(width: 8),
                                          Text(lang.translate('progress_report'), style: const TextStyle(color: Colors.purple)),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    enabled: !training.isCompleted,
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: training.isCompleted ? Colors.grey : null),
                                        const SizedBox(width: 8),
                                        Text(lang.translate('edit'), style: TextStyle(color: training.isCompleted ? Colors.grey : null)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy),
                                        const SizedBox(width: 8),
                                        Text(lang.translate('duplicate')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text(lang.translate('delete'), style: const TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  switch (value) {
                                    case 'view':
                                      _viewWorkoutDetails(training);
                                      break;
                                    case 'progress':
                                      _viewProgressReport(training);
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

  /// @brief Builds the Assigned Goals tab UI
  /// @details Displays all fitness goals assigned to trainees by the trainer.
  /// Shows a "Create Goal" button and refresh button. Each goal is displayed as
  /// a Card with name, trainee, goal type badge (weight, measurement, performance),
  /// progress value, progress bar, days remaining indicator, and completion status.
  /// Includes popup menu for view details and delete actions. Shows empty state
  /// when no goals exist.
  /// @return Widget The goals tab content
  Widget _buildAssignedGoalsTab() {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showTraineeSelectionForGoal,
                  icon: const Icon(Icons.flag),
                  label: Text(lang.translate('create_goal')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: Text(lang.translate('refresh')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    lang.translate('created_goals_total', params: {'count': '${_goals.length}'}),
                    style: const TextStyle(color: Colors.purple),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _goals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flag, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          lang.translate('no_goals_created_yet'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(lang.translate('create_first_goal')),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _goals.length,
                    itemBuilder: (context, index) {
                      final goal = _goals[index];
                      final trainee = _getTraineeById(goal.traineeId);
                      final progress = goal.progressPercentage;
                      final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: goal.isCompleted ? Colors.green : Colors.purple,
                            child: Icon(
                              goal.isCompleted ? Icons.check : Icons.flag,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getGoalTypeColor(goal.type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getGoalTypeLabel(goal.type),
                                  style: TextStyle(
                                    color: _getGoalTypeColor(goal.type),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${lang.translate('assigned_to')}: ${trainee?.name ?? lang.translate('unknown_trainee')} (${goal.traineeId})'),
                              Text(
                                '${lang.translate('progress')}: ${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  goal.isCompleted ? Colors.green : Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                daysRemaining > 0
                                    ? lang.translate('deadline_days_remaining', params: {'days': '$daysRemaining'})
                                    : lang.translate('deadline_overdue'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: daysRemaining > 0 ? Colors.grey : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    const Icon(Icons.visibility),
                                    const SizedBox(width: 8),
                                    Text(lang.translate('view_details')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(lang.translate('delete'), style: const TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'view':
                                  _viewGoalDetails(goal);
                                  break;
                                case 'delete':
                                  _deleteGoal(goal);
                                  break;
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the Assigned Nutrition Plans tab UI
  /// @details Displays all nutrition plans assigned to trainees with options to
  /// view food logs and manage plans
  /// @return Widget The nutrition tab content
  Widget _buildNutritionTab() {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with count
          Row(
            children: [
              const Icon(Icons.restaurant_menu, size: 24),
              const SizedBox(width: 12),
              Text(
                lang.translate('assigned_nutrition_plans_count', params: {'count': '${_nutritionPlans.length}'}),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List of nutrition plans
          Expanded(
            child: _nutritionPlans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          lang.translate('no_nutrition_plans_assigned'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.translate('assign_plans_from_trainees_tab'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _nutritionPlans.length,
                    itemBuilder: (context, index) {
                      final plan = _nutritionPlans[index];
                      final trainee = _getTraineeById(plan.traineeId);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.restaurant_menu, color: Colors.orange.shade700, size: 28),
                          ),
                          title: Text(
                            plan.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    trainee?.name ?? lang.translate('unknown_trainee'),
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    lang.translate('kcal_per_day', params: {'calories': '${plan.dailyCalories}'}),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.restaurant, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    lang.translate('recipes_count', params: {'count': '${plan.recipes.length}'}),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lang.translate('created')}: ${plan.createdAt.toString().split(' ')[0]}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: trainee != null ? () => _viewNutritionLog(trainee) : null,
                            icon: const Icon(Icons.restaurant, size: 18),
                            label: Text(lang.translate('view_food_log')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// @brief Helper Methods Section
  /// @details These methods provide utility functions for data lookup and UI formatting

  /// @brief Retrieves a trainee by their ID from the cached trainees list
  /// @details Searches the _trainees list for a trainee with the specified ID.
  /// Returns null if no trainee is found (caught exception).
  /// @param traineeId The unique identifier of the trainee to find
  /// @return UserModel? The trainee if found, null otherwise
  UserModel? _getTraineeById(String traineeId) {
    try {
      return _trainees.firstWhere((trainee) => trainee.id == traineeId);
    } catch (e) {
      return null;
    }
  }

  /// @brief Gets the name of a trainee by their ID
  /// @details Convenience method that looks up a trainee and returns their name.
  /// Returns 'Unknown' if the trainee is not found.
  /// @param traineeId The unique identifier of the trainee
  /// @return String The trainee's name or 'Unknown'
  String _getTraineeName(String traineeId) {
    final trainee = _getTraineeById(traineeId);
    return trainee?.name ?? 'Unknown';
  }

  /// @brief Returns the Material Design color for a workout difficulty level
  /// @details Maps difficulty strings to appropriate color indicators:
  /// beginner = green, intermediate = orange, advanced = red, default = grey
  /// Used for color-coding difficulty badges throughout the UI.
  /// @param difficulty The difficulty level string (beginner, intermediate, advanced)
  /// @return Color The Material Design color for the difficulty level
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

  /// @brief Action Methods Section
  /// @details These methods handle user interactions and initiate workflows

  /// @brief Initiates the new workout creation workflow
  /// @details Shows WorkoutCreationModeDialog to let trainer choose between
  /// creating from scratch or from template. Validates that trainees exist before
  /// proceeding. Routes to appropriate trainee selection and creation flow based
  /// on selected mode.
  void _createNewWorkout() {
    print('=== NEW WORKOUT BUTTON CLICKED ===');
    print('Trainees count: ${_trainees.length}');

    if (_trainees.isEmpty) {
      print('❌ No trainees available');
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.translate('no_trainees_available_message')} ${lang.translate('system_has_mock_trainees')}'),
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
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('error_with_message', params: {'message': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// @brief Handles the workout creation mode selection
  /// @details Routes to appropriate workflow based on selected mode (from scratch
  /// or from template). Uses Future.delayed to ensure proper dialog dismissal
  /// before showing next dialog. Shows error snackbar if mode is invalid.
  /// @param mode The workout creation mode selected (fromScratch or fromTemplate)
  /// @param selectedTemplate Optional template if mode is fromTemplate
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error')}: ${lang.translate('invalid_workout_mode')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// @brief Shows trainee selection dialog for creating a new workout from scratch
  /// @details Displays an AlertDialog with a list of available trainees. When a
  /// trainee is selected, closes the dialog and calls _createBasicWorkoutForTrainee()
  /// to open the workout creation wizard with that trainee pre-selected.
  void _showTraineeSelectionForNewWorkout() {
    print('📋 Showing trainee selection dialog for new workout');
    showDialog(
      context: context,
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Text(lang.translate('create_new_workout')),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.translate('select_trainee_to_create_workout_for')),
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
                        subtitle: Text(lang.translate('id_display', params: {'id': trainee.id})),
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
            child: Text(lang.translate('cancel')),
          ),
        ],
      );
      },
    );
  }

  /// @brief Shows trainee selection dialog for creating a workout from template
  /// @details Displays an AlertDialog with a list of available trainees. When a
  /// trainee is selected, closes the dialog and calls _createWorkoutFromTemplateForTrainee()
  /// to create a new workout using the selected template for that trainee.
  /// @param template The WorkoutTemplate to use for creating the workout
  void _showTraineeSelectionForTemplate(WorkoutTemplate template) {
    print('📋 Showing trainee selection dialog for template: ${template.name}');
    showDialog(
      context: context,
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Text(lang.translate('use_template_colon', params: {'name': template.name})),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.translate('select_trainee_for_template')),
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
                        subtitle: Text(lang.translate('id_display', params: {'id': trainee.id})),
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
            child: Text(lang.translate('cancel')),
          ),
        ],
      );
      },
    );
  }

  /// @brief Opens workout creation wizard for a trainee with from-scratch workflow
  /// @details Displays WorkoutCreationWizard with the specified trainee pre-selected.
  /// When the user creates a workout, it adds the current trainer ID and persists
  /// to TrainingService. Updates the UI cache and shows success/error feedback.
  /// @param trainee The trainee to create a workout for
  void _createBasicWorkoutForTrainee(UserModel trainee) {
    print('🎨 Opening WorkoutCreationWizard for: ${trainee.name}');

    // Use the WorkoutCreationWizard mechanism for "Create from scratch"
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
                  final lang = context.read<LanguageProvider>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(lang.translate('custom_workout_created', params: {'name': workout.name, 'trainee': trainee.name})),
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
                  final lang = context.read<LanguageProvider>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lang.translate('error_creating_workout')}: $e'),
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

  /// @brief Creates a workout for a trainee based on a template
  /// @details Converts the WorkoutTemplate to a TrainingModel, sets the trainee
  /// and trainer IDs, schedules it for tomorrow, and persists to TrainingService.
  /// Updates the UI cache and shows success/error feedback. Requires valid
  /// current user from AuthProvider.
  /// @param template The WorkoutTemplate to use as the base
  /// @param trainee The trainee to assign the workout to
  /// @return Future<void> Completes when the workout is created
  Future<void> _createWorkoutFromTemplateForTrainee(WorkoutTemplate template, UserModel trainee) async {
    print('Creating workout from template: ${template.name} for ${trainee.name}');

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    try {
      // Convert template to training model with trainee and date information
      final workout = template.toTrainingModel(
        traineeId: trainee.id,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      ).copyWith(trainerId: currentUser.id); // Ensure the current trainer is assigned

      final createdWorkout = await _trainingService.createTraining(workout);

      setState(() {
        _trainings.add(createdWorkout);
      });

      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(lang.translate('workout_created_for', params: {'name': template.name, 'trainee': trainee.name})),
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error_creating_workout')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// @brief Creates a test workout for debugging purposes
  /// @details Creates a hardcoded test workout for trainee 'trainee3' (Mike Johnson)
  /// with three exercises (Push-ups, Squats, Plank). Used for testing the system
  /// before mock data is fully integrated. Shows success notification and debug logs.
  void _createTestWorkout() {
    // Create a test workout with exercises for system verification
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${lang.translate('test_workout_created')}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${lang.translate('error_creating_test_workout')}: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// @brief Shows placeholder for add trainee feature
  /// @details Currently displays a "coming soon" snackbar. To be implemented
  /// in future releases with functionality to assign new trainees.
  void _addTrainee() {
    final lang = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${lang.translate('add_trainee_feature')} - ${lang.translate('coming_soon')}')),
    );
  }

  /// @brief Refreshes all dashboard data from services
  /// @details Sets _isLoading to true, triggers UI update, then calls _loadData()
  /// to reload trainees, trainings, and goals from services. Useful for syncing
  /// with backend or refreshing stale data after operations.
  void _refreshData() {
    setState(() {
      _isLoading = true;
    });
    _loadData();
  }

  /// @brief Shows dialog to create a new workout template
  /// @details Displays WorkoutCreationModeDialog to let trainer choose between
  /// creating from scratch or from template. Validates trainees exist first.
  void _createWorkoutTemplate() {
    if (_trainees.isEmpty) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.translate('no_trainees_available_message')} ${lang.translate('system_has_mock_trainees')}'),
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

  /// @brief Shows placeholder for schedule workout feature
  /// @details Currently displays a "coming soon" snackbar. To be implemented
  /// in future releases with calendar-based workout scheduling.
  void _scheduleWorkout() {
    final lang = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${lang.translate('schedule_workout_feature')} - ${lang.translate('coming_soon')}')),
    );
  }

  /// @brief Shows placeholder for create meal plan feature
  /// @details Currently displays a "coming soon" snackbar. To be implemented
  /// in future releases with nutrition planning functionality.
  void _createMealPlan() {
    final lang = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${lang.translate('create_meal_plan_feature')} - ${lang.translate('coming_soon')}')),
    );
  }

  /// @brief Shows placeholder for nutrition library feature
  /// @details Currently displays a "coming soon" snackbar. To be implemented
  /// in future releases with access to nutrition database and meal templates.
  void _nutritionLibrary() {
    final lang = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${lang.translate('nutrition_library_feature')} - ${lang.translate('coming_soon')}')),
    );
  }

  /// @brief Shows trainee selection dialog for creating a goal
  /// @details Displays an AlertDialog with a list of available trainees. When a
  /// trainee is selected, closes the dialog and calls _createGoalForTrainee()
  /// to open the goal creation form for that trainee.
  void _showTraineeSelectionForGoal() {
    if (_trainees.isEmpty) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('no_trainees_available_message')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Text(lang.translate('select_trainee')),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.translate('select_trainee_to_create_goal_for')),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _trainees.length,
                  itemBuilder: (context, index) {
                    final trainee = _trainees[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(trainee.name[0]),
                        ),
                        title: Text(trainee.name),
                        subtitle: Text(lang.translate('id_display', params: {'id': trainee.id})),
                        onTap: () {
                          Navigator.pop(context);
                          _createGoalForTrainee(trainee);
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
            child: Text(lang.translate('cancel')),
          ),
        ],
      );
      },
    );
  }

  /// @brief Opens goal creation dialog for a trainee
  /// @details Displays GoalCreationDialog with the specified trainee. When the
  /// user creates a goal, adds the current trainer ID and persists to GoalService.
  /// Updates the UI cache and shows success/error feedback.
  /// @param trainee The trainee to create a goal for
  void _createGoalForTrainee(UserModel trainee) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => GoalCreationDialog(
        trainee: trainee,
        onGoalCreated: (goal) async {
          try {
            final goalWithTrainer = GoalModel(
              id: goal.id,
              traineeId: goal.traineeId,
              trainerId: currentUser.id,
              name: goal.name,
              type: goal.type,
              targetValue: goal.targetValue,
              currentValue: goal.currentValue,
              unit: goal.unit,
              deadline: goal.deadline,
              isCompleted: goal.isCompleted,
              createdAt: goal.createdAt,
            );

            final createdGoal = await _goalService.createGoal(goalWithTrainer);

            setState(() {
              _goals.add(createdGoal);
            });

            if (mounted) {
              final lang = context.read<LanguageProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(lang.translate('goal_created_for', params: {'name': goal.name, 'trainee': trainee.name})),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.purple,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              final lang = context.read<LanguageProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${lang.translate('error_creating_goal')}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// @brief Shows detailed view of a goal
  /// @details Displays an AlertDialog showing goal details including trainee name,
  /// type, current/target values, progress percentage, progress bar, and deadline.
  /// Allows trainer to review goal status at a glance.
  /// @param goal The goal to display details for
  void _viewGoalDetails(GoalModel goal) {
    final trainee = _getTraineeById(goal.traineeId);
    showDialog(
      context: context,
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Text(goal.name),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${lang.translate('assigned_to')}: ${trainee?.name ?? lang.translate('unknown_trainee')} (${goal.traineeId})'),
              Text('${lang.translate('type')}: ${_getGoalTypeLabel(goal.type)}'),
              const SizedBox(height: 12),
              Text('${lang.translate('current')}: ${goal.currentValue.toStringAsFixed(1)} ${goal.unit}'),
              Text('${lang.translate('target')}: ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}'),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted ? Colors.green : Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              Text('${lang.translate('progress')}: ${goal.progressPercentage.toStringAsFixed(1)}%'),
              const SizedBox(height: 12),
              Text('${lang.translate('deadline')}: ${goal.deadline.toString().split(' ')[0]}'),
              Text(
                goal.isCompleted ? lang.translate('status_completed_checkmark') : lang.translate('status_in_progress_clock'),
                style: TextStyle(
                  color: goal.isCompleted ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('close')),
          ),
        ],
      );
      },
    );
  }

  /// @brief Deletes a goal after confirmation
  /// @details Shows a confirmation dialog with warning about permanent deletion.
  /// If confirmed, removes the goal from GoalService and updates the UI cache.
  /// Shows success notification on deletion.
  /// @param goal The goal to delete
  void _deleteGoal(GoalModel goal) {
    showDialog(
      context: context,
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Text(lang.translate('delete_goal')),
        content: Text(lang.translate('are_you_sure_delete', params: {'name': goal.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _goalService.deleteGoal(goal.id);
              setState(() {
                _goals.removeWhere((g) => g.id == goal.id);
              });
              if (mounted) {
                final langContext = context.read<LanguageProvider>();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(langContext.translate('goal_deleted', params: {'name': goal.name})),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.translate('delete')),
          ),
        ],
      );
      },
    );
  }

  /// @brief Returns the Material Design color for a goal type
  /// @details Maps goal type enum to appropriate color indicators:
  /// weight = blue, measurement = orange, performance = green.
  /// Used for color-coding goal type badges in the UI.
  /// @param type The goal type enum value
  /// @return Color The Material Design color for the goal type
  Color _getGoalTypeColor(GoalType type) {
    switch (type) {
      case GoalType.weight:
        return Colors.blue;
      case GoalType.measurement:
        return Colors.orange;
      case GoalType.performance:
        return Colors.green;
    }
  }

  /// @brief Returns the display label for a goal type
  /// @details Maps goal type enum to human-readable labels for UI display.
  /// @param type The goal type enum value
  /// @return String The uppercase display label (WEIGHT, MEASUREMENT, PERFORMANCE)
  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.weight:
        return 'WEIGHT';
      case GoalType.measurement:
        return 'MEASUREMENT';
      case GoalType.performance:
        return 'PERFORMANCE';
    }
  }

  /// @brief Shows placeholder progress view for a trainee
  /// @details Displays an AlertDialog with placeholder content for progress tracking.
  /// To be implemented with actual progress charts and statistics.
  /// @param name The trainee's name to display in the dialog title
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

  /// @brief Shows detailed view of a trainee's profile and statistics
  /// @details Displays an AlertDialog with trainee information (email, ID, role,
  /// membership date) and workout statistics (assigned and completed counts).
  /// Includes a "Create Workout" button to quickly create a workout for this trainee.
  /// @param trainee The trainee to display details for
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

  /// @brief Opens workout creation workflow for a specific trainee
  /// @details Shows WorkoutCreationModeDialog with the trainee pre-selected.
  /// Skips the trainee selection step since it's already known. Routes to
  /// appropriate creation workflow based on selected mode.
  /// @param trainee The trainee to create a workout for
  void _createWorkoutForTrainee(UserModel trainee) {
    print('=== CREATE WORKOUT FOR TRAINEE BUTTON CLICKED ===');
    print('Trainee: ${trainee.name} (${trainee.id})');

    // Show workout creation mode dialog with trainee already selected
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

  /// @brief Opens nutrition assignment dialog for a trainee
  /// @details Displays the NutritionAssignmentDialog allowing the trainer to set
  /// daily caloric limits and assign recipes to the selected trainee
  /// @param trainee The trainee to assign nutrition plan to
  void _assignNutrition(UserModel trainee) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NutritionAssignmentDialog(
        trainerId: currentUser.id,
        trainee: trainee,
        onPlanCreated: _loadData,
      ),
    );
  }

  void _viewNutritionLog(UserModel trainee) {
    showDialog(
      context: context,
      builder: (context) => TraineeNutritionLogDialog(
        trainee: trainee,
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error')}: ${lang.translate('invalid_workout_mode')}'),
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
              ...training.exercises.map((exercise) {
                final lang = context.watch<LanguageProvider>();
                final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
                return Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• $translatedName', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              );
              }),
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

  void _viewProgressReport(TrainingModel training) {
    final lang = context.read<LanguageProvider>();
    if (!training.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('progress_report_only_completed')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trainee = _getTraineeById(training.traineeId);
    if (trainee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('trainee_not_found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ProgressReportDialog(
        completedTraining: training,
        traineeName: trainee.name,
      ),
    );
  }

  void _duplicateWorkout(TrainingModel training) async {
    final lang = context.read<LanguageProvider>();
    final duplicated = TrainingModel(
      id: const Uuid().v4(),
      name: training.name + lang.translate('copy_suffix'),
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
    await sl.get<TrainingService>().createTraining(duplicated);
    setState(() {
      _trainings.add(duplicated);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('workout_duplicated_as', params: {'name': duplicated.name}))),
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
      builder: (context) {
        final lang = context.watch<LanguageProvider>();
        return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(lang.translate('confirm_deletion')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDeleteAll
                ? lang.translate('are_you_sure_delete_workouts', params: {'count': '$workoutCount'})
                : lang.translate('are_you_sure_delete_workout', params: {'name': training.name}),
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
                      lang.translate('action_cannot_undone'),
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
            child: Text(lang.translate('cancel')),
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
                  final lang = context.read<LanguageProvider>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.translate('deleted_workouts_from_series', params: {'count': '${deletedIds.length}'})),
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
                  final lang = context.read<LanguageProvider>();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lang.translate('delete')}: "${training.name}"'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isDeleteAll ? lang.translate('delete_all') : lang.translate('delete')),
          ),
        ],
      );
      },
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