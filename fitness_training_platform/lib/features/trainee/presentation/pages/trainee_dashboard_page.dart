/// @file trainee_dashboard_page.dart
/// @brief Trainee dashboard page for viewing and managing workout assignments
/// @details This file contains the main dashboard interface for trainees (fitness learners).
/// The dashboard provides a comprehensive view of workout assignments, progress tracking,
/// and fitness goals. It features three primary tabs: Progress (goals and measurements),
/// Workouts (assigned training sessions), and Nutrition (meal planning).
///
/// Key features include:
/// - Workout management: view, start, and complete workouts in normal or bulk mode
/// - Progress tracking: weight logging, body measurements, and goal monitoring
/// - Activity tracking: daily step counting with auto-sync from health data
/// - State management: uses Provider for authentication and SharedPreferences for preferences
/// - Real-time data loading from multiple services (TrainingService, MeasurementService, etc.)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/services/localization_service.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/goal_model.dart';
import '../../../../shared/models/nutrition_model.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../shared/services/nutrition_service.dart';
import '../../../../shared/services/measurement_service.dart';
import '../../../../shared/services/health_service.dart';
import '../../../../shared/services/steps_service.dart';
import '../../../../shared/services/goal_service.dart';
import '../../../../shared/models/measurement_model.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../routing/route_names.dart';
import '../widgets/workout_session_dialog.dart';
import '../widgets/bulk_workout_dialog.dart';
import '../widgets/food_log_dialog.dart';

/// @class TraineeDashboardPage
/// @brief Main dashboard widget for trainee users
/// @details StatefulWidget that displays the trainee's fitness dashboard with three tabs:
/// 1. Progress Tab - Shows weight tracking, measurements, goals, steps, and progress pictures
/// 2. Workouts Tab - Displays assigned workouts with ability to start/continue/complete them
/// 3. Nutrition Tab - Displays calorie tracking and nutrition information
///
/// The page integrates with multiple services to provide real-time data:
/// - TrainingService: fetches assigned workouts
/// - MeasurementService: loads weight and body measurements
/// - GoalService: retrieves fitness goals
/// - StepsService: manages step counting data
/// - HealthService: syncs with device health data
///
/// Users can select their preferred workout mode (normal or bulk) which is saved
/// to SharedPreferences and applied to future workouts.
class TraineeDashboardPage extends StatefulWidget {
  /// @brief Constructor for TraineeDashboardPage
  /// @details Creates a new instance of the trainee dashboard with default settings.
  /// No parameters are required as all state is managed by the state class and services.
  const TraineeDashboardPage({super.key});

  @override
  State<TraineeDashboardPage> createState() => _TraineeDashboardPageState();
}

/// @class _TraineeDashboardPageState
/// @brief State class for TraineeDashboardPage
/// @details Manages the stateful logic for the trainee dashboard including:
/// - Service initialization and dependency injection
/// - Tab navigation and view state management
/// - Data loading from multiple service layers
/// - Workout mode preference persistence
/// - Dialog management for user interactions (weight logging, step tracking, etc.)
///
/// The state uses SingleTickerProviderStateMixin to support TabBar animation.
/// All user data is loaded asynchronously in initState() and cached locally
/// for fast UI updates. The state rebuilds when data changes via setState().
class _TraineeDashboardPageState extends State<TraineeDashboardPage> with SingleTickerProviderStateMixin {
  /// @brief Service for managing training/workout operations
  /// @details Injected via service locator pattern. Used to fetch trainings
  /// assigned to current trainee, update workout progress, and track completion.
  final TrainingService _trainingService = sl.get<TrainingService>();

  /// @brief Service for nutrition/meal planning operations
  /// @details Injected via service locator. Provides nutrition-related data
  /// and meal plan information for the nutrition tab.
  final NutritionService _nutritionService = sl.get<NutritionService>();

  /// @brief Service for body measurement and weight tracking
  /// @details Injected via service locator. Manages weight logs and body
  /// measurements (waist, chest, arms, hips) for progress tracking.
  final MeasurementService _measurementService = sl.get<MeasurementService>();

  /// @brief Service for syncing with device health data
  /// @details Injected via service locator. Integrates with device health
  /// sensors to automatically fetch step count data from Google Fit, Apple Health, etc.
  final HealthService _healthService = sl.get<HealthService>();

  /// @brief Service for manual step entry and tracking
  /// @details Injected via service locator. Allows users to manually log steps
  /// when automatic sync is unavailable or if they prefer manual entry.
  final StepsService _stepsService = sl.get<StepsService>();

  /// @brief Service for managing fitness goals
  /// @details Injected via service locator. Loads and tracks weight, measurement,
  /// and performance goals assigned by the trainer.
  final GoalService _goalService = sl.get<GoalService>();

  /// @brief Controller for managing the three dashboard tabs
  /// @details Initialized in initState(). Controls which tab is currently visible
  /// (Progress, Workouts, or Nutrition). Uses TabBar for navigation.
  late TabController _tabController;

  /// @brief List of all workouts assigned to the current trainee
  /// @details Cached from TrainingService.getTrainingsForTrainee().
  /// Updated whenever a workout is modified or a new workout is assigned.
  List<TrainingModel> _trainings = [];

  /// @brief List of body measurements (weight and measurements) for the trainee
  /// @details Cached from MeasurementService. Each entry contains weight,
  /// body measurements (waist, chest, arms, hips), and timestamp.
  List<MeasurementModel> _measurements = [];

  /// @brief List of fitness goals assigned to the trainee
  /// @details Cached from GoalService. Goals can be of types: weight, measurement,
  /// or performance, each with target values, deadlines, and progress tracking.
  List<GoalModel> _goals = [];

  /// @brief List of nutrition plans assigned to the trainee
  /// @details Cached from NutritionService. Contains daily caloric limits and recipes
  /// assigned by the trainer for meal planning and nutrition tracking.
  List<NutritionPlanModel> _nutritionPlans = [];

  /// @brief List of nutrition entries logged today by the trainee
  /// @details Contains food items consumed today with calorie information
  List<NutritionEntryModel> _todayNutritionEntries = [];

  /// @brief Current step count for today
  /// @details Updated from either manual entry or automatic device sync.
  /// Compared against 10,000 step goal to show progress.
  int _todaySteps = 0;

  /// @brief Flag indicating if today's steps were manually entered
  /// @details Used to show a "Manual" badge next to step count if true.

