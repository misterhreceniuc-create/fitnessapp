// ==================== lib/main.dart ====================
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/dependency_injection/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const FitnessTrainingApp());
}