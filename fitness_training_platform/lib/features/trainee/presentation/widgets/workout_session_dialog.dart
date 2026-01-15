/// @file workout_session_dialog.dart
/// @brief Stateful dialog widget for real-time workout session management and exercise tracking
/// @details This file implements the core workout execution interface that allows trainees to
/// perform assigned workouts, track exercise performance, and record actual sets with reps and weight.
/// The dialog manages the complete workout session lifecycle including rest periods between sets,
/// progress tracking, result editing, and history recording. It integrates with ExerciseHistoryService
/// to save completed workout data for progress analysis and tracking.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../shared/models/training_model.dart';
import '../../../workout/data/exercise_model.dart';
import '../../../../shared/services/exercise_history_service.dart';
import '../../../../shared/services/localization_service.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @class WorkoutSessionDialog
/// @brief Stateful widget wrapper for workout session execution dialog
/// @details Creates a dialog environment for trainees to complete assigned workouts in real-time.
/// Manages state transitions between pre-workout, active workout, rest periods, and completion views.
/// Handles the callback communication with parent widgets when workout status changes. Supports both
/// initial workout execution and re-editing of previously completed workouts.
class WorkoutSessionDialog extends StatefulWidget {
  /// @brief The training session to be executed by the trainee
  final TrainingModel training;

  /// @brief Callback function invoked when workout data is updated
  /// @details Called whenever significant changes occur to the training data, including
  /// after each set submission, exercise completion, or full workout completion. The updated
  /// TrainingModel is passed to the callback for the parent widget to process and update state.
  final Function(TrainingModel) onWorkoutUpdated;

  /// @brief Constructor for WorkoutSessionDialog
  /// @details Creates a new workout session dialog with required training data and update callback.
  /// @param key Widget key for state management (optional)
  /// @param training The training model to be executed
  /// @param onWorkoutUpdated Callback for workout data updates
  const WorkoutSessionDialog({
    super.key,
    required this.training,
    required this.onWorkoutUpdated,
  });

  @override
  State<WorkoutSessionDialog> createState() => _WorkoutSessionDialogState();
}

/// @class _WorkoutSessionDialogState
/// @brief State class managing real-time workout session execution and progress tracking
/// @details This state class handles the complete lifecycle of a trainee's workout execution session.
/// It manages exercise progression, set completion tracking, rest period timing, data validation,
/// and integration with the exercise history service. The state maintains the working copy of exercises
/// and their actual performance data throughout the session. It also manages the UI state for showing
/// appropriate views (pre-start, active workout, rest, completion) and handling result editing.
class _WorkoutSessionDialogState extends State<WorkoutSessionDialog> {
  /// @brief Working list of exercises for this training session
  /// @details Initialized as a copy of the training's exercises to allow safe modifications.
  /// Tracks actual sets, completion status, and performance data as the trainee progresses.
  late List<ExerciseModel> _exercises;

  /// @brief Index of the currently active exercise in the exercises list
  /// @details 0-indexed position tracking which exercise the trainee is performing.
  /// Used to access the current exercise and its properties (sets, reps, weight, rest time).
  int _currentExerciseIndex = 0;

  /// @brief Index of the currently active set within the current exercise
  /// @details 0-indexed position within the current exercise. Incremented after each set
  /// submission and reset to 0 when moving to the next exercise. Used for tracking progress
  /// and determining when to trigger rest periods or exercise transitions.
  int _currentSetIndex = 0;

  /// @brief Flag indicating if the trainee is currently in a rest period
  /// @details When true, the dialog displays the rest timer view instead of exercise input.
  /// Set to true after set submission if more sets remain for the current exercise,
  /// and set to false when rest completes or is skipped.
  bool _isResting = false;

  /// @brief Countdown timer value in seconds for the current rest period
  /// @details Decrements by 1 each second during active rest period. When it reaches 0,
  /// the rest period is considered complete. Duration comes from the current exercise's
  /// restTimeSeconds property.
  int _restTimeRemaining = 0;

