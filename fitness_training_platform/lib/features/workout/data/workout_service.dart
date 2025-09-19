import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_model.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Workout>> getWorkouts() {
    return _firestore.collection('workouts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Workout.fromJson(data);
      }).toList();
    });
  }

  Future<Workout?> getWorkoutById(String workoutId) async {
    final doc = await _firestore.collection('workouts').doc(workoutId).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return Workout.fromJson(data);
    }
    return null;
  }
}