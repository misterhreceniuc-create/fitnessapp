/// @file workout_mode_selection_dialog.dart
/// @brief Dialog for selecting workout execution mode in the trainee dashboard
/// @details This file contains the WorkoutModeSelectionDialog widget that allows trainees
/// to choose how they want to execute their assigned workouts. It offers two execution modes:
/// step-by-step guided mode (with rest timers between sets) and all-at-once mode
/// (self-paced exercise logging). The dialog intelligently detects previously started workouts
/// and automatically resumes the appropriate mode. It handles completed workouts and routes
/// to the appropriate dialog based on the selected or detected mode.

import 'package:flutter/material.dart';
import '../../../../shared/models/training_model.dart';
import 'workout_session_dialog.dart';
import 'bulk_workout_dialog.dart';

/// @enum WorkoutMode
/// @brief Enumerates the two available execution modes for completing workouts
/// @details Distinguishes between two distinct approaches to completing assigned workouts,
/// each with different pacing and user interaction patterns.
enum WorkoutMode {
  /// @brief Traditional guided workout with step-by-step exercise progression
  /// @details Trainee progresses through exercises sequentially with rest timers between sets.
  /// Opens WorkoutSessionDialog for detailed set-by-set tracking.
  stepByStep,

  /// @brief Flexible workout mode allowing self-paced completion of all exercises
  /// @details Trainee completes all exercises at their own pace without strict sequencing.
  /// Opens BulkWorkoutDialog for comprehensive exercise logging.
  allAtOnce,
}

/// @class WorkoutModeSelectionDialog
/// @brief Stateless dialog widget for selecting or detecting workout execution mode
/// @details Presents a modal dialog with two selectable modes for workout execution. Implements
/// intelligent state detection to automatically resume workouts that have already been started.
/// Handles three distinct scenarios: completed workouts (shows step-by-step dialog for review),
/// in-progress workouts (detects and resumes the original mode), and new workouts (shows mode
/// selection options). The dialog automatically closes and opens the appropriate execution
/// dialog based on user selection or detected state. Returns completed/updated workout data
/// to parent via onWorkoutUpdated callback.
class WorkoutModeSelectionDialog extends StatelessWidget {
  /// @brief The training/workout model to be executed
  /// @details Contains all exercise information, scheduling details, completion status,
  /// and actual workout progress (if started). Used to determine dialog behavior and
  /// detect workout state (new, in-progress, or completed).
  final TrainingModel training;

  /// @brief Callback function invoked when a workout is completed or updated
  /// @details Called with the updated TrainingModel containing logged exercise data
  /// (actualSets with reps and weights) and completion status. Used to update parent
  /// widget state with workout results.
  final Function(TrainingModel) onWorkoutUpdated;

  /// @brief Constructor for WorkoutModeSelectionDialog
  /// @details Initializes the dialog with a required training model and update callback.
  /// The training model is analyzed during build to determine appropriate UI and behavior.
  /// @param training The TrainingModel representing the workout to be executed
  /// @param onWorkoutUpdated Callback function invoked when workout is completed
  const WorkoutModeSelectionDialog({
    super.key,
    required this.training,
    required this.onWorkoutUpdated,
  });

