// ==================== lib/shared/models/measurement_model.dart ====================
class MeasurementModel {
  final String id;
  final String traineeId;
  final DateTime date;
  final double weight;
  final Map<String, double> bodyMeasurements;

  MeasurementModel({
    required this.id,
    required this.traineeId,
    required this.date,
    required this.weight,
    required this.bodyMeasurements,
  });

  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    return MeasurementModel(
      id: json['id'],
      traineeId: json['traineeId'],
      date: DateTime.parse(json['date']),
      weight: json['weight'].toDouble(),
      bodyMeasurements: Map<String, double>.from(json['bodyMeasurements']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traineeId': traineeId,
      'date': date.toIso8601String(),
      'weight': weight,
      'bodyMeasurements': bodyMeasurements,
    };
  }
}