/// @file food_log_dialog.dart
/// @brief Dialog for trainees to log their daily food intake
/// @details Allows trainees to log multiple food entries throughout the day
/// with food name and calorie count for each item

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/nutrition_model.dart';
import '../../../../shared/services/nutrition_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @class FoodLogDialog
/// @brief Dialog for logging daily food intake
class FoodLogDialog extends StatefulWidget {
  final String traineeId;
  final DateTime date;
  final VoidCallback? onFoodLogged;

  const FoodLogDialog({
    Key? key,
    required this.traineeId,
    required this.date,
    this.onFoodLogged,
  }) : super(key: key);

  @override
  State<FoodLogDialog> createState() => _FoodLogDialogState();
}

class _FoodLogDialogState extends State<FoodLogDialog> {
  final _formKey = GlobalKey<FormState>();
  final NutritionService _nutritionService = sl.get<NutritionService>();

  final List<_FoodEntry> _foodEntries = [_FoodEntry()];
  bool _isLoading = false;

  Future<void> _handleLogFood() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if at least one entry has data
    final validEntries = _foodEntries.where((e) =>
      e.nameController.text.trim().isNotEmpty &&
      e.caloriesController.text.trim().isNotEmpty
    ).toList();

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one food item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert entries to FoodItemModel
      final foodItems = validEntries.map((entry) {
        return FoodItemModel(
          name: entry.nameController.text.trim(),
          quantity: 1,
          unit: 'serving',
          calories: int.parse(entry.caloriesController.text),
        );
      }).toList();

      final totalCalories = foodItems.fold(0, (sum, item) => sum + item.calories);

      // Create nutrition entry
      final nutritionEntry = NutritionEntryModel(
        id: const Uuid().v4(),
        traineeId: widget.traineeId,
        date: widget.date,
        consumedFoods: foodItems,
        totalCalories: totalCalories,
      );

      await _nutritionService.logNutrition(nutritionEntry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${foodItems.length} food items (${totalCalories} kcal)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
        widget.onFoodLogged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _addEntry() {
    setState(() {
      _foodEntries.add(_FoodEntry());
    });
  }

  void _removeEntry(int index) {
    if (_foodEntries.length > 1) {
      setState(() {
        _foodEntries[index].dispose();
        _foodEntries.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    for (var entry in _foodEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Log Food Intake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.date.toString().split(' ')[0],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Food Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _isLoading ? null : _addEntry,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Food entries
                      ..._foodEntries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final foodEntry = entry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Item ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_foodEntries.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        color: Colors.red,
                                        onPressed: _isLoading ? null : () => _removeEntry(index),
                                        tooltip: 'Remove',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: foodEntry.nameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Food Name',
                                          hintText: 'e.g., Chicken Salad',
                                          prefixIcon: Icon(Icons.fastfood),
                                          border: OutlineInputBorder(),
                                        ),
                                        textCapitalization: TextCapitalization.words,
                                        validator: (value) {
                                          // Only validate if this is the only entry or if calories are entered
                                          final hasCalories = foodEntry.caloriesController.text.trim().isNotEmpty;
                                          if (hasCalories && (value == null || value.trim().isEmpty)) {
                                            return 'Food name required';
                                          }
                                          return null;
                                        },
                                        enabled: !_isLoading,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: foodEntry.caloriesController,
                                        decoration: const InputDecoration(
                                          labelText: 'Calories',
                                          hintText: '250',
                                          suffixText: 'kcal',
                                          prefixIcon: Icon(Icons.local_fire_department),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        validator: (value) {
                                          // Only validate if this is the only entry or if name is entered
                                          final hasName = foodEntry.nameController.text.trim().isNotEmpty;
                                          if (hasName && (value == null || value.trim().isEmpty)) {
                                            return 'Calories required';
                                          }
                                          if (value != null && value.trim().isNotEmpty) {
                                            final calories = int.tryParse(value);
                                            if (calories == null || calories < 0) {
                                              return 'Invalid';
                                            }
                                          }
                                          return null;
                                        },
                                        enabled: !_isLoading,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleLogFood,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Logging...' : 'Log Food'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// @class _FoodEntry
/// @brief Helper class to manage individual food entry controllers
class _FoodEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();

  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
  }
}
