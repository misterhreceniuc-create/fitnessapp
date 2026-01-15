/// @file injection_container.dart
/// @brief Dependency injection container for the application
/// @details Implements a simple service locator pattern for managing dependencies

import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_service.dart';
import '../../shared/services/training_service.dart';
import '../../shared/services/nutrition_service.dart';
import '../../shared/services/exercise_library_service.dart';
import '../../shared/services/template_service.dart';
import '../../shared/services/exercise_history_service.dart';
import '../../shared/services/measurement_service.dart';
import '../../shared/services/health_service.dart';
import '../../shared/services/steps_service.dart';
import '../../shared/services/goal_service.dart';
import '../../shared/services/local_storage_service.dart';

/// @class ServiceLocator
/// @brief Simple service locator implementation for dependency injection
/// @details Singleton pattern that stores and retrieves service instances by type
class ServiceLocator {
  /// @brief Singleton instance
  static final _instance = ServiceLocator._internal();

  /// @brief Factory constructor returns singleton instance
  factory ServiceLocator() => _instance;

  /// @brief Private constructor for singleton
  ServiceLocator._internal();

  /// @brief Map storing service instances keyed by their type
  final Map<Type, dynamic> _services = {};

  /// @brief Retrieve a service instance by type
  /// @tparam T The service type to retrieve
  /// @return Service instance of type T
  /// @throws Exception if service is not registered
  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }
    return service as T;
  }

  /// @brief Register a service instance
  /// @tparam T The service type
  /// @param service The service instance to register
  void register<T>(T service) {
    _services[T] = service;
  }
}

/// @brief Global service locator instance
/// @details Use sl.get<ServiceType>() to retrieve services throughout the app
final sl = ServiceLocator();

/// @brief Initialize and register all application dependencies
/// @details This function must be called before the app starts. It:
/// 1. Initializes SharedPreferences for storage
/// 2. Creates LocalStorageService with SharedPreferences
/// 3. Creates all service instances with their dependencies
/// 4. Loads persisted data from storage into each service
/// 5. Registers all services in the service locator
/// @return Future that completes when all services are initialized
Future<void> setupDependencies() async {
  // Initialize SharedPreferences (works on all platforms)
  final sharedPreferences = await SharedPreferences.getInstance();

  // Create storage service with SharedPreferences
  final localStorage = LocalStorageService(sharedPreferences);

  // Register core infrastructure services
  sl.register<SharedPreferences>(sharedPreferences);
  sl.register<LocalStorageService>(localStorage);

  // Create services with storage support (these services need persistence)
  final userService = UserService(localStorage);
  final authService = AuthService(localStorage, userService);
  final trainingService = TrainingService(localStorage);
  final goalService = GoalService(localStorage);
  final measurementService = MeasurementService(localStorage);
  final stepsService = StepsService(localStorage);

  // Initialize data from storage into each service
  // This loads persisted data from previous sessions
  await userService.loadFromStorage();
  await authService.loadFromStorage();
  await trainingService.loadFromStorage();
  await goalService.loadFromStorage();
  await measurementService.loadFromStorage();
  await stepsService.loadFromStorage();

  // Register all services in the service locator
  sl.register<AuthService>(authService);
  sl.register<UserService>(userService);
  sl.register<TrainingService>(trainingService);
  sl.register<NutritionService>(NutritionService());
  sl.register<ExerciseLibraryService>(ExerciseLibraryService());
  sl.register<TemplateService>(TemplateService());
  sl.register<ExerciseHistoryService>(ExerciseHistoryService());
  sl.register<MeasurementService>(measurementService);
  sl.register<HealthService>(HealthService());
  sl.register<StepsService>(stepsService);
  sl.register<GoalService>(goalService);
}