  /// @brief Timer object for managing rest period countdown
  /// @details A periodic timer that fires every second to decrement _restTimeRemaining.
  /// Null when no rest period is active. Must be explicitly cancelled to prevent memory leaks.
  Timer? _restTimer;

  /// @brief Exercise history service instance for saving completed workout data
  /// @details Retrieved from dependency injection container. Used to persist exercise history
  /// when workout completion is finalized, enabling progress tracking and analysis.
  final ExerciseHistoryService _historyService = sl.get<ExerciseHistoryService>();

  /// @brief Text controller for capturing reps input in current set
  /// @details Accepts numeric input from the user for the number of repetitions completed
  /// in the current set. Cleared after each set submission.
  final _repsController = TextEditingController();

  /// @brief Text controller for capturing weight input in current set
  /// @details Accepts numeric input (supports decimals) for the weight in kg used
  /// in the current set. Cleared after each set submission.
  final _kgController = TextEditingController();

  /// @brief Map of text controllers for editing reps in completed sets
  /// @details Keyed by exercise ID, contains lists of controllers for each set of that exercise.
  /// Initialized in _initializeEditControllers() and used only in edit mode for result refinement.
  Map<String, List<TextEditingController>> _editRepsControllers = {};

  /// @brief Map of text controllers for editing weight in completed sets
  /// @details Keyed by exercise ID, contains lists of controllers for each set of that exercise.
  /// Initialized in _initializeEditControllers() and used only in edit mode for result refinement.
  Map<String, List<TextEditingController>> _editKgControllers = {};

  /// @brief Flag indicating if the trainee has started the workout
  /// @details When false, displays the pre-start view with workout summary and start button.
  /// When true, displays either the active workout view or the completion view based on
  /// _workoutCompleted status.
  bool _workoutStarted = false;

  /// @brief Flag indicating if all exercises in the workout have been completed
  /// @details When true, displays the completion/results view showing all exercises and
  /// their recorded sets. Allows trainees to review results before final submission.
  bool _workoutCompleted = false;

  /// @brief Flag indicating if the trainee is currently editing workout results
  /// @details When true, the completion view switches to edit mode with TextFields
  /// for modifying reps and weight values for each set. When false, displays read-only results.
  bool _isEditingResults = false;

  /// @brief Initializes the state when the widget is first created
  /// @details Called once when the state object is first created. Performs critical setup:
  /// 1. Creates a working copy of exercises from the training model
  /// 2. Initializes text controllers for result editing
  /// 3. Loads any previously saved progress or workout data
  /// This ensures trainees can resume incomplete workouts from where they left off.
  @override
  void initState() {
    super.initState();
    // Create a working copy to avoid modifying the original training data
    _exercises = List.from(widget.training.exercises);
    // Initialize edit controllers for each exercise's sets
    _initializeEditControllers();
    // Load previous progress if this workout was partially completed or needs re-editing
    _loadExistingData();
  }

  /// @brief Cleans up resources when the state is disposed
  /// @details Called when the widget is removed from the widget tree. Performs cleanup:
  /// 1. Cancels the rest timer if it's running
  /// 2. Disposes current set input controllers
  /// 3. Disposes all edit mode controllers
  /// This prevents memory leaks and timer callbacks executing after widget destruction.
  @override
  void dispose() {
    _restTimer?.cancel();
    _repsController.dispose();
    _kgController.dispose();
    _disposeEditControllers();
    super.dispose();
  }

