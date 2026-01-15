/// @file progress_report_dialog.dart
/// @brief Dialog for displaying detailed trainee progress reports to trainers
/// @details This file implements a comprehensive progress report interface that allows
/// trainers to review trainees' workout performance improvements. The dialog fetches
/// exercise history data from ExerciseHistoryService, generates TrainingProgressReport
/// with exercise-by-exercise comparisons against previous performance, and displays
/// visual summaries including overall improvement percentage, volume increases, and
/// detailed per-exercise progress metrics (weight, reps, volume changes). Used when
/// trainers review completed workouts to provide feedback and track progressive overload.

import 'package:flutter/material.dart';
import '../../../../shared/models/exercise_history_model.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/services/exercise_history_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @class ProgressReportDialog
/// @brief Stateful widget for displaying trainee progress reports to trainers
/// @details Creates a dialog that loads and displays comprehensive progress data
/// comparing current workout performance against previous sessions. Shows both
/// aggregate metrics (overall improvement rate, total volume increase) and
/// detailed exercise-level breakdowns with current vs. previous performance.
class ProgressReportDialog extends StatefulWidget {
  /// @brief The completed training session to generate a report for
  final TrainingModel completedTraining;

  /// @brief Name of the trainee for display in the report
  final String traineeName;

  /// @brief Constructor for ProgressReportDialog
  /// @param key Widget key for state management
  /// @param completedTraining Completed training to analyze
  /// @param traineeName Trainee's name for display
  const ProgressReportDialog({
    super.key,
    required this.completedTraining,
    required this.traineeName,
  });

  @override
  State<ProgressReportDialog> createState() => _ProgressReportDialogState();
}

/// @class _ProgressReportDialogState
/// @brief State class for progress report generation and display
/// @details Manages async loading of progress report data from ExerciseHistoryService,
/// handles loading/error states, and renders the complete progress visualization with
/// overall summaries and per-exercise breakdowns.
class _ProgressReportDialogState extends State<ProgressReportDialog> {
  /// @brief Service for retrieving exercise history and generating progress reports
  final ExerciseHistoryService _historyService = sl.get<ExerciseHistoryService>();

  /// @brief The generated progress report, null while loading or on error
  TrainingProgressReport? _progressReport;

  /// @brief Loading state flag for async report generation
  bool _isLoading = true;

  /// @brief Initializes state and triggers progress report generation
  @override
  void initState() {
    super.initState();
    _generateProgressReport();
  }

