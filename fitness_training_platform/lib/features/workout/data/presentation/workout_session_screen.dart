import 'dart:async';
import 'package:flutter/material.dart';
import '../data/exercise_model.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutId;
  final List<Exercise> exercises;

  const WorkoutSessionScreen({
    super.key,
    required this.workoutId,
    required this.exercises,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int currentExerciseIndex = 0;
  // Remove currentSet, we will show all sets at once
  int timerSeconds = 30; // Initial exercise time (adjust as needed)
  bool isResting = false;
  Timer? _timer;
  final List<List<TextEditingController>> repsControllers = [];
  final List<List<TextEditingController>> weightControllers = [];

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each exercise and set
    for (var exercise in widget.exercises) {
      repsControllers.add(List.generate(exercise.sets, (_) => TextEditingController()));
      weightControllers.add(List.generate(exercise.sets, (_) => TextEditingController()));
    }
    startExercise();
  }

  void startExercise() {
    setState(() {
      isResting = false;
      timerSeconds = widget.exercises[currentExerciseIndex].restTime > 0
          ? widget.exercises[currentExerciseIndex].restTime
          : 30;
    });
    _startTimer();
  }

  void startRest() {
    setState(() {
      isResting = true;
      timerSeconds = widget.exercises[currentExerciseIndex].restTime;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (timerSeconds > 0) {
          timerSeconds--;
        } else {
          timer.cancel();
          if (isResting) {
            // After rest, just stay on current exercise (all sets shown)
            // Optionally, you could auto-advance to next exercise, but here we wait for user
          } else {
            startRest();
          }
        }
      });
    });
  }

  void _showCompletion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout Completed! Great job!')),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises[currentExerciseIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text('Fill in your results for each set:'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: exercise.sets,
                itemBuilder: (context, setIndex) {
                  final repsController = repsControllers[currentExerciseIndex][setIndex];
                  final weightController = weightControllers[currentExerciseIndex][setIndex];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set ${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Target: ${exercise.reps} reps'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: repsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Repetitions',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: weightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$timerSeconds',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Require all sets to be filled before proceeding
                  bool allFilled = true;
                  for (int i = 0; i < exercise.sets; i++) {
                    if (repsControllers[currentExerciseIndex][i].text.isEmpty ||
                        weightControllers[currentExerciseIndex][i].text.isEmpty) {
                      allFilled = false;
                      break;
                    }
                  }
                  if (!allFilled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter reps and weight for all sets before continuing.')),
                    );
                    return;
                  }
                  _timer?.cancel();
                  if (currentExerciseIndex < widget.exercises.length - 1) {
                    setState(() {
                      currentExerciseIndex++;
                    });
                    startExercise();
                  } else {
                    _showCompletion();
                  }
                },
                child: Text(currentExerciseIndex < widget.exercises.length - 1 ? 'Next Exercise' : 'Finish Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}