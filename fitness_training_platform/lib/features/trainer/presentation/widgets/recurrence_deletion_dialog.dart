import 'package:flutter/material.dart';
import '../../../../shared/models/training_model.dart';

enum DeletionScope { single, all }

class RecurrenceDeletionDialog extends StatelessWidget {
  final TrainingModel training;
  final Function(DeletionScope) onScopeSelected;

  const RecurrenceDeletionDialog({
    super.key,
    required this.training,
    required this.onScopeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete, color: Colors.red.shade600),
          const SizedBox(width: 12),
          const Text('Delete Workout'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This workout is part of a recurring series (${training.recurrenceDisplayText}).',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'What would you like to delete?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),

          // Single workout option
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.red.shade600),
              title: const Text('Delete this workout only'),
              subtitle: Text('Only remove "${training.name}" scheduled for ${_formatDate(training.scheduledDate)}'),
              onTap: () => onScopeSelected(DeletionScope.single),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // All workouts option
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(Icons.delete_sweep, color: Colors.red.shade700),
              title: Text(
                'Delete all workouts in this series',
                style: TextStyle(color: Colors.red.shade700),
              ),
              subtitle: Text(
                'Remove all ${training.totalRecurrences} workouts in this recurring series',
                style: TextStyle(color: Colors.red.shade600),
              ),
              onTap: () => onScopeSelected(DeletionScope.all),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 16),
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
                    'This action cannot be undone. Deleted workouts will be permanently removed.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
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
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}