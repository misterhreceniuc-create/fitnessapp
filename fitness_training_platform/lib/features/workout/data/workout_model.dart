import 'exercise_model.dart';

class Workout {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final List<Exercise> exercises;

  Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.exercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    var exercisesList = <Exercise>[];
    if (json['exercises'] != null) {
      exercisesList = (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList();
    }
    return Workout(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? 'assets/images/workout1.png',
      exercises: exercisesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}