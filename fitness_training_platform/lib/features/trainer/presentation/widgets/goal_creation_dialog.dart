import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/goal_model.dart';

class GoalCreationDialog extends StatefulWidget {
  final UserModel trainee;
  final Function(GoalModel) onGoalCreated;

  const GoalCreationDialog({
    super.key,
    required this.trainee,
    required this.onGoalCreated,
  });

  @override
  State<GoalCreationDialog> createState() => _GoalCreationDialogState();
}

class _GoalCreationDialogState extends State<GoalCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _unitController = TextEditingController();

  GoalType _selectedType = GoalType.weight;
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    _targetValueController.dispose();
    _currentValueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      final goal = GoalModel(
        id: const Uuid().v4(),
        traineeId: widget.trainee.id,
        trainerId: '', // Will be set by the caller
        name: _nameController.text.trim(),
        type: _selectedType,
        targetValue: double.parse(_targetValueController.text.trim()),
        currentValue: double.parse(_currentValueController.text.trim()),
        unit: _unitController.text.trim(),
        deadline: _deadline,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      widget.onGoalCreated(goal);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.purple, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create New Goal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'For ${widget.trainee.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Goal Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Name',
                    hintText: 'e.g., Lose 10kg, Bench Press 100kg',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a goal name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Goal Type
                DropdownButtonFormField<GoalType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Goal Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: GoalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getGoalTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        // Set default units based on type
                        if (value == GoalType.weight) {
                          _unitController.text = 'kg';
                        } else if (value == GoalType.measurement) {
                          _unitController.text = 'cm';
                        } else {
                          _unitController.text = 'reps';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Current Value
                TextFormField(
                  controller: _currentValueController,
                  decoration: const InputDecoration(
                    labelText: 'Current Value',
                    hintText: 'e.g., 75',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter current value';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Target Value
                TextFormField(
                  controller: _targetValueController,
                  decoration: const InputDecoration(
                    labelText: 'Target Value',
                    hintText: 'e.g., 70',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter target value';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Unit
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'e.g., kg, cm, reps',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter unit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Deadline
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Deadline'),
                  subtitle: Text(
                    '${_deadline.day}/${_deadline.month}/${_deadline.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Change'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _deadline = picked;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saveGoal,
                      icon: const Icon(Icons.check),
                      label: const Text('Create Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.weight:
        return 'Weight Goal';
      case GoalType.measurement:
        return 'Measurement Goal';
      case GoalType.performance:
        return 'Performance Goal';
    }
  }
}
