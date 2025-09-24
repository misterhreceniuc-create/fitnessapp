import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../workout_model.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailScreen({Key? key, required this.workout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workout.title)),
      body: Column(
        children: [
          Image.asset(workout.imageUrl),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              workout.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercises:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final exercise in workout.exercises) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 18)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              if (exercise.actualSets != null && exercise.actualSets!.isNotEmpty) ...[
                                for (int i = 0; i < exercise.actualSets!.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                                    child: Text(
                                      'Set ${i + 1}: ${exercise.actualSets![i].reps} reps, ${exercise.actualSets![i].kg} kg',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                              ]
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, top: 2.0, bottom: 2.0),
                                  child: Text(
                                    '${exercise.sets} sets x ${exercise.reps} reps',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ]
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _startWorkout(context, workout),
              child: const Text('Start Training'),
            ),
          ),
        ],
      ),
    );
  }

  void _startWorkout(BuildContext context, Workout workout) {
    context.push('/workout-session', extra: {
      'workoutId': workout.id,
      'exercises': workout.exercises,
    });
  }
}