  /// @brief Flag indicating if today's steps were manually entered
  /// @details Used to show a "Manual" badge next to step count if true.
  /// True when user manually logs steps, false when fetched from device.
  bool _isManualSteps = false;

  /// @brief Flag indicating if initial data is still loading
  /// @details Shows loading spinner while fetching trainings, measurements,
  /// and goals. Set to false once all data is loaded.
  bool _isLoading = true;

  /// @brief Flag to show all weight entries vs. only recent 3
  /// @details Toggles expanded/collapsed view of weight history in progress tab.
  bool _showAllWeights = false;

  /// @brief Flag to show all measurement entries vs. only recent 3
  /// @details Toggles expanded/collapsed view of measurement history in progress tab.
  bool _showAllMeasurements = false;

  /// @brief Flag indicating if step data is currently loading
  /// @details Shows loading spinner while fetching step data from health service
  /// or manual entry. Separate from _isLoading for non-blocking updates.
  bool _isLoadingSteps = false;

  /// @brief User's preferred workout mode for new workouts
  /// @details Can be 'normal' (track each set individually) or 'bulk' (enter all at once).
  /// Saved to SharedPreferences and loaded on app startup.
  String _workoutMode = 'normal'; // 'normal' or 'bulk'

  /// @brief Initializes the state after the widget is created
  /// @details Called once when the state is first created. Sets up:
  /// 1. TabController for managing the 3 dashboard tabs
  /// 2. Loads user's workout mode preference from SharedPreferences
  /// 3. Initiates asynchronous data loading from services
  /// Does not block UI; loading spinner shown while data is fetched.
  /// @return void
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWorkoutModePreference();
    _loadData();
  }

  /// @brief Loads the user's preferred workout mode from persistent storage
  /// @details Retrieves 'workout_mode' from SharedPreferences. If not found,
  /// defaults to 'normal' mode. Updates the _workoutMode state variable
  /// which is used to determine which workout dialog to open when starting a workout.
  /// @return Future<void> Completes after preference is loaded and state updated
  Future<void> _loadWorkoutModePreference() async {
    final prefs = sl.get<SharedPreferences>();
    final mode = prefs.getString('workout_mode') ?? 'normal';
    setState(() {
      _workoutMode = mode;
    });
  }

  /// @brief Saves the user's workout mode preference to persistent storage
  /// @details Persists the selected mode ('normal' or 'bulk') to SharedPreferences
  /// and updates the local _workoutMode state. The saved preference is loaded
  /// on next app startup via _loadWorkoutModePreference().
  /// @param mode The workout mode to save ('normal' or 'bulk')
  /// @return Future<void> Completes after preference is saved and state updated
  Future<void> _saveWorkoutModePreference(String mode) async {
    final prefs = sl.get<SharedPreferences>();
    await prefs.setString('workout_mode', mode);
    setState(() {
      _workoutMode = mode;
    });
  }

  /// @brief Cleans up resources when the state is disposed
  /// @details Called when the widget is removed from the tree. Disposes
  /// the TabController to prevent memory leaks. Important for lifecycle
  /// management of animation controllers.
  /// @return void
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// @brief Loads all dashboard data from services asynchronously
  /// @details This is the main data loading method called during initState().
  /// It fetches data from multiple services concurrently:
  /// 1. Gets current user from AuthProvider
  /// 2. Fetches all trainings assigned to the trainee
  /// 3. Fetches all body measurements (weight, dimensions)
  /// 4. Fetches all goals (weight, measurement, performance)
  /// 5. Spawns separate thread to load steps data (non-blocking)
  ///
  /// Includes extensive debug logging to trace data relationships and
  /// troubleshoot assignment issues. All data is cached locally in state.
  /// Updates _isLoading flag to hide spinner once data arrives.
  /// Errors are caught and logged without crashing the app.
  ///
  /// @return Future<void> Completes when primary data is loaded (steps load separately)
  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      // Debug logging: Display current user information
      print('=== TRAINEE DEBUG INFO ===');
      print('Current User ID: ${currentUser.id}');
      print('Current User Name: ${currentUser.name}');
      print('Current User Email: ${currentUser.email}');

      try {
        // Fetch all workouts assigned to this trainee
        final trainings = await _trainingService.getTrainingsForTrainee(currentUser.id);
        print('Found ${trainings.length} trainings for this user');

        // Debug: Log each training assignment for verification
        for (var training in trainings) {
          print('- Training: ${training.name} (ID: ${training.id})');
          print('  Assigned to trainee ID: ${training.traineeId}');
          print('  Scheduled: ${training.scheduledDate}');
        }

        // Fetch all body measurements for this trainee
        final measurements = await _measurementService.getMeasurementsForTrainee(currentUser.id);
        print('Found ${measurements.length} measurements for this user');

        // Fetch all goals assigned to this trainee
        final goals = await _goalService.getGoalsForTrainee(currentUser.id);
        print('Found ${goals.length} goals for this user');

        // Fetch all nutrition plans assigned to this trainee
        final nutritionPlans = await _nutritionService.getNutritionPlansForTrainee(currentUser.id);
        print('Found ${nutritionPlans.length} nutrition plans for this user');

        // Fetch today's nutrition entries
        final todayNutritionEntries = await _nutritionService.getNutritionEntries(currentUser.id, DateTime.now());
        print('Found ${todayNutritionEntries.length} nutrition entries for today');

        // Update state with all loaded data and hide loading spinner
        setState(() {
          _trainings = trainings;
          _measurements = measurements;
          _goals = goals;
          _nutritionPlans = nutritionPlans;
          _todayNutritionEntries = todayNutritionEntries;
          _isLoading = false;
        });

        // Load steps data separately in background (don't block UI)
        _loadStepsData();
      } catch (e) {
        // Handle and log any errors during data loading
        print('Error loading data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// @brief Loads step count data for today from manual or automatic sources
  /// @details This method prioritizes data sources for step counting:
  /// 1. First checks if user manually logged steps today via StepsService
  /// 2. If no manual entry, falls back to device health data from HealthService
  /// 3. Updates _todaySteps and _isManualSteps flags accordingly
  ///
  /// This is called asynchronously after main data loads to avoid blocking UI.
  /// Shows loading indicator while fetching. Handles errors gracefully if
  /// health service is unavailable (defaults to 0 steps).
  ///
  /// The "mounted" check prevents setting state after widget is disposed.
  ///
  /// @return Future<void> Completes when step data is loaded
  Future<void> _loadStepsData() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    // Show loading indicator while fetching steps
    setState(() {
      _isLoadingSteps = true;
    });

    try {
      // Check for manual step entry first (takes precedence over auto-sync)
      final manualEntry = await _stepsService.getTodaySteps(currentUser.id);

      if (manualEntry != null) {
        // User manually logged steps - use this value
        if (mounted) {
          setState(() {
            _todaySteps = manualEntry.steps;
            _isManualSteps = true;
            _isLoadingSteps = false;
          });
        }
      } else {
        // No manual entry - try automatic sync from health data
        final steps = await _healthService.getTodaySteps();
        if (mounted) {
          setState(() {
            _todaySteps = steps;
            _isManualSteps = false;
            _isLoadingSteps = false;
          });
        }
      }
    } catch (e) {
      // Handle errors gracefully (health sync may fail)
      print('Error loading steps data: $e');
      if (mounted) {
        setState(() {
          _isLoadingSteps = false;
        });
      }
    }
  }

  /// @brief Shows dialog for manually logging daily steps
  /// @details Displays an AlertDialog allowing users to manually log or update
  /// their step count for today. Features:
  /// - Text input field with number keyboard for step count
  /// - Checks if today's entry already exists (shows "Update" vs "Save")
  /// - Validates input (checks for empty, non-numeric, or negative values)
  /// - Shows informational banner if updating existing entry
  /// - Calls StepsService to persist the entry
  /// - Shows success snackbar after saving
  /// - Automatically reloads step data via _loadStepsData()
  ///
  /// Users can only log one step count per day. Submitting a new value
  /// updates the existing entry for today.
  ///
  /// @return void (but shows dialog)
  void _showManualStepsDialog() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    // Check if user already logged steps today (for update vs. create)
    final todaySteps = await _stepsService.getTodaySteps(currentUser.id);
    final isUpdating = todaySteps != null;

    final stepsController = TextEditingController(
      text: isUpdating ? todaySteps.steps.toString() : '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdating ? 'Update Today\'s Steps' : 'Log Steps Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isUpdating
                ? 'Update your step count for today:'
                : 'Enter your step count for today:'),
            const SizedBox(height: 16),
            TextField(
              controller: stepsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps',
                border: OutlineInputBorder(),
                suffixText: 'steps',
              ),
            ),
            if (isUpdating) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can only log one step count per day',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final stepsText = stepsController.text.trim();
              if (stepsText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter step count')),
                );
                return;
              }

              final steps = int.tryParse(stepsText);
              if (steps == null || steps < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }

              if (currentUser != null) {
                await _stepsService.logManualSteps(
                  traineeId: currentUser.id,
                  date: DateTime.now(),
                  steps: steps,
                );

                // Reload steps
                await _loadStepsData();

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Steps ${isUpdating ? 'updated' : 'logged'}: ${steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps')),
                  );
                }
              }
            },
            child: Text(isUpdating ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  /// @brief Starts or resumes a workout, opening the appropriate dialog
  /// @details Intelligently determines which workout dialog to open based on:
  /// 1. If workout already completed: Opens normal mode dialog for viewing/editing
  /// 2. If workout already started: Detects which mode was used and resumes in that mode
  ///    - Normal mode: User logged sets individually, show partial set completion
  ///    - Bulk mode: User entered all at once, resume in bulk mode
  /// 3. If workout not started: Opens dialog based on user's preferred mode
  ///
  /// The mode detection works by checking for mixed set completion:
  /// If any exercise has some (but not all) actualSets recorded, it's normal mode.
  /// Otherwise, it's treated as bulk mode (all or nothing).
  ///
  /// @param training The TrainingModel representing the workout to start
  /// @return void
  void _startWorkout(TrainingModel training) {
    // If workout is completed, open in normal mode for viewing/editing results
    if (training.isCompleted) {
      _openNormalModeWorkout(training);
      return;
    }

    // Check if user already started this workout
    final hasStarted = training.exercises.any((e) => e.actualSets.isNotEmpty);

    if (hasStarted) {
      // Workout in progress - detect which mode was being used
      // by checking for partial set completion (normal mode indicator)
      final isNormalMode = training.exercises.any((exercise) {
        final completedSets = exercise.actualSets.length;
        return completedSets > 0 && completedSets < exercise.sets;
      });

      // Resume workout in the detected mode
      if (isNormalMode) {
        _openNormalModeWorkout(training);
      } else {
        _openBulkModeWorkout(training);
      }
      return;
    }

    // New workout - open based on user's saved preference
    if (_workoutMode == 'normal') {
      _openNormalModeWorkout(training);
    } else {
      _openBulkModeWorkout(training);
    }
  }

  /// @brief Opens a workout in normal mode dialog (set-by-set tracking)
  /// @details Opens WorkoutSessionDialog for set-by-set exercise tracking.
  /// This dialog allows users to log reps and weight for each set individually.
  /// When the user completes the workout, the onWorkoutUpdated callback:
  /// 1. Persists the updated training to TrainingService
  /// 2. Updates the local _trainings cache
  /// 3. Automatically triggers UI rebuild with new progress
  ///
  /// barrrierDismissible is false to prevent accidental dialog closure.
  /// The dialog blocks user interaction with the rest of the app.
  ///
  /// @param training The TrainingModel to display in normal mode
  /// @return void
  void _openNormalModeWorkout(TrainingModel training) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkoutSessionDialog(
        training: training,
        onWorkoutUpdated: (updatedTraining) async {
          // Persist updated training to service
          await _trainingService.updateTraining(updatedTraining);
          // Update local cache and rebuild UI
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

  /// @brief Opens a workout in bulk mode dialog (all sets at once)
  /// @details Opens BulkWorkoutDialog for entering all reps and weight values
  /// at once. This is faster for users who know their target numbers.
  /// When the user completes the workout, the onWorkoutUpdated callback:
  /// 1. Persists the updated training to TrainingService
  /// 2. Updates the local _trainings cache
  /// 3. Automatically triggers UI rebuild with new progress
  ///
  /// barrrierDismissible is false to prevent accidental dialog closure.
  /// The dialog blocks user interaction with the rest of the app.
  ///
  /// @param training The TrainingModel to display in bulk mode
  /// @return void
  void _openBulkModeWorkout(TrainingModel training) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BulkWorkoutDialog(
        training: training,
        onWorkoutUpdated: (updatedTraining) async {
          // Persist updated training to service
          await _trainingService.updateTraining(updatedTraining);
          // Update local cache and rebuild UI
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

  /// @brief Builds the main dashboard UI
  /// @details Constructs the complete dashboard scaffold with:
  /// 1. AppBar with user greeting, refresh/notifications/settings/logout buttons
  /// 2. TabBar with three tabs: Progress, Workouts, Nutrition
  /// 3. TabBarView showing appropriate content for each tab
  ///
  /// Shows loading spinner while data is being fetched. Once loaded, displays
  /// the TabBarView with three main sections:
  /// - _buildProgressTab(): Weight, measurements, steps, and goals
  /// - _buildWorkoutsTab(): List of assigned workouts with execution controls
  /// - _buildNutritionTab(): Calorie and meal plan tracking
  ///
  /// Uses Provider to watch for authentication state changes.
  /// Automatically rebuilds when currentUser changes.
  ///
  /// @return Widget The main scaffold containing all dashboard content
  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${lang.translate('trainee_dashboard')} - ${currentUser?.name ?? 'User'}'),
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
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
          const LanguageSwitcher(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.analytics), text: lang.translate('progress')),
            Tab(icon: const Icon(Icons.fitness_center), text: lang.translate('workouts')),
            Tab(icon: const Icon(Icons.restaurant), text: lang.translate('nutrition')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProgressTab(),
                _buildWorkoutsTab(),
                _buildNutritionTab(),
              ],
            ),
    );
  }

  /// @brief Builds the Workouts tab UI
  /// @details Displays all assigned workouts in a scrollable list with:
  /// 1. Debug information card showing user ID and loaded workout count
  /// 2. Manual refresh button for troubleshooting data loading
  /// 3. List of workout cards (or empty state if no workouts assigned)
  ///
  /// Each workout card is an ExpansionTile showing:
  /// - Workout name, description, difficulty, scheduled date
  /// - Status indicator (pending/in progress/completed)
  /// - Expandable exercise list with target sets/reps and actual results
  /// - Action buttons (Start, Continue, or Edit Results based on state)
  ///
  /// Workout states are color-coded:
  /// - Blue circle: Not started
  /// - Orange circle: In progress (has actual sets logged)
  /// - Green circle: Completed
  ///
  /// Users can click "Start Workout" to open either WorkoutSessionDialog
  /// (normal mode) or BulkWorkoutDialog (bulk mode) based on preference.
  ///
  /// @return Widget The complete workouts tab content
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

  /// @brief Builds a single workout card widget
  /// @details Creates an expandable card (ExpansionTile) for one training session.
  /// The card shows:
  /// 1. Leading: Status icon (blue/orange/green circle)
  /// 2. Title: Workout name with strike-through if completed
  /// 3. Status badge: "COMPLETED" or "IN PROGRESS" label
  /// 4. Subtitle: Description, trainee ID, scheduled date, difficulty badge, progress
  /// 5. Expanded content: Detailed exercise list with actual results and action buttons
  ///
  /// Color coding for status:
  /// - Blue: Not started
  /// - Orange: In progress (some sets logged)
  /// - Green: Completed
  ///
  /// Difficulty color coding:
  /// - Green: Beginner
  /// - Orange: Intermediate
  /// - Red: Advanced
  ///
  /// For in-progress workouts, shows "Progress: X/Y sets" to indicate completion.
  /// Displays actual results if any sets have been logged.
  /// Shows trainer notes if provided.
  /// Action buttons change based on state:
  /// - Not started/In progress: "Start Workout" or "Continue Workout"
  /// - Completed: "Edit Results" button
  ///
  /// @param training The TrainingModel to display
  /// @return Widget The complete workout card
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
                  final lang = context.watch<LanguageProvider>();
                  final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
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
                                  translatedName,
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
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _startWorkout(training),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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

  /// @brief Calculates and returns the workout progress as "completed/total" sets
  /// @details Iterates through all exercises in the training and counts:
  /// 1. Total target sets (exercise.sets * number of exercises)
  /// 2. Completed sets (actualSets.length for each exercise)
  /// Returns a string like "5/12 sets" for display in the UI.
  /// Used in the workout progress indicator during in-progress workouts.
  ///
  /// @param training The TrainingModel to calculate progress for
  /// @return String Formatted progress string "completed/total sets"
  String _getWorkoutProgress(TrainingModel training) {
    int totalSets = 0;
    int completedSets = 0;

    // Sum up all target sets and completed sets across all exercises
    for (final exercise in training.exercises) {
      totalSets += exercise.sets;
      completedSets += exercise.actualSets.length;
    }

    return '$completedSets/$totalSets sets';
  }

  /// @brief Returns the appropriate color for a difficulty level
  /// @details Maps difficulty string to Material colors:
  /// - 'beginner' -> Green
  /// - 'intermediate' -> Orange
  /// - 'advanced' -> Red
  /// - default -> Grey
  /// Used to color-code difficulty badges on workout cards.
  ///
  /// @param difficulty The difficulty level string
  /// @return Color The corresponding Material color
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

  /// @brief Builds the Nutrition tab UI
  /// @details Displays nutrition and calorie tracking information:
  /// 1. Daily calories card showing consumed/target ratio (1,250/2,000)
  /// 2. Progress bar for calorie intake
  /// 3. Placeholder message for nutrition tracking feature
  ///
  /// Currently shows mock data. In a complete implementation, this would integrate
  /// with NutritionService to display actual meal logs and nutritional information.
  /// @return Widget The complete nutrition tab content
  Widget _buildNutritionTab() {
    if (_nutritionPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Nutrition Plan Assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your trainer hasn\'t assigned a nutrition plan yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Get the most recent nutrition plan
    final plan = _nutritionPlans.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily Calorie Card
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange.shade700, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Caloric Target',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Assigned by your trainer',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${plan.dailyCalories}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kcal/day',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Log Food Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logFood,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Log Food Intake', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Today's Food Log Section
        if (_todayNutritionEntries.isNotEmpty) ...[
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Today\'s Food Log',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Consumed vs Target
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Consumed',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      Text(
                        '/',
                        style: TextStyle(fontSize: 32, color: Colors.grey.shade400),
                      ),
                      Column(
                        children: [
                          Text(
                            '${plan.dailyCalories}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            'Target',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar
                  LinearProgressIndicator(
                    value: (_todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories) / plan.dailyCalories).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories) <= plan.dailyCalories
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories) <= plan.dailyCalories
                        ? 'You have ${plan.dailyCalories - _todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories)} kcal remaining'
                        : 'You exceeded your target by ${_todayNutritionEntries.fold(0, (sum, entry) => sum + entry.totalCalories) - plan.dailyCalories} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Food Items List
                  const Text(
                    'Logged Food Items',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._todayNutritionEntries.expand((entry) => entry.consumedFoods.map((food) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.fastfood, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '${food.calories} kcal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ))).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Plan Info
        Row(
          children: [
            const Icon(Icons.label, size: 20),
            const SizedBox(width: 8),
            Text(
              plan.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Created: ${plan.createdAt.toString().split(' ')[0]}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Recipes Section
        Row(
          children: [
            const Icon(Icons.restaurant_menu, size: 20),
            const SizedBox(width: 8),
            Text(
              'Recipe Ideas (${plan.recipes.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Recipe Cards
        ...plan.recipes.map((recipe) {
          final lang = context.watch<LanguageProvider>();
          final translatedRecipeName = LocalizationService.translateRecipeName(recipe.name, lang.currentLanguage);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showRecipeDetails(recipe),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.restaurant, color: Colors.orange.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translatedRecipeName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text('${recipe.calories} kcal', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 20),
                        Icon(Icons.timer, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text('${recipe.prepTimeMinutes} min', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 20),
                        Icon(Icons.list_alt, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text('${recipe.ingredients.length} ingredients', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// @brief Opens the food logging dialog for trainees
  /// @details Allows trainees to log multiple food items with calorie counts for today
  void _logFood() {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FoodLogDialog(
        traineeId: currentUser.id,
        date: DateTime.now(),
        onFoodLogged: _loadData,
      ),
    );
  }

  /// @brief Shows detailed recipe information in a dialog
  /// @details Displays ingredients, instructions, calories, and prep time
  /// @param recipe The recipe to display
  void _showRecipeDetails(RecipeModel recipe) {
    final lang = context.watch<LanguageProvider>();
    final translatedRecipeName = LocalizationService.translateRecipeName(recipe.name, lang.currentLanguage);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        translatedRecipeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.description,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 20),

                      // Nutrition Info
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.local_fire_department, color: Colors.orange.shade700),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${recipe.calories}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('calories', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.timer, color: Colors.blue.shade700),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${recipe.prepTimeMinutes}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('minutes', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ingredients
                      const Text(
                        'Ingredients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...recipe.ingredients.map((ingredient) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(child: Text(ingredient, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 24),

                      // Instructions
                      const Text(
                        'Instructions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...recipe.instructions.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  /// @brief Builds the Progress tab UI
  /// @details Displays comprehensive progress tracking with multiple sections:
  /// 1. Weight goals (if assigned)
  /// 2. Weight tracking card with history table and weekly averages
  /// 3. Performance goals (if assigned)
  /// 4. Daily steps card with manual entry and progress indicator
  /// 5. Measurement goals (if assigned)
  /// 6. Body measurements card with history table and weekly averages
  /// 7. Progress pictures card for transformation photos
  ///
  /// Each section can be expanded to show full history. Weekly averages
  /// are calculated automatically from recent entries. Users can manually
  /// log weight, steps, and body measurements if desired.
  ///
  /// @return Widget The complete progress tab content
  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weight Goal (if assigned by trainer)
          ..._buildWeightGoals(),

          // Weight tracking card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monitor_weight, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Weight Progress',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showWeightDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_measurements.isNotEmpty) ...[
                    Text(
                      'Current Weight: ${_measurements.first.weight.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: ${_formatDate(_measurements.first.date)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ] else ...[
                    const Text(
                      'No weight logged yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Click "Log" to add your first weight entry',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Weight history table
                  if (_measurements.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Weight History',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildWeightHistoryTable(),
                    if (_measurements.length > 3) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllWeights = !_showAllWeights;
                            });
                          },
                          icon: Icon(
                            _showAllWeights ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                          label: Text(_showAllWeights ? 'Show less' : 'See more'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                    // Weekly average
                    if (_calculateWeeklyAverage() != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Weekly Average',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_calculateWeeklyAverage()!['average'].toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              Text(
                                '${_calculateWeeklyAverage()!['count']} entries this week',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Performance Goals (if assigned)
          ..._buildPerformanceGoals(),

          // Daily Steps card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_walk, color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Daily Steps',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_isLoadingSteps)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadStepsData,
                          tooltip: 'Refresh steps',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_todaySteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      if (_isManualSteps) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Manual',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Goal: 10,000 steps', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (_todaySteps / 10000).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _todaySteps >= 10000
                        ? 'Goal reached! 🎉'
                        : '${(10000 - _todaySteps).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps to go',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showManualStepsDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(_isManualSteps ? 'Update Manually' : 'Log Manually'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  if (_todaySteps == 0 && !_isLoadingSteps && !_isManualSteps) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Auto-sync from Google Fit/Health Connect, or log manually',
                              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Measurement Goals (if assigned)
          ..._buildMeasurementGoals(),

          // Measurements card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, color: Colors.orange, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Body Measurements',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showMeasurementsDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_getLatestMeasurements() != null) ...[
                    _buildCurrentMeasurements(_getLatestMeasurements()!),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: ${_formatDate(_getLatestMeasurementDate()!)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ] else ...[
                    const Text(
                      'No measurements logged yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Click "Log" to add your first measurement',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Measurements history table
                  if (_getMeasurementsWithBody().isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Measurement History',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildMeasurementsHistoryTable(),
                    if (_getMeasurementsWithBody().length > 3) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllMeasurements = !_showAllMeasurements;
                            });
                          },
                          icon: Icon(
                            _showAllMeasurements ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                          label: Text(_showAllMeasurements ? 'Show less' : 'See more'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                    // Weekly average
                    if (_calculateMeasurementsWeeklyAverage() != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildMeasurementsWeeklyAverage(),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Progress Pictures card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_camera, color: Colors.purple, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Progress Pictures',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showProgressPicturesDialog,
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Monthly transformation photos', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildProgressPicturePlaceholder('Jan 2025'),
                        const SizedBox(width: 12),
                        _buildProgressPicturePlaceholder('Dec 2024'),
                        const SizedBox(width: 12),
                        _buildProgressPicturePlaceholder('Nov 2024'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPicturePlaceholder(String month) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo, color: Colors.grey[600], size: 40),
          const SizedBox(height: 4),
          Text(
            month,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  /// @brief Shows dialog for logging today's weight
  /// @details Displays an AlertDialog for weight entry with:
  /// - Decimal number input field (supports .1 precision)
  /// - Checks if today's measurement exists (shows "Update" vs "Save")
  /// - Validates input (checks for empty, non-numeric, or zero/negative values)
  /// - Shows informational banner if updating existing entry
  /// - Calls MeasurementService to persist the weight entry
  /// - Reloads all measurements via _loadMeasurementsForTrainee()
  /// - Shows success snackbar after saving
  ///
  /// Users can only log one weight measurement per day. Multiple entries
  /// for the same day are treated as updates to the existing entry.
  /// Weight is measured in kilograms (kg).
  ///
  /// @return void (but shows dialog)
  void _showWeightDialog() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    // Check if user already logged weight today (for update vs. create)
    final todayMeasurement = await _measurementService.getTodayMeasurement(currentUser.id);
    final isUpdating = todayMeasurement != null;

    final weightController = TextEditingController(
      text: isUpdating ? todayMeasurement.weight.toStringAsFixed(1) : '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdating ? 'Update Today\'s Weight' : 'Log Weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isUpdating
              ? 'Update your weight for today:'
              : 'Enter your current weight:'),
            const SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),
            if (isUpdating) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can only log one weight per day',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final weightText = weightController.text.trim();
              if (weightText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a weight')),
                );
                return;
              }

              final weight = double.tryParse(weightText);
              if (weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid weight')),
                );
                return;
              }

              if (currentUser != null) {
                await _measurementService.addMeasurement(
                  traineeId: currentUser.id,
                  weight: weight,
                );

                // Reload measurements
                final measurements = await _measurementService.getMeasurementsForTrainee(currentUser.id);
                setState(() {
                  _measurements = measurements;
                });

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Weight ${isUpdating ? 'updated' : 'logged'}: ${weight.toStringAsFixed(1)} kg')),
                  );
                }
              }
            },
            child: Text(isUpdating ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  /// @brief Shows dialog for logging body measurements
  /// @details Displays an AlertDialog for logging body dimensions with:
  /// - Text input fields for: waist, chest, arms, hips (all in cm)
  /// - Decimal number input support
  /// - Checks if today's measurements exist (shows "Update" vs "Save")
  /// - Validates inputs (checks for empty, non-numeric, or zero/negative values)
  /// - Shows informational banner if updating existing entry
  /// - Pre-populates fields if measurements already exist for today
  /// - Requires at least one measurement to be entered
  /// - Calls MeasurementService to persist the measurements
  /// - Reloads all measurements after saving
  /// - Shows success snackbar after saving
  ///
  /// All measurements are in centimeters (cm). Users can only log one
  /// set of measurements per day. Some fields can be left empty if not
  /// measured. At least one field must have a value.
  ///
  /// @return void (but shows dialog)
  void _showMeasurementsDialog() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    // Check if user already logged measurements today (for update vs. create)
    final todayMeasurement = await _measurementService.getTodayMeasurement(currentUser.id);
    final isUpdating = todayMeasurement != null && todayMeasurement.bodyMeasurements.isNotEmpty;

    final waistController = TextEditingController(
      text: isUpdating && todayMeasurement.bodyMeasurements.containsKey('waist')
          ? todayMeasurement.bodyMeasurements['waist']!.toStringAsFixed(1)
          : '',
    );
    final chestController = TextEditingController(
      text: isUpdating && todayMeasurement.bodyMeasurements.containsKey('chest')
          ? todayMeasurement.bodyMeasurements['chest']!.toStringAsFixed(1)
          : '',
    );
    final armsController = TextEditingController(
      text: isUpdating && todayMeasurement.bodyMeasurements.containsKey('arms')
          ? todayMeasurement.bodyMeasurements['arms']!.toStringAsFixed(1)
          : '',
    );
    final hipsController = TextEditingController(
      text: isUpdating && todayMeasurement.bodyMeasurements.containsKey('hips')
          ? todayMeasurement.bodyMeasurements['hips']!.toStringAsFixed(1)
          : '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdating ? 'Update Today\'s Measurements' : 'Log Body Measurements'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: waistController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Waist (cm)',
                  border: OutlineInputBorder(),
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chestController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Chest (cm)',
                  border: OutlineInputBorder(),
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: armsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Arms (cm)',
                  border: OutlineInputBorder(),
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hipsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hips (cm)',
                  border: OutlineInputBorder(),
                  suffixText: 'cm',
                ),
              ),
              if (isUpdating) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can only log one set of measurements per day',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final bodyMeasurements = <String, double>{};

              if (waistController.text.isNotEmpty) {
                final waist = double.tryParse(waistController.text.trim());
                if (waist != null && waist > 0) {
                  bodyMeasurements['waist'] = waist;
                }
              }

              if (chestController.text.isNotEmpty) {
                final chest = double.tryParse(chestController.text.trim());
                if (chest != null && chest > 0) {
                  bodyMeasurements['chest'] = chest;
                }
              }

              if (armsController.text.isNotEmpty) {
                final arms = double.tryParse(armsController.text.trim());
                if (arms != null && arms > 0) {
                  bodyMeasurements['arms'] = arms;
                }
              }

              if (hipsController.text.isNotEmpty) {
                final hips = double.tryParse(hipsController.text.trim());
                if (hips != null && hips > 0) {
                  bodyMeasurements['hips'] = hips;
                }
              }

              if (bodyMeasurements.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter at least one measurement')),
                );
                return;
              }

              if (currentUser != null) {
                // Get the latest weight or use 0 as placeholder
                final latestWeight = await _measurementService.getLatestWeight(currentUser.id) ?? 0;

                await _measurementService.addMeasurement(
                  traineeId: currentUser.id,
                  weight: latestWeight,
                  bodyMeasurements: bodyMeasurements,
                );

                // Reload measurements
                final measurements = await _measurementService.getMeasurementsForTrainee(currentUser.id);
                setState(() {
                  _measurements = measurements;
                });

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Measurements ${isUpdating ? 'updated' : 'logged'} successfully!')),
                  );
                }
              }
            },
            child: Text(isUpdating ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showProgressPicturesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Progress Picture'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Take or upload a progress photo'),
            SizedBox(height: 8),
            Text(
              'Monthly photos help track your transformation!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement camera/gallery picker
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo feature coming soon!')),
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
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

  /// @brief Shows notifications dialog
  /// @details Displays a list of recent notifications to the user:
  /// - New workout assignments
  /// - Meal plan updates
  /// - Goal progress alerts
  ///
  /// Currently shows placeholder notifications. In a complete implementation,
  /// this would display actual notifications from a notification service.
  ///
  /// @return void (but shows dialog)
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

  /// @brief Shows settings and preferences dialog
  /// @details Displays user settings with:
  /// 1. Workout mode selection (Normal vs. Bulk)
  ///    - Normal: Track each set individually with more granular control
  ///    - Bulk: Enter all reps and weights at once for faster logging
  /// 2. Information about how preferences apply to future workouts
  /// 3. Ability to change preference and see immediate confirmation
  ///
  /// The selected mode is persisted to SharedPreferences and automatically
  /// applied to all new workouts the user starts. Existing in-progress
  /// workouts keep their original mode.
  ///
  /// @return void (but shows dialog)
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: Colors.blue),
            const SizedBox(width: 12),
            const Text('Settings & Preferences'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workout Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Workout mode selection (Normal vs Bulk)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Normal mode: set-by-set tracking
                    RadioListTile<String>(
                      title: const Text('Normal Mode'),
                      subtitle: const Text('Track each set individually'),
                      value: 'normal',
                      groupValue: _workoutMode,
                      onChanged: (value) async {
                        if (value != null) {
                          await _saveWorkoutModePreference(value);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Workout mode set to Normal'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    // Bulk mode: all at once
                    RadioListTile<String>(
                      title: const Text('Bulk Mode'),
                      subtitle: const Text('Enter all reps and weight at once'),
                      value: 'bulk',
                      groupValue: _workoutMode,
                      onChanged: (value) async {
                        if (value != null) {
                          await _saveWorkoutModePreference(value);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Workout mode set to Bulk'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Info banner about preference persistence
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your workout mode preference will be applied to all workouts',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// @brief Shows logout confirmation dialog
  /// @details Displays a confirmation dialog asking the user to confirm logout.
  /// If confirmed:
  /// 1. Calls AuthProvider.logout() to clear authentication state
  /// 2. Navigates to login page using go_router
  /// 3. Clears all cached data
  ///
  /// @return void (but shows dialog)
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

  /// @brief Formats a DateTime for user-friendly display
  /// @details Returns human-readable date strings:
  /// - "Today" for today's date
  /// - "Yesterday" for yesterday's date
  /// - "YYYY-MM-DD" format for all other dates
  ///
  /// Used in history tables and measurement displays to make dates
  /// more readable than raw DateTime objects.
  ///
  /// @param date The DateTime to format
  /// @return String Formatted date string
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    // Return friendly labels for recent dates
    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      // Return formatted date for all other dates
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// @brief Calculates the weekly average weight
  /// @details Filters measurements to current week (Monday-Sunday) and calculates:
  /// 1. Average weight across all measurements this week
  /// 2. Count of measurements taken this week
  ///
  /// Returns null if no measurements exist or no measurements this week.
  /// Week is defined as Monday (weekday 1) through Sunday (weekday 7).
  /// Used to display "Weekly Average" stat in progress tab.
  ///
  /// @return Map<String, dynamic>? Map with 'average' and 'count' keys, or null
  Map<String, dynamic>? _calculateWeeklyAverage() {
    if (_measurements.isEmpty) return null;

    final now = DateTime.now();
    // Get the start of the current week (Monday is day 1)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    // Filter measurements from this week (current 7-day period starting Monday)
    final weekMeasurements = _measurements.where((m) {
      final measurementDate = DateTime(m.date.year, m.date.month, m.date.day);
      return measurementDate.isAfter(startOfWeekDate.subtract(const Duration(days: 1))) &&
             measurementDate.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    if (weekMeasurements.isEmpty) return null;

    // Calculate average weight from week's measurements
    final totalWeight = weekMeasurements.fold<double>(0, (sum, m) => sum + m.weight);
    final average = totalWeight / weekMeasurements.length;

    return {
      'average': average,
      'count': weekMeasurements.length,
    };
  }

  /// @brief Builds a formatted weight history table widget
  /// @details Creates a data table showing weight entries with:
  /// 1. Table header with Date and Weight columns
  /// 2. Rows for each weight entry (limited to 3 or all based on _showAllWeights)
  /// 3. Date and time stamps for each entry
  /// 4. Weight delta (change from previous measurement) with color coding
  ///    - Green: Weight decreased (positive progress)
  ///    - Red: Weight increased
  /// 5. Custom styling with borders and hover effects
  ///
  /// Used in the Progress tab to display weight tracking history.
  /// Measurements are displayed in reverse chronological order (newest first).
  ///
  /// @return Widget The formatted weight history table
  Widget _buildWeightHistoryTable() {
    // Show all entries or just the 3 most recent based on _showAllWeights flag
    final displayedMeasurements = _showAllWeights
        ? _measurements
        : _measurements.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Weight',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...displayedMeasurements.asMap().entries.map((entry) {
            final index = entry.key;
            final measurement = entry.value;
            final isLast = index == displayedMeasurements.length - 1;

            // Calculate delta (compare with previous/older weight in the full list)
            double? delta;
            final fullListIndex = _measurements.indexOf(measurement);
            if (fullListIndex < _measurements.length - 1) {
              final previousWeight = _measurements[fullListIndex + 1].weight;
              delta = measurement.weight - previousWeight;
            }

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(measurement.date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${measurement.date.hour.toString().padLeft(2, '0')}:${measurement.date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${measurement.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (delta != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: delta > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// @brief Gets all measurements that have body dimension data
  /// @details Filters the measurements list to return only entries that have
  /// body measurements (waist, chest, arms, hips). Excludes weight-only entries.
  /// Used to populate the body measurements section in the Progress tab.
  ///
  /// @return List<MeasurementModel> List of measurements with non-empty bodyMeasurements
  List<MeasurementModel> _getMeasurementsWithBody() {
    return _measurements.where((m) => m.bodyMeasurements.isNotEmpty).toList();
  }

  /// @brief Gets the most recent body measurements
  /// @details Returns the body measurements map from the most recent entry
  /// that contains body measurement data (waist, chest, arms, hips).
  /// Returns null if no body measurements have been logged.
  ///
  /// @return Map<String, double>? Map of measurement name to value in cm, or null
  Map<String, double>? _getLatestMeasurements() {
    final measurementsWithBody = _getMeasurementsWithBody();
    if (measurementsWithBody.isEmpty) return null;
    return measurementsWithBody.first.bodyMeasurements;
  }

  /// @brief Gets the date of the most recent body measurements
  /// @details Returns the timestamp of the most recent entry that contains
  /// body measurement data. Returns null if no body measurements exist.
  /// Used to display "Last updated" text in measurements section.
  ///
  /// @return DateTime? The date of latest measurements, or null
  DateTime? _getLatestMeasurementDate() {
    final measurementsWithBody = _getMeasurementsWithBody();
    if (measurementsWithBody.isEmpty) return null;
    return measurementsWithBody.first.date;
  }

  /// @brief Builds a display for current body measurements
  /// @details Creates a Wrap widget showing measurement values in a 2-column grid:
  /// 1. Measurement name (capitalized): "Waist", "Chest", "Arms", "Hips"
  /// 2. Value with "cm" unit suffix
  /// 3. Bold font for values to make them stand out
  ///
  /// Used to display the most recent body measurements in the Progress tab.
  /// Measurements are arranged in a responsive grid that wraps on smaller screens.
  ///
  /// @param measurements Map of measurement names to values in cm
  /// @return Widget Display of current measurements
  Widget _buildCurrentMeasurements(Map<String, double> measurements) {
    final entries = measurements.entries.toList();
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: entries.map((entry) {
        // Capitalize first letter of measurement name
        final label = entry.key[0].toUpperCase() + entry.key.substring(1);
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${entry.value.toStringAsFixed(1)} cm',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMeasurementsHistoryTable() {
    final measurementsWithBody = _getMeasurementsWithBody();
    final displayedMeasurements = _showAllMeasurements
        ? measurementsWithBody
        : measurementsWithBody.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Measurements',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...displayedMeasurements.asMap().entries.map((entry) {
            final index = entry.key;
            final measurement = entry.value;
            final isLast = index == displayedMeasurements.length - 1;

            // Calculate deltas
            Map<String, double>? deltas;
            final fullListIndex = measurementsWithBody.indexOf(measurement);
            if (fullListIndex < measurementsWithBody.length - 1) {
              final previousMeasurement = measurementsWithBody[fullListIndex + 1];
              deltas = {};
              for (var key in measurement.bodyMeasurements.keys) {
                if (previousMeasurement.bodyMeasurements.containsKey(key)) {
                  deltas[key] = measurement.bodyMeasurements[key]! -
                               previousMeasurement.bodyMeasurements[key]!;
                }
              }
            }

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(measurement.date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${measurement.date.hour.toString().padLeft(2, '0')}:${measurement.date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: measurement.bodyMeasurements.entries.map((e) {
                        final label = e.key[0].toUpperCase() + e.key.substring(1);
                        final delta = deltas?[e.key];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$label: ',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                '${e.value.toStringAsFixed(1)} cm',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              if (delta != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: delta > 0 ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Map<String, dynamic>? _calculateMeasurementsWeeklyAverage() {
    final measurementsWithBody = _getMeasurementsWithBody();
    if (measurementsWithBody.isEmpty) return null;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final weekMeasurements = measurementsWithBody.where((m) {
      final measurementDate = DateTime(m.date.year, m.date.month, m.date.day);
      return measurementDate.isAfter(startOfWeekDate.subtract(const Duration(days: 1))) &&
             measurementDate.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    if (weekMeasurements.isEmpty) return null;

    // Calculate averages for each measurement type
    final averages = <String, double>{};
    final counts = <String, int>{};

    for (var measurement in weekMeasurements) {
      for (var entry in measurement.bodyMeasurements.entries) {
        averages[entry.key] = (averages[entry.key] ?? 0) + entry.value;
        counts[entry.key] = (counts[entry.key] ?? 0) + 1;
      }
    }

    for (var key in averages.keys) {
      averages[key] = averages[key]! / counts[key]!;
    }

    return {
      'averages': averages,
      'count': weekMeasurements.length,
    };
  }

  Widget _buildMeasurementsWeeklyAverage() {
    final weeklyData = _calculateMeasurementsWeeklyAverage();
    if (weeklyData == null) return const SizedBox.shrink();

    final averages = weeklyData['averages'] as Map<String, double>;
    final count = weeklyData['count'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Weekly Average',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: averages.entries.map((entry) {
            final label = entry.key[0].toUpperCase() + entry.key.substring(1);
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 80) / 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$label:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(1)} cm',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '$count entries this week',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWeightGoals() {
    final weightGoals = _goals.where((g) => g.type == GoalType.weight).toList();
    if (weightGoals.isEmpty) return [];

    return weightGoals.map((goal) {
      final progress = goal.progressPercentage;
      final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;

      return Column(
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Weight',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              goal.name,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: goal.isCompleted ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          goal.isCompleted ? 'Completed' : 'In Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.currentValue.toStringAsFixed(1)} ${goal.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Target',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.toStringAsFixed(1)}% complete',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        daysRemaining > 0
                            ? '$daysRemaining days left'
                            : 'Overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysRemaining > 0 ? Colors.grey.shade700 : Colors.red,
                          fontWeight: daysRemaining > 0 ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  List<Widget> _buildMeasurementGoals() {
    final measurementGoals = _goals.where((g) => g.type == GoalType.measurement).toList();
    if (measurementGoals.isEmpty) return [];

    return measurementGoals.map((goal) {
      final progress = goal.progressPercentage;
      final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;

      return Column(
        children: [
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Measurement',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              goal.name,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: goal.isCompleted ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          goal.isCompleted ? 'Completed' : 'In Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.currentValue.toStringAsFixed(1)} ${goal.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Target',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.toStringAsFixed(1)}% complete',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        daysRemaining > 0
                            ? '$daysRemaining days left'
                            : 'Overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysRemaining > 0 ? Colors.grey.shade700 : Colors.red,
                          fontWeight: daysRemaining > 0 ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  List<Widget> _buildPerformanceGoals() {
    final performanceGoals = _goals.where((g) => g.type == GoalType.performance).toList();
    if (performanceGoals.isEmpty) return [];

    return performanceGoals.map((goal) {
      final progress = goal.progressPercentage;
      final daysRemaining = goal.deadline.difference(DateTime.now()).inDays;

      return Column(
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Daily Steps',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              goal.name,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: goal.isCompleted ? Colors.green.shade700 : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          goal.isCompleted ? 'Completed' : 'In Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.currentValue.toStringAsFixed(1)} ${goal.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Target',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted ? Colors.green.shade700 : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.toStringAsFixed(1)}% complete',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        daysRemaining > 0
                            ? '$daysRemaining days left'
                            : 'Overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysRemaining > 0 ? Colors.grey.shade700 : Colors.red,
                          fontWeight: daysRemaining > 0 ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }
}