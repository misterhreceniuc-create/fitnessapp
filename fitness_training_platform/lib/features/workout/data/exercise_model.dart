class ActualSet {
  final int reps;
  final double kg;

  ActualSet({required this.reps, required this.kg});

  factory ActualSet.fromJson(Map<String, dynamic> json) {
    return ActualSet(
      reps: json['reps'] ?? 0,
      kg: json['kg'] != null ? (json['kg'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'kg': kg,
  };
}

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final int restTime; // in seconds
  final List<ActualSet>? actualSets;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restTime,
    this.actualSets,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] ?? '',
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? 0,
      restTime: json['restTime'] ?? 60,
      actualSets: json['actualSets'] != null
          ? (json['actualSets'] as List).map((e) => ActualSet.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'restTime': restTime,
    if (actualSets != null) 'actualSets': actualSets!.map((e) => e.toJson()).toList(),
  };
}