  /// @brief Generates the progress report from exercise history data
  /// @details Calls ExerciseHistoryService to compare current workout against
  /// previous performance for each exercise. Updates state with generated report
  /// or sets loading to false on error. Runs asynchronously on widget init.
  Future<void> _generateProgressReport() async {
    try {
      final report = await _historyService.generateProgressReport(
        widget.completedTraining,
        widget.traineeName,
      );
      setState(() {
        _progressReport = report;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating progress report: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// @brief Builds the complete progress report dialog UI
  /// @details Shows loading indicator while generating report, error message if
  /// generation failed, or complete progress visualization with header and content.
  /// @return Dialog widget containing the progress report interface
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _progressReport != null
                      ? _buildProgressContent()
                      : _buildErrorContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// @brief Builds the header section with report title and trainee/workout info
  /// @details Displays "Progress Report" title with trainee name and workout name
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress Report',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.traineeName} • ${widget.completedTraining.name}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
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

  /// @brief Builds the main progress content with summary and exercise breakdown
  /// @details Shows overall performance summary card followed by detailed
  /// exercise-by-exercise analysis cards in a scrollable view
  Widget _buildProgressContent() {
    final report = _progressReport!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallSummary(report),
          const SizedBox(height: 20),
          _buildExerciseBreakdown(report),
        ],
      ),
    );
  }

  /// @brief Builds the overall performance summary card
  /// @details Displays aggregate metrics including overall progress summary text,
  /// total exercises, improved exercises count, improvement percentage, and total
  /// volume increase. Uses stat cards for quick visual reference.
  Widget _buildOverallSummary(TrainingProgressReport report) {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Overall Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              report.overallProgressSummary,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Exercises',
                    '${report.totalExercises}',
                    'Total',
                    Icons.fitness_center,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Improved',
                    '${report.exercisesWithImprovement}',
                    'Exercises',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Progress Rate',
                    '${report.improvementPercentage.toStringAsFixed(0)}%',
                    'Improvement',
                    Icons.percent,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            if (report.totalVolumeIncrease > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total volume increased by ${report.totalVolumeIncrease.toStringAsFixed(1)} kg•reps',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// @brief Builds a single statistic card for overall summary
  /// @details Creates a colored card with icon, value, title, and subtitle
  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the exercise-by-exercise analysis section
  /// @details Displays "Exercise-by-Exercise Analysis" header followed by
  /// comparison cards for each exercise in the workout
  Widget _buildExerciseBreakdown(TrainingProgressReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercise-by-Exercise Analysis',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...report.exerciseComparisons.map((comparison) => _buildExerciseComparisonCard(comparison)),
      ],
    );
  }

  /// @brief Builds a detailed comparison card for a single exercise
  /// @details Shows exercise name with improvement badge, progress description,
  /// current performance sets, previous performance sets (if available), and
  /// progress metrics (weight/reps/volume changes with color-coded indicators).
  /// Uses green for improvements, blue for new exercises, orange for maintained.
  Widget _buildExerciseComparisonCard(ExerciseProgressComparison comparison) {
    final hasImproved = comparison.hasImproved;
    final cardColor = hasImproved ? Colors.green : comparison.previous == null ? Colors.blue : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comparison.exerciseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasImproved
                            ? Icons.trending_up
                            : comparison.previous == null
                                ? Icons.fiber_new
                                : Icons.remove,
                        size: 12,
                        color: cardColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasImproved
                            ? 'Improved'
                            : comparison.previous == null
                                ? 'New'
                                : 'Same',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              comparison.progressDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Current performance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Performance:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: comparison.current.asMap().entries.map((entry) {
                      final index = entry.key;
                      final set = entry.value;
                      return Text(
                        'Set ${index + 1}: ${set.reps}×${set.kg}kg',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Previous performance (if available)
            if (comparison.previous != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Performance:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: comparison.previous!.actualSets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        return Text(
                          'Set ${index + 1}: ${set.reps}×${set.kg}kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Progress metrics
            if (comparison.previous != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (comparison.weightProgress != 0) ...[
                    Expanded(
                      child: _buildProgressMetric(
                        'Weight',
                        '${comparison.weightProgress > 0 ? '+' : ''}${comparison.weightProgress.toStringAsFixed(1)}kg',
                        comparison.weightProgress > 0 ? Colors.green : Colors.red,
                        comparison.weightProgress > 0 ? Icons.trending_up : Icons.trending_down,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (comparison.repsProgress != 0) ...[
                    Expanded(
                      child: _buildProgressMetric(
                        'Reps',
                        '${comparison.repsProgress > 0 ? '+' : ''}${comparison.repsProgress}',
                        comparison.repsProgress > 0 ? Colors.green : Colors.red,
                        comparison.repsProgress > 0 ? Icons.trending_up : Icons.trending_down,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _buildProgressMetric(
                      'Volume',
                      '${comparison.volumeProgress > 0 ? '+' : ''}${comparison.volumeProgress.toStringAsFixed(0)}',
                      comparison.volumeProgress > 0 ? Colors.green : comparison.volumeProgress < 0 ? Colors.red : Colors.grey,
                      comparison.volumeProgress > 0 ? Icons.trending_up : comparison.volumeProgress < 0 ? Icons.trending_down : Icons.remove,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// @brief Builds a single progress metric indicator
  /// @details Creates a colored badge showing progress change with icon, value,
  /// and label. Used for weight, reps, and volume progress indicators.
  Widget _buildProgressMetric(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// @brief Builds the error message view when report generation fails
  /// @details Displays error icon and message prompting user to try again
  Widget _buildErrorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to generate progress report',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}