  /// @brief Builds the dialog UI or automatically navigates based on workout state
  /// @details Implements intelligent branching logic based on the training model's state:
  /// 1. If workout is completed: opens WorkoutSessionDialog for review/editing
  /// 2. If workout is in-progress: detects which mode was being used and resumes that mode
  /// 3. If workout is new: shows mode selection dialog with two option cards
  /// The logic checks actualSets on exercises to detect progress and determine if the
  /// partial completion pattern (mixed completed/incomplete sets) indicates step-by-step mode.
  /// @return Widget Either a mode selection dialog or empty widget (when auto-navigating)
  @override
  Widget build(BuildContext context) {
    // ========== COMPLETED WORKOUT HANDLING ==========
    // If workout is already completed, show step-by-step dialog for review/editing
    if (training.isCompleted) {
      // Show dialog directly without navigation (called from parent already)
      return WorkoutSessionDialog(
        training: training,
        onWorkoutUpdated: onWorkoutUpdated,
      );
    }

    // ========== IN-PROGRESS WORKOUT DETECTION ==========
    // Check if any exercise has actualSets (indicating workout has started)
    final hasStarted = training.exercises.any((e) => e.actualSets.isNotEmpty);

    if (hasStarted) {
      // ========== MODE DETECTION LOGIC ==========
      // Determine which mode was being used by analyzing the pattern of completed sets.
      // Step-by-step mode typically has partial set completion (mix of completed and incomplete)
      // All-at-once mode typically completes all sets at once or has consistent completion pattern.
      final isStepByStep = training.exercises.any((exercise) {
        final completedSets = exercise.actualSets.length;
        // This indicates incomplete progression - characteristic of step-by-step mode
        return completedSets > 0 && completedSets < exercise.sets;
      });

      if (isStepByStep) {
        // ========== RESUME STEP-BY-STEP MODE ==========
        // Close current dialog and open step-by-step mode to continue the workout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
          _openStepByStepMode(context);
        });
        // Return empty widget since navigation happens in post-frame callback
        return const SizedBox.shrink();
      } else {
        // ========== RESUME ALL-AT-ONCE MODE ==========
        // Close current dialog and open all-at-once mode to continue the workout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
          _openAllAtOnceMode(context);
        });
        // Return empty widget since navigation happens in post-frame callback
        return const SizedBox.shrink();
      }
    }

    // ========== NEW WORKOUT MODE SELECTION ==========
    // Show the mode selection dialog for new (unstarted) workouts
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  /// @brief Builds the header section of the mode selection dialog
  /// @details Creates a colored header container with the dialog title "Choose Workout Mode"
  /// and a close button. The header uses the theme's primary color for visual consistency.
  /// @param context The build context for accessing theme colors
  /// @return Widget A header container with title and close button
  Widget _buildHeader(BuildContext context) {
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
          // Dialog title
          const Expanded(
            child: Text(
              'Choose Workout Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Close button to dismiss dialog without selecting
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the main content section of the dialog
  /// @details Renders the workout information (name and exercise count) followed by
  /// two selectable mode cards. Each card displays an icon, title, and description
  /// explaining the mode's characteristics. Cards are built with _buildModeOption().
  /// @param context The build context for accessing theme styles
  /// @return Widget The content section with workout info and mode option cards
  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Workout name
          Text(
            training.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Exercise count summary
          Text(
            '${training.exercises.length} exercises',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // ========== STEP-BY-STEP MODE OPTION ==========
          // Traditional guided mode with rest periods between sets
          _buildModeOption(
            context: context,
            icon: Icons.play_arrow,
            title: 'Step-by-Step Mode',
            description: 'Traditional guided workout with rest periods between sets',
            color: Colors.blue,
            onTap: () => _openStepByStepMode(context),
          ),

          const SizedBox(height: 16),

          // ========== ALL-AT-ONCE MODE OPTION ==========
          // Self-paced mode without timers or sequencing
          _buildModeOption(
            context: context,
            icon: Icons.list,
            title: 'All-at-Once Mode',
            description: 'Fill out all exercises at your own pace without timers',
            color: Colors.green,
            onTap: () => _openAllAtOnceMode(context),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// @brief Builds a single selectable mode option card
  /// @details Creates an interactive card widget with icon, title, description, and
  /// forward arrow. The icon is displayed in a circular badge with a subtle background
  /// color. Tapping the card invokes the onTap callback.
  /// @param context The build context for theme access
  /// @param icon The IconData to display in the icon badge
  /// @param title The mode title to display prominently
  /// @param description The mode description explaining its characteristics
  /// @param color The primary color used for the icon badge and accents
  /// @param onTap Callback function invoked when the card is tapped
  /// @return Widget A selectable mode option card
  Widget _buildModeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon badge with subtle background color
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Title and description text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Forward arrow indicating navigation
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// @brief Opens the step-by-step mode workout dialog
  /// @details Closes the current mode selection dialog and displays WorkoutSessionDialog,
  /// which provides guided, set-by-set exercise tracking with rest timers between sets.
  /// The dialog is non-dismissible to prevent accidental cancellation during a workout.
  /// @param context The build context for navigation
  /// @return void
  void _openStepByStepMode(BuildContext context) {
    // Close mode selection dialog
    Navigator.pop(context);
    // Show step-by-step workout dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal during workout
      builder: (context) => WorkoutSessionDialog(
        training: training,
        onWorkoutUpdated: onWorkoutUpdated,
      ),
    );
  }

  /// @brief Opens the all-at-once mode workout dialog
  /// @details Closes the current mode selection dialog and displays BulkWorkoutDialog,
  /// which provides a self-paced interface for completing all exercises without
  /// sequencing or rest timers. Users can navigate freely between exercises.
  /// The dialog is non-dismissible to prevent accidental cancellation during a workout.
  /// @param context The build context for navigation
  /// @return void
  void _openAllAtOnceMode(BuildContext context) {
    // Close mode selection dialog
    Navigator.pop(context);
    // Show all-at-once workout dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal during workout
      builder: (context) => BulkWorkoutDialog(
        training: training,
        onWorkoutUpdated: onWorkoutUpdated,
      ),
    );
  }
}