  /// @brief Initializes text controllers for editing completed set results
  /// @details Creates TextEditingController pairs (reps and kg) for each set of each exercise.
  /// Controllers are populated with existing actual set data if available. This enables trainees
  /// to modify their recorded performance data in the completion view's edit mode. Controllers are
  /// stored in maps keyed by exercise ID, with each map containing a list of controllers for each set.
  /// Called during initState and whenever actualSets count changes during the workout.
  void _initializeEditControllers() {
    // Iterate through all exercises to set up controllers
    for (int i = 0; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      final exerciseId = exercise.id;

      // Create empty lists for this exercise's controllers
      _editRepsControllers[exerciseId] = [];
      _editKgControllers[exerciseId] = [];

      // Initialize controllers for existing sets with their current values
      // This allows editing of previously recorded performance data
      for (int j = 0; j < exercise.actualSets.length; j++) {
        _editRepsControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[j].reps.toString())
        );
        _editKgControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[j].kg.toString())
        );
      }
    }
  }

  /// @brief Updates edit controllers for a specific exercise when actualSets count changes
  /// @details Maintains synchronization between actualSets data and TextEditingController lists.
  /// Called after each set submission to ensure the controllers list matches the actualSets list.
  /// Adds new controllers if sets were added, or removes and disposes controllers if sets were removed.
  /// This is critical for preventing index out of bounds errors when editing results.
  /// @param exerciseIndex Index of the exercise in the _exercises list to sync
  void _updateEditControllersForExercise(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final exerciseId = exercise.id;
    // Get current counts of actual sets vs. controllers
    final currentActualSets = exercise.actualSets.length;
    final currentControllers = _editRepsControllers[exerciseId]?.length ?? 0;

    // Scale-up case: More actual sets exist than controllers
    // Add new controllers for newly recorded sets
    if (currentActualSets > currentControllers) {
      for (int i = currentControllers; i < currentActualSets; i++) {
        _editRepsControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[i].reps.toString())
        );
        _editKgControllers[exerciseId]!.add(
          TextEditingController(text: exercise.actualSets[i].kg.toString())
        );
      }
    }
    // Scale-down case: More controllers exist than actual sets
    // Remove and dispose excess controllers to prevent memory leaks
    else if (currentActualSets < currentControllers) {
      for (int i = currentActualSets; i < currentControllers; i++) {
        _editRepsControllers[exerciseId]![i].dispose();
        _editKgControllers[exerciseId]![i].dispose();
      }
      // Trim the lists to match actualSets count
      _editRepsControllers[exerciseId] = _editRepsControllers[exerciseId]!.sublist(0, currentActualSets);
      _editKgControllers[exerciseId] = _editKgControllers[exerciseId]!.sublist(0, currentActualSets);
    }
  }

  /// @brief Disposes all edit mode text controllers
  /// @details Called in dispose() to clean up all TextEditingController resources.
  /// Iterates through both reps and kg controller maps and disposes each controller
  /// to prevent memory leaks and avoid holding references to disposed controllers.
  void _disposeEditControllers() {
    // Dispose all reps controllers for all exercises
    for (final controllers in _editRepsControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    // Dispose all kg controllers for all exercises
    for (final controllers in _editKgControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  }

  /// @brief Loads any previously saved workout progress or completion state
  /// @details Called during initState to resume incomplete workouts or load completed workouts for re-editing.
  /// Checks three conditions:
  /// 1. If workout is already completed, displays completion view for potential re-editing
  /// 2. If there's partial progress (some sets completed), resumes from that point
  /// 3. If no progress, keeps workout in pre-start state
  /// This allows trainees to seamlessly continue their workouts across app sessions.
  void _loadExistingData() {
    // Case 1: Workout was previously completed - allow re-editing
    if (widget.training.isCompleted) {
      setState(() {
        _workoutStarted = true;
        _workoutCompleted = true;
      });
      return;
    }

    // Case 2: Check if there's partial progress in this workout
    bool hasExistingData = false;
    int lastCompletedExercise = 0;
    int lastCompletedSet = 0;

    // Find the last exercise with recorded sets
    for (int i = 0; i < _exercises.length; i++) {
      if (_exercises[i].actualSets.isNotEmpty) {
        hasExistingData = true;
        lastCompletedExercise = i;
        // Get count of completed sets for this exercise
        lastCompletedSet = _exercises[i].actualSets.length;
      }
    }

    // Resume from the last completed point
    if (hasExistingData) {
      setState(() {
        _workoutStarted = true;
        _currentExerciseIndex = lastCompletedExercise;
        _currentSetIndex = lastCompletedSet;

        // If all sets are completed for current exercise, automatically move to next
        // This handles the case where a trainee completed all sets and restarted
        if (_currentSetIndex >= _exercises[_currentExerciseIndex].sets) {
          if (_currentExerciseIndex < _exercises.length - 1) {
            _currentExerciseIndex++;
            _currentSetIndex = 0;
          } else {
            // All exercises completed - show completion view
            _workoutCompleted = true;
          }
        }
      });
    }
  }

  /// @brief Starts the workout session from the beginning
  /// @details Transitions from the pre-start view to the active workout view.
  /// Resets exercise and set indices to 0 to begin at the first exercise, first set.
  /// Called when the trainee clicks the "Start Workout" button in the start view.
  void _startWorkout() {
    setState(() {
      _workoutStarted = true;
      _currentExerciseIndex = 0;
      _currentSetIndex = 0;
    });
  }

  /// @brief Records a completed set with actual reps and weight
  /// @details This is the core method for ActualSet recording logic. When a trainee submits
  /// their performance data for a set:
  /// 1. Validates reps (must be > 0) and weight (must be >= 0)
  /// 2. Creates an ActualSet with the recorded data
  /// 3. Stores it in the current exercise's actualSets list at the appropriate index
  /// 4. Updates edit controllers to maintain sync
  /// 5. Clears input fields for next entry
  /// 6. Saves progress via callback
  /// 7. Determines next action: rest period, move to next exercise, or complete workout
  /// The method implements the complete set submission flow and manages state transitions.
  void _submitSet() {
    // Parse and validate user input from text controllers
    final reps = int.tryParse(_repsController.text);
    final kg = double.tryParse(_kgController.text);

    // Validation: ensure both values are valid and within acceptable ranges
    if (reps == null || kg == null || reps <= 0 || kg < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid reps and weight')),
      );
      return;
    }

    // Create an ActualSet object with the recorded performance data
    // This encapsulates the set's actual reps and weight as performed by the trainee
    final newSet = ActualSet(reps: reps, kg: kg);
    final updatedSets = List<ActualSet>.from(_exercises[_currentExerciseIndex].actualSets);

    // Add or update the set in the actualSets list
    // If this is a new set (length <= index), append it; otherwise, update the existing set
    if (updatedSets.length <= _currentSetIndex) {
      updatedSets.add(newSet);
    } else {
      updatedSets[_currentSetIndex] = newSet;
    }

    // Update the current exercise with the new actualSets using the immutable pattern
    _exercises[_currentExerciseIndex] = _exercises[_currentExerciseIndex].copyWith(
      actualSets: updatedSets,
    );

    // Synchronize edit controllers with the updated actualSets
    // Prevents index mismatches when editing results later
    _updateEditControllersForExercise(_currentExerciseIndex);

    // Clear input fields for the next set
    _repsController.clear();
    _kgController.clear();

    // Notify parent widget of progress via callback
    _saveProgress();

    // Determine the next action after set submission
    // Check if this was the last set of the current exercise
    if (_currentSetIndex + 1 >= _exercises[_currentExerciseIndex].sets) {
      // All sets for this exercise are complete
      if (_currentExerciseIndex + 1 >= _exercises.length) {
        // All exercises complete - finish the workout
        _completeWorkout();
      } else {
        // More exercises remain - move to the next exercise
        _moveToNextExercise();
      }
    } else {
      // More sets remain for current exercise - start rest period
      _startRestPeriod();
    }
  }

  /// @brief Initiates a rest period between sets
  /// @details After a set is completed, a rest period countdown begins. This method:
  /// 1. Sets rest period active flag and increments set index
  /// 2. Initializes rest timer with duration from exercise's restTimeSeconds
  /// 3. Starts a periodic timer that decrements every second
  /// 4. Updates UI state to show the rest timer view
  /// 5. Automatically disables the rest period when countdown reaches 0 or widget is unmounted
  /// The trainee can skip rest early using _skipRest() method.
  void _startRestPeriod() {
    setState(() {
      _isResting = true;
      _restTimeRemaining = _exercises[_currentExerciseIndex].restTimeSeconds;
      _currentSetIndex++;
    });

    // Cancel any existing timer to prevent multiple timers running simultaneously
    _restTimer?.cancel();
    // Create a new periodic timer that fires every second
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Check if widget is still mounted before calling setState
      // Prevents "setState called after dispose" errors
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // Decrement the remaining rest time
        if (_restTimeRemaining > 0) {
          _restTimeRemaining--;
        } else {
          // Rest period complete - disable rest view
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  /// @brief Skips the remaining rest period immediately
  /// @details Called when the trainee clicks "Skip Rest" button. Cancels the timer
  /// and transitions directly to the next set input view, allowing the trainee to
  /// continue without waiting for the full rest duration.
  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restTimeRemaining = 0;
    });
  }

  /// @brief Advances to the next exercise in the training session
  /// @details Called after the current exercise is fully completed. Resets set index
  /// to 0 and increments exercise index. Cancels any active rest timer and clears
  /// the rest state to display the next exercise's input view.
  void _moveToNextExercise() {
    setState(() {
      _currentExerciseIndex++;
      _currentSetIndex = 0;
      _isResting = false;
    });
    _restTimer?.cancel();
  }

  /// @brief Saves workout progress to the parent widget
  /// @details Creates a copy of the training with updated exercises and calls the
  /// onWorkoutUpdated callback. This notifies the parent widget of progress changes,
  /// enabling features like auto-save and real-time progress synchronization.
  void _saveProgress() {
    final updatedTraining = widget.training.copyWith(exercises: _exercises);
    widget.onWorkoutUpdated(updatedTraining);
  }

  /// @brief Marks the workout as completed and prepares for result review
  /// @details Called after the last set of the last exercise is submitted. Performs
  /// final setup for the completion view: updates all edit controllers with final data,
  /// sets completion flag, clears rest state, and cancels any running timer. Transitions
  /// the UI to the completion/results view where trainees can review and optionally
  /// edit their recorded performance before final submission.
  void _completeWorkout() {
    // Update all edit controllers with final actualSets data
    // Ensures all controllers are synchronized before entering results view
    for (int i = 0; i < _exercises.length; i++) {
      _updateEditControllersForExercise(i);
    }

    setState(() {
      _workoutCompleted = true;
      _isResting = false;
    });
    _restTimer?.cancel();
  }

  /// @brief Finalizes workout completion and submits to trainer
  /// @details This is the core completion workflow method. Performs the following:
  /// 1. Creates final TrainingModel with completion timestamp and flag
  /// 2. Saves exercise history to ExerciseHistoryService for progress tracking
  /// 3. Notifies parent widget with completed training data
  /// 4. Closes the dialog
  /// 5. Shows confirmation message to trainee
  /// Handles both initial completion and re-submission after editing. The exercise history
  /// service persists the completed workout data for trainer review and progress analysis.
  /// @details Async method that saves to service before closing dialog
  void _submitCompletedWorkout() async {
    // Create final training model with completion metadata
    final completedTraining = widget.training.copyWith(
      exercises: _exercises,
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    // Save exercise history to service for progress tracking and trainer review
    // This makes the completed workout data available for progress reports
    try {
      await _historyService.saveTrainingHistory(completedTraining);
      print('✅ Exercise history saved successfully');
    } catch (e) {
      print('❌ Error saving exercise history: $e');
    }

    // Notify parent widget of completion
    widget.onWorkoutUpdated(completedTraining);
    Navigator.pop(context);

    // Show confirmation to trainee
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.training.isCompleted
            ? 'Workout updated and re-submitted to trainer!'
            : 'Workout completed and submitted to trainer!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// @brief Toggles between edit mode and view mode for results
  /// @details Simple state toggle that switches the completion view between
  /// read-only results display and editable TextFields. Allows trainees to
  /// review and correct their recorded performance data before final submission.
  void _toggleEditMode() {
    setState(() {
      _isEditingResults = !_isEditingResults;
    });
  }

  /// @brief Saves edited workout results and validates all input data
  /// @details Comprehensive result editing workflow with complete validation:
  /// 1. Validates all exercise sets for non-empty and correctly formatted data
  /// 2. Ensures reps are positive integers and weight values are non-negative
  /// 3. Shows specific error messages for each invalid field
  /// 4. Updates all exercises with corrected ActualSet data from controllers
  /// 5. Saves progress and exits edit mode
  /// The validation phase checks all data before any updates occur, preventing
  /// partial updates if validation fails. Critical for maintaining data integrity.
  void _saveEditedResults() {
    // VALIDATION PHASE: Check all inputs before making any changes
    // Iterate through all exercises and their sets to validate completeness
    for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
      final exercise = _exercises[exerciseIndex];
      final exerciseId = exercise.id;
      final repsControllers = _editRepsControllers[exerciseId]!;
      final kgControllers = _editKgControllers[exerciseId]!;

      // Validate each set of the exercise
      for (int setIndex = 0; setIndex < repsControllers.length; setIndex++) {
        final repsText = repsControllers[setIndex].text.trim();
        final kgText = kgControllers[setIndex].text.trim();

        // Get translated exercise name
        final lang = context.watch<LanguageProvider>();
        final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);

        // Check for empty fields
        if (repsText.isEmpty || kgText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please fill in all fields for $translatedName, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Validate reps is a positive integer
        final reps = int.tryParse(repsText);
        if (reps == null || reps <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a valid number of reps for $translatedName, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Validate weight is a non-negative number
        final kg = double.tryParse(kgText);
        if (kg == null || kg < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter a valid weight for $translatedName, Set ${setIndex + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // UPDATE PHASE: All validation passed, now update with validated data
    try {
      for (int exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++) {
        final exercise = _exercises[exerciseIndex];
        final exerciseId = exercise.id;
        final repsControllers = _editRepsControllers[exerciseId]!;
        final kgControllers = _editKgControllers[exerciseId]!;

        // Build updated actualSets list from validated controller values
        final updatedSets = <ActualSet>[];
        for (int setIndex = 0; setIndex < repsControllers.length; setIndex++) {
          final reps = int.parse(repsControllers[setIndex].text.trim());
          final kg = double.parse(kgControllers[setIndex].text.trim());
          updatedSets.add(ActualSet(reps: reps, kg: kg));
        }

        // Update exercise with corrected actualSets
        _exercises[exerciseIndex] = exercise.copyWith(actualSets: updatedSets);
      }

      // Save updated progress and exit edit mode
      _saveProgress();
      setState(() {
        _isEditingResults = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Catch any unexpected errors during the save process
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving changes. Please check your input values.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// @brief Builds the widget tree for the workout session dialog
  /// @details Main build method that orchestrates the complete UI based on workout state.
  /// Uses a ternary operator chain to display the appropriate view:
  /// 1. Pre-start view: Shows workout summary and "Start Workout" button
  /// 2. Active workout view: Shows exercise input, completed sets, and rest timer
  /// 3. Completion view: Shows results summary with edit capabilities
  /// The header is always displayed at the top with the workout name.
  /// @return Dialog widget containing the entire workout session interface
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            // Main content area that changes based on workout state
            Expanded(
              child: _workoutCompleted
                  ? _buildCompletionView()
                  : _workoutStarted
                      ? _buildWorkoutView()
                      : _buildStartView(),
            ),
          ],
        ),
      ),
    );
  }

  /// @brief Builds the header widget with workout title and close button
  /// @details Displays a primary-colored header bar containing the training name
  /// and a close button for dismissing the dialog. Always visible regardless of state.
  /// @return Container widget with styled header content
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.training.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the pre-workout start view
  /// @details Displays a motivational pre-start screen showing:
  /// 1. Fitness icon
  /// 2. Motivational message
  /// 3. Workout summary (number of exercises and estimated duration)
  /// 4. "Start Workout" button to begin the session
  /// This view is shown initially before any exercises are started, allowing the
  /// trainee to prepare mentally and see what they're about to do.
  /// @return Padding widget containing centered content
  Widget _buildStartView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fitness_center,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to start your workout?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Display workout summary: exercise count and estimated duration
          Text(
            '${_exercises.length} exercises • ${widget.training.estimatedDuration} min',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startWorkout,
              child: const Text('Start Workout'),
            ),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the active workout view with exercise input and progress tracking
  /// @details This is the main workout execution interface showing:
  /// 1. Progress indicator showing position in workout
  /// 2. Current exercise name and set count
  /// 3. Previously completed sets in read-only cards
  /// 4. Current set input fields for reps and weight
  /// 5. Target performance (planned reps and weight)
  /// 6. Submit button that manages transitions
  /// This view updates dynamically as the trainee records each set. It displays
  /// both the target performance and actual recorded data side by side.
  /// @return Padding widget containing the complete active workout interface
  Widget _buildWorkoutView() {
    if (_isResting) {
      return _buildRestView();
    }

    final currentExercise = _exercises[_currentExerciseIndex];
    final completedSets = currentExercise.actualSets.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentExerciseIndex + (_currentSetIndex / currentExercise.sets)) / _exercises.length,
          ),
          const SizedBox(height: 20),
          
          // Exercise info
          Text(
            currentExercise.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Set ${_currentSetIndex + 1} of ${currentExercise.sets}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),

          // Target vs completed sets
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Show completed sets
                  if (completedSets > 0) ...[
                    const Text(
                      'Completed Sets:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(completedSets, (index) {
                      final set = currentExercise.actualSets[index];
                      return Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Set ${index + 1}'),
                          subtitle: Text('${set.reps} reps × ${set.kg} kg'),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Current set input
                  const Text(
                    'Current Set:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Target: ${currentExercise.reps} reps × ${currentExercise.weight ?? 'bodyweight'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reps Completed',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _kgController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitSet,
                      child: Text(
                        _currentSetIndex + 1 >= currentExercise.sets
                            ? (_currentExerciseIndex + 1 >= _exercises.length 
                                ? 'Finish Exercise' 
                                : 'Next Exercise')
                            : 'Complete Set',
                      ),
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

  /// @brief Builds the rest period countdown view
  /// @details Displays a countdown timer between sets showing:
  /// 1. Timer icon
  /// 2. Rest period label and current set info
  /// 3. Large countdown display in MM:SS format
  /// 4. "Skip Rest" button to bypass remaining time
  /// 5. "Continue" button that activates when rest completes
  /// The timer decrements every second, automatically disabling the continue
  /// button until the rest period is fully complete. Prevents trainees from
  /// rushing their rest periods while still allowing them to skip if needed.
  /// @return Padding widget containing rest period interface
  Widget _buildRestView() {
    // Convert seconds to minutes and seconds for display
    final minutes = _restTimeRemaining ~/ 60;
    final seconds = _restTimeRemaining % 60;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer,
            size: 80,
            color: Colors.orange,
          ),
          const SizedBox(height: 20),
          const Text(
            'Rest Period',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Show current progress within the exercise
          Text(
            'Set ${_currentSetIndex} of ${_exercises[_currentExerciseIndex].sets}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 30),

          // Large countdown timer display
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),

          const SizedBox(height: 30),
          Row(
            children: [
              // Skip Rest button - always enabled
              Expanded(
                child: OutlinedButton(
                  onPressed: _skipRest,
                  child: const Text('Skip Rest'),
                ),
              ),
              const SizedBox(width: 16),
              // Continue button - only enabled when rest time is 0 or less
              Expanded(
                child: ElevatedButton(
                  onPressed: _restTimeRemaining <= 0
                      ? () {
                          setState(() {
                            _isResting = false;
                          });
                        }
                      : null,
                  child: Text(_restTimeRemaining <= 0 ? 'Continue' : 'Wait...'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// @brief Builds the workout completion view with results summary and editing
  /// @details Displays the final workout results in two modes:
  /// 1. View mode: Shows all exercises with completed sets in read-only format
  /// 2. Edit mode: Allows modifying recorded reps and weight values
  /// Includes ExpansionTiles for each exercise showing:
  /// - Exercise name and set count
  /// - Individual set results (reps × weight)
  /// - Edit/save buttons depending on mode
  /// - Submit button to finalize and send to trainer
  /// Validates all edited data before allowing save. Shows success/error messages.
  /// @return Padding widget containing the completion interface
  Widget _buildCompletionView() {
    final isReEdit = widget.training.isCompleted;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Celebration icon if new completion, edit icon if re-editing
          Icon(
            isReEdit ? Icons.edit : Icons.celebration,
            size: 80,
            color: isReEdit ? Colors.blue : Colors.green,
          ),
          const SizedBox(height: 20),
          // Title changes based on whether this is a new or re-edit completion
          Text(
            isReEdit ? 'Edit Workout Results' : 'Workout Completed!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isReEdit ? Colors.blue : Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          // Instructional text based on mode
          Text(
            isReEdit
                ? 'Edit your results and re-submit to your trainer.'
                : 'Great job! Review your results below.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),

          // Scrollable list of all exercises with their completed sets
          // Each exercise is collapsible to show detailed set results
          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, exerciseIndex) {
                final exercise = _exercises[exerciseIndex];
                final lang = context.watch<LanguageProvider>();
                final translatedName = LocalizationService.translateExerciseName(exercise.name, lang.currentLanguage);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      translatedName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Subtitle shows count of completed sets
                    subtitle: Text('${exercise.actualSets.length} sets completed'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Results:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            // Generate set result cards/fields for each completed set
                            ...exercise.actualSets.asMap().entries.map((entry) {
                              final setIndex = entry.key;
                              final set = entry.value;
                              final exerciseId = exercise.id;

                              if (_isEditingResults) {
                                // EDIT MODE: Show TextFields for modifying results
                                return Card(
                                  color: Colors.blue.shade50,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Set ${setIndex + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        // Reps and weight input fields side by side
                                        Row(
                                          children: [
                                            // Reps input field
                                            Expanded(
                                              child: TextField(
                                                controller: _editRepsControllers[exerciseId]![setIndex],
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Reps',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Weight input field
                                            Expanded(
                                              child: TextField(
                                                controller: _editKgControllers[exerciseId]![setIndex],
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(
                                                  labelText: 'Weight (kg)',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // VIEW MODE: Show read-only result cards
                                return ListTile(
                                  leading: const Icon(Icons.check_circle, color: Colors.green),
                                  title: Text('Set ${setIndex + 1}'),
                                  subtitle: Text('${set.reps} reps × ${set.kg} kg'),
                                );
                              }
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          // Bottom button section - changes based on edit mode
          _isEditingResults
              ? Column(
                  children: [
                    // Edit mode buttons: Cancel and Save Changes
                    Row(
                      children: [
                        // Cancel edit button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _toggleEditMode,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Cancel Edit',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save changes button with validation
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveEditedResults,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  // View mode buttons: Edit Results and Submit to Trainer
                  children: [
                    // Edit results button - switches to edit mode
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _toggleEditMode,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Edit Results',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Final submission button - saves history and closes dialog
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitCompletedWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isReEdit ? 'Re-Submit to Trainer' : 'Submit to Trainer',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}