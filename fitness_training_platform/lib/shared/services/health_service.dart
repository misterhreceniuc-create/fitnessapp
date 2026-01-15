import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();

  /// Request permissions for health data
  Future<bool> requestPermissions() async {
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.WEIGHT,
      ];

      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);

      if (hasPermissions != true) {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
      }

      return hasPermissions ?? false;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Get step count for today
  Future<int> getTodaySteps() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = now;

      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        print('Health permissions not granted');
        return 0;
      }

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (healthData.isEmpty) {
        print('No step data found for today');
        return 0;
      }

      // Sum up all step data points for today
      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          totalSteps += (data.value as num).toInt();
        }
      }

      return totalSteps;
    } catch (e) {
      print('Error getting today\'s steps: $e');
      return 0;
    }
  }

  /// Get step count for a specific date range
  Future<int> getStepsForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        print('Health permissions not granted');
        return 0;
      }

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startDate,
        endTime: endDate,
      );

      if (healthData.isEmpty) {
        return 0;
      }

      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          totalSteps += (data.value as num).toInt();
        }
      }

      return totalSteps;
    } catch (e) {
      print('Error getting steps for date range: $e');
      return 0;
    }
  }

  /// Check if health data is available on this device
  Future<bool> isHealthDataAvailable() async {
    try {
      return await _health.isDataTypeAvailable(HealthDataType.STEPS);
    } catch (e) {
      print('Error checking health data availability: $e');
      return false;
    }
  }
}
