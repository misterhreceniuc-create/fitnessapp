import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/models/training_model.dart';
import '../../../../shared/models/training_template_model.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../shared/services/exercise_library_service.dart';
import '../../../../shared/services/template_service.dart';
import '../../../../shared/services/user_service.dart';
import '../../../../shared/services/training_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../routing/route_names.dart';
import '../widgets/training_template_dialog.dart';
import '../widgets/custom_exercise_dialog.dart';
import '../widgets/workout_creation_wizard.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> with SingleTickerProviderStateMixin {
  final ExerciseLibraryService _exerciseLibraryService = sl.get<ExerciseLibraryService>();
  final TemplateService _templateService = sl.get<TemplateService>();
  final UserService _userService = sl.get<UserService>();

  late TabController _tabController;
  List<WorkoutTemplate> _templates = [];
  List<ExerciseTemplate> _customExercises = [];
  List<UserModel> _trainees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      try {
        // Load training templates created by this trainer
        final templates = await _templateService.getTemplatesForTrainer(currentUser.id);
        final customExercises = _exerciseLibraryService.getCustomExercisesByTrainer(currentUser.id);
        final trainees = await _userService.getTrainees(currentUser.id);

        setState(() {
          _templates = templates;
          _customExercises = customExercises;
          _trainees = trainees;
          _isLoading = false;
        });

        print('=== TEMPLATES DATA LOADED ===');
        print('Templates: ${templates.length}');
        print('Trainees: ${trainees.length}');
        for (var trainee in trainees) {
          print('- Trainee: ${trainee.name} (${trainee.id})');
        }
      } catch (e) {
        print('Error loading templates data: $e');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(RouteNames.trainerDashboard);
          },
        ),
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
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Workout Templates'),
            Tab(icon: Icon(Icons.extension), text: 'Custom Exercises'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrainingTemplatesTab(),
                _buildCustomExercisesTab(),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "custom_exercise",
            onPressed: _createCustomExercise,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.extension),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "training_template",
            onPressed: _createTrainingTemplate,
            icon: const Icon(Icons.add),
            label: const Text('Workout Template'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingTemplatesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createTrainingTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('New Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importTemplate,
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
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
                    '${_templates.length} workout templates created',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _templates.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No workout templates yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Create your first workout template to reuse workout plans'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getDifficultyColor(template.difficulty),
                            child: Text(
                              template.difficulty[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(template.description),
                              Text('${template.exercises.length} exercises • ${template.estimatedDuration} min'),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getDifficultyColor(template.difficulty).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      template.difficulty.toUpperCase(),
                                      style: TextStyle(
                                        color: _getDifficultyColor(template.difficulty),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (template.isPublic)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'PUBLIC',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility),
                                    SizedBox(width: 8),
                                    Text('View Details'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy),
                                    SizedBox(width: 8),
                                    Text('Duplicate'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'use',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Use Template', style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              print('=== POPUP MENU SELECTED ===');
                              print('Selected value: $value');
                              print('Template: ${template.name}');

                              switch (value) {
                                case 'view':
                                  print('Calling _viewTemplate');
                                  _viewTemplate(template);
                                  break;
                                case 'edit':
                                  print('Calling _editTemplate');
                                  _editTemplate(template);
                                  break;
                                case 'duplicate':
                                  print('Calling _duplicateTemplate');
                                  _duplicateTemplate(template);
                                  break;
                                case 'use':
                                  print('Calling _useTemplate');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('USE TEMPLATE CLICKED: ${template.name}'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                  _useTemplate(template);
                                  break;
                                case 'delete':
                                  print('Calling _deleteTemplate');
                                  _deleteTemplate(template);
                                  break;
                              }
                            },
                          ),
                          onTap: () => _viewTemplate(template),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomExercisesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createCustomExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('New Exercise'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _browseExerciseLibrary,
                  icon: const Icon(Icons.library_books),
                  label: const Text('Library'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    '${_customExercises.length} custom exercises created',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _customExercises.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.extension, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No custom exercises yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Create custom exercises to use in your workouts'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _customExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _customExercises[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(exercise.category),
                            child: Icon(
                              _getCategoryIcon(exercise.category),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target: ${exercise.targetMuscle}'),
                              Text('Equipment: ${exercise.equipment}'),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(exercise.category).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      exercise.category.toUpperCase(),
                                      style: TextStyle(
                                        color: _getCategoryColor(exercise.category),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      exercise.difficultyLevel.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility),
                                    SizedBox(width: 8),
                                    Text('View Details'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy),
                                    SizedBox(width: 8),
                                    Text('Duplicate'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'view':
                                  _viewExercise(exercise);
                                  break;
                                case 'edit':
                                  _editExercise(exercise);
                                  break;
                                case 'duplicate':
                                  _duplicateExercise(exercise);
                                  break;
                                case 'delete':
                                  _deleteExercise(exercise);
                                  break;
                              }
                            },
                          ),
                          onTap: () => _viewExercise(exercise),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helper methods
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'strength':
        return Colors.red;
      case 'cardio':
        return Colors.blue;
      case 'flexibility':
        return Colors.green;
      case 'balance':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'strength':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'flexibility':
        return Icons.self_improvement;
      case 'balance':
        return Icons.balance;
      default:
        return Icons.extension;
    }
  }

  // Action methods
  void _createTrainingTemplate() {
    showDialog(
      context: context,
      builder: (context) => WorkoutTemplateDialog(
        onTemplateCreated: (template) async {
          try {
            final createdTemplate = await _templateService.createTemplate(template);
            setState(() {
              _templates.add(createdTemplate);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Workout template "${template.name}" created!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error creating template: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _createCustomExercise() {
    showDialog(
      context: context,
      builder: (context) => CustomExerciseDialog(
        onExerciseCreated: (exercise) {
          setState(() {
            _customExercises.add(exercise);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom exercise "${exercise.name}" created!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _importTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import template feature - coming soon!')),
    );
  }

  void _browseExerciseLibrary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exercise library browser - coming soon!')),
    );
  }

  void _viewTemplate(WorkoutTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${template.description}'),
              Text('Difficulty: ${template.difficulty.toUpperCase()}'),
              Text('Duration: ${template.estimatedDuration} minutes'),
              Text('Category: ${template.category}'),
              Text('Created: ${template.createdAt.toString().split(' ')[0]}'),
              Text('Public: ${template.isPublic ? "Yes" : "No"}'),
              if (template.tags.isNotEmpty)
                Text('Tags: ${template.tags.join(", ")}'),
              const SizedBox(height: 16),
              const Text('Exercises:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...template.exercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${exercise.name} (${exercise.category})'),
              )),
              if (template.notes != null) ...[
                const SizedBox(height: 12),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(template.notes!),
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

  void _viewExercise(ExerciseTemplate exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exercise.name),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: ${exercise.category}'),
              Text('Target Muscle: ${exercise.targetMuscle}'),
              Text('Equipment: ${exercise.equipment}'),
              Text('Difficulty: ${exercise.difficultyLevel}'),
              const SizedBox(height: 16),
              const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(exercise.instructions),
              if (exercise.tips.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...exercise.tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $tip'),
                )),
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

  void _editTemplate(WorkoutTemplate template) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit template feature - coming soon!')),
    );
  }

  void _editExercise(ExerciseTemplate exercise) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit exercise feature - coming soon!')),
    );
  }

  void _duplicateTemplate(WorkoutTemplate template) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate template feature - coming soon!')),
    );
  }

  void _duplicateExercise(ExerciseTemplate exercise) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate exercise feature - coming soon!')),
    );
  }

  void _useTemplate(WorkoutTemplate template) {
    print('=== USE TEMPLATE CLICKED ===');
    print('Template: ${template.name}');
    print('Template ID: ${template.id}');
    print('Trainees count: ${_trainees.length}');

    if (_trainees.isEmpty) {
      print('❌ No trainees available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trainees available. Please add trainees first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show simple trainee selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use Template: ${template.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select a trainee to create this workout for:'),
              const SizedBox(height: 16),
              ...(_trainees.map((trainee) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(trainee.name[0]),
                  ),
                  title: Text(trainee.name),
                  subtitle: Text('ID: ${trainee.id}'),
                  onTap: () {
                    Navigator.pop(context);
                    _createWorkoutFromTemplate(template, trainee);
                  },
                ),
              ))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _createWorkoutFromTemplate(WorkoutTemplate template, UserModel trainee) async {
    print('Creating workout from template: ${template.name} for ${trainee.name}');

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    try {
      // Convert template to TrainingModel
      final workout = template.toTrainingModel(
        traineeId: trainee.id,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      );

      // Create the workout
      final createdWorkout = await sl.get<TrainingService>().createTraining(workout);

      print('✅ Workout created successfully: ${createdWorkout.id}');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Workout "${template.name}" created for ${trainee.name}!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Navigate back to dashboard
      context.go(RouteNames.trainerDashboard);

    } catch (e) {
      print('❌ Error creating workout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating workout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteTemplate(WorkoutTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _templateService.deleteTemplate(template.id);
                setState(() {
                  _templates.remove(template);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Template "${template.name}" deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting template: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteExercise(ExerciseTemplate exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Are you sure you want to delete "${exercise.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _customExercises.remove(exercise);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exercise "${exercise.name}" deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}