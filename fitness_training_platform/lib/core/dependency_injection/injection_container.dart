import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_service.dart';
import '../../shared/services/training_service.dart';
import '../../shared/services/nutrition_service.dart';
import '../../shared/services/exercise_library_service.dart';
import '../../shared/services/template_service.dart';

class ServiceLocator {
  static final _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};

  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }
    return service as T;
  }

  void register<T>(T service) {
    _services[T] = service;
  }
}

final sl = ServiceLocator();

Future<void> setupDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  
  sl.register<SharedPreferences>(sharedPreferences);
  sl.register<AuthService>(AuthService());
  sl.register<UserService>(UserService());
  sl.register<TrainingService>(TrainingService());
  sl.register<NutritionService>(NutritionService());
  sl.register<ExerciseLibraryService>(ExerciseLibraryService());
  sl.register<TemplateService>(TemplateService());
}