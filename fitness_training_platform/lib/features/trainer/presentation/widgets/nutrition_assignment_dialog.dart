/// @file nutrition_assignment_dialog.dart
/// @brief Dialog for trainers to assign nutrition plans to trainees
/// @details Allows trainers to set daily caloric limits and assign recipes to trainees.
/// Includes predefined recipe templates and the ability to customize recipes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/nutrition_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/services/nutrition_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @class NutritionAssignmentDialog
/// @brief Dialog for assigning nutrition plans to trainees
class NutritionAssignmentDialog extends StatefulWidget {
  final String trainerId;
  final UserModel trainee;
  final VoidCallback? onPlanCreated;

  const NutritionAssignmentDialog({
    Key? key,
    required this.trainerId,
    required this.trainee,
    this.onPlanCreated,
  }) : super(key: key);

  @override
  State<NutritionAssignmentDialog> createState() => _NutritionAssignmentDialogState();
}

class _NutritionAssignmentDialogState extends State<NutritionAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final NutritionService _nutritionService = sl.get<NutritionService>();

  bool _isLoading = false;
  final List<RecipeModel> _selectedRecipes = [];

  // Predefined recipe templates
  final List<RecipeModel> _availableRecipes = [
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Grilled Chicken Salad',
      description: 'High protein, low carb salad with grilled chicken breast',
      ingredients: [
        '200g chicken breast',
        '2 cups mixed greens',
        '1/4 cup cherry tomatoes',
        '2 tbsp olive oil',
        '1 tbsp balsamic vinegar',
      ],
      instructions: [
        'Grill chicken breast until fully cooked',
        'Chop vegetables',
        'Mix greens, tomatoes, and chicken',
        'Drizzle with olive oil and balsamic vinegar',
      ],
      calories: 350,
      prepTimeMinutes: 20,
    ),
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Oatmeal with Berries',
      description: 'Nutritious breakfast with complex carbs and antioxidants',
      ingredients: [
        '1/2 cup oats',
        '1 cup water or milk',
        '1/2 cup mixed berries',
        '1 tbsp honey',
        '1 tbsp almonds',
      ],
      instructions: [
        'Cook oats in water/milk according to package',
        'Top with berries, honey, and almonds',
        'Serve warm',
      ],
      calories: 300,
      prepTimeMinutes: 10,
    ),
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Salmon with Vegetables',
      description: 'Omega-3 rich dinner with roasted vegetables',
      ingredients: [
        '150g salmon fillet',
        '1 cup broccoli',
        '1/2 cup carrots',
        '1 tbsp olive oil',
        'Lemon and herbs',
      ],
      instructions: [
        'Season salmon with lemon and herbs',
        'Bake at 180°C for 15 minutes',
        'Roast vegetables with olive oil',
        'Serve together',
      ],
      calories: 450,
      prepTimeMinutes: 25,
    ),
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Greek Yogurt Parfait',
      description: 'High protein snack with probiotics',
      ingredients: [
        '200g Greek yogurt',
        '1/4 cup granola',
        '1/2 cup mixed berries',
        '1 tbsp honey',
      ],
      instructions: [
        'Layer yogurt in a glass',
        'Add granola and berries',
        'Drizzle with honey',
      ],
      calories: 250,
      prepTimeMinutes: 5,
    ),
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Quinoa Bowl',
      description: 'Complete protein source with vegetables',
      ingredients: [
        '1 cup cooked quinoa',
        '100g chickpeas',
        '1/2 avocado',
        '1/4 cup corn',
        'Lime dressing',
      ],
      instructions: [
        'Cook quinoa according to package',
        'Mix with chickpeas, corn, and avocado',
        'Add lime dressing',
      ],
      calories: 400,
      prepTimeMinutes: 15,
    ),
    RecipeModel(
      id: const Uuid().v4(),
      name: 'Protein Smoothie',
      description: 'Quick post-workout protein shake',
      ingredients: [
        '1 scoop protein powder',
        '1 banana',
        '1 cup almond milk',
        '1 tbsp peanut butter',
        'Ice cubes',
      ],
      instructions: [
        'Add all ingredients to blender',
        'Blend until smooth',
        'Serve immediately',
      ],
      calories: 320,
      prepTimeMinutes: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _planNameController.text = 'Nutrition Plan for ${widget.trainee.name}';
    _caloriesController.text = '2000';
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _handleCreatePlan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one recipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final plan = NutritionPlanModel(
        id: const Uuid().v4(),
        traineeId: widget.trainee.id,
        trainerId: widget.trainerId,
        name: _planNameController.text.trim(),
        dailyCalories: int.parse(_caloriesController.text),
        macros: {
          'protein': 150,
          'carbs': 200,
          'fats': 60,
        },
        meals: [],
        recipes: _selectedRecipes,
        createdAt: DateTime.now(),
      );

      await _nutritionService.createNutritionPlan(plan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nutrition plan created for ${widget.trainee.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
        widget.onPlanCreated?.call();
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

  String? _validateCalories(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Daily calories is required';
    }
    final calories = int.tryParse(value);
    if (calories == null) {
      return 'Please enter a valid number';
    }
    if (calories < 1000 || calories > 5000) {
      return 'Calories should be between 1000-5000';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
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
                  const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Nutrition Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'For: ${widget.trainee.name}',
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
                      // Plan Name
                      TextFormField(
                        controller: _planNameController,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name',
                          prefixIcon: Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Plan name is required';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Daily Caloric Limit
                      TextFormField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(
                          labelText: 'Daily Caloric Limit',
                          prefixIcon: Icon(Icons.local_fire_department),
                          suffixText: 'kcal',
                          border: OutlineInputBorder(),
                          helperText: 'Recommended: 1500-3000 kcal/day',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _validateCalories,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),

                      // Recipes Section
                      Row(
                        children: [
                          const Text(
                            'Select Recipes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('${_selectedRecipes.length} selected'),
                            backgroundColor: Colors.orange.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Recipe Cards
                      ..._availableRecipes.map((recipe) {
                        final isSelected = _selectedRecipes.any((r) => r.id == recipe.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isSelected ? Colors.orange.shade50 : null,
                          elevation: isSelected ? 3 : 1,
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedRecipes.removeWhere((r) => r.id == recipe.id);
                                      } else {
                                        _selectedRecipes.add(recipe);
                                      }
                                    });
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedRecipes.add(recipe);
                                              } else {
                                                _selectedRecipes.removeWhere((r) => r.id == recipe.id);
                                              }
                                            });
                                          },
                                  ),
                                  const SizedBox(width: 12),
                                  // Recipe Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe.name,
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
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.local_fire_department, size: 16, color: Colors.orange.shade700),
                                            const SizedBox(width: 4),
                                            Text('${recipe.calories} kcal', style: const TextStyle(fontSize: 13)),
                                            const SizedBox(width: 16),
                                            Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                                            const SizedBox(width: 4),
                                            Text('${recipe.prepTimeMinutes} min', style: const TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // View Details Button
                                  IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    onPressed: () => _showRecipeDetails(recipe),
                                  ),
                                ],
                              ),
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
                    onPressed: _isLoading ? null : _handleCreatePlan,
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
                    label: Text(_isLoading ? 'Creating...' : 'Assign Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
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

  void _showRecipeDetails(RecipeModel recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(recipe.description),
              const SizedBox(height: 16),
              const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...recipe.ingredients.map((ing) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('• $ing'),
                  )),
              const SizedBox(height: 16),
              const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...recipe.instructions.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('${entry.key + 1}. ${entry.value}'),
                  )),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text('${recipe.calories} calories'),
                  const SizedBox(width: 24),
                  Icon(Icons.timer, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text('${recipe.prepTimeMinutes} minutes'),
                ],
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
}
