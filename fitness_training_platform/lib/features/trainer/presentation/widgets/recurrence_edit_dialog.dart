import 'package:flutter/material.dart';
import '../../../../shared/models/training_model.dart';

enum EditScope { single, all }

class RecurrenceEditDialog extends StatelessWidget {
  final TrainingModel training;
  final Function(EditScope) onScopeSelected;

  const RecurrenceEditDialog({
    super.key,
    required this.training,
    required this.onScopeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Text('Edit Workout'),
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
            'What would you like to edit?',
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
              leading: Icon(Icons.calendar_today, color: Colors.blue.shade600),
              title: const Text('Edit this workout only'),
              subtitle: Text('Only modify "${training.name}" scheduled for ${_formatDate(training.scheduledDate)}'),
              onTap: () => onScopeSelected(EditScope.single),
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
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(Icons.repeat, color: Colors.orange.shade600),
              title: const Text('Edit all workouts in this series'),
              subtitle: Text('Modify all ${training.totalRecurrences} workouts in this recurring series'),
              onTap: () => onScopeSelected(EditScope.all),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing all workouts will update the content but preserve individual scheduled dates.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
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