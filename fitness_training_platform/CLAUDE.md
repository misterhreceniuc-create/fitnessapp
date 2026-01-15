# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A comprehensive Flutter-based fitness training platform that connects trainers with trainees. The app supports three user roles (Admin, Trainer, Trainee) and manages workout creation, scheduling, tracking, and progress reporting.

## Essential Commands

### Development
```bash
# Run the app (default: starts on available device)
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d chrome
flutter run -d android

# Hot reload: Press 'r' in terminal while app is running
# Hot restart: Press 'R' in terminal while app is running

# Analyze code for issues
flutter analyze

# Format code
dart format .
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/widget_test.dart
```

### Build
```bash
# Build for Windows
flutter build windows

# Build for Android APK
flutter build apk

# Build for Android App Bundle
flutter build appbundle

# Build for web
flutter build web
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated
```

## Architecture

### State Management
- **Provider**: Used for global state (ThemeProvider, AuthProvider)
- **Riverpod**: Alternative state management (flutter_riverpod dependency present)
- State is managed at the service layer with in-memory mock data

### Navigation
- **go_router**: Declarative routing configured in `lib/routing/app_router.dart`
- Route names defined in `lib/routing/route_names.dart`
- Initial route: `/login`

### Dependency Injection
- Custom service locator pattern in `lib/core/dependency_injection/injection_container.dart`
- All services registered via `setupDependencies()` called in `main.dart`
- Access services using `sl.get<ServiceType>()`

### Feature Structure
```
lib/
├── core/                       # Core functionality (DI)
├── features/                   # Feature modules
│   ├── admin/                  # Admin dashboard
│   ├── auth/                   # Login/registration
│   ├── trainer/                # Trainer-specific features
│   │   ├── presentation/
│   │   │   ├── pages/          # Trainer dashboard, templates page
│   │   │   └── widgets/        # Workout creation wizard, dialogs
│   ├── trainee/                # Trainee-specific features
│   │   └── presentation/
│   │       ├── pages/          # Trainee dashboard
│   │       └── widgets/        # Workout session, bulk workout dialogs
│   └── workout/                # Workout domain logic
│       └── data/               # Models and services
├── shared/                     # Shared across features
│   ├── models/                 # Data models (User, Training, etc.)
│   ├── services/               # Business logic services
│   ├── providers/              # Global state providers
│   └── widgets/                # Reusable UI components
├── themes/                     # App theming
└── routing/                    # Navigation configuration
```

### Key Services (lib/shared/services/)
- **AuthService**: Mock authentication, user management
- **UserService**: User data operations
- **TrainingService**: Workout CRUD operations
- **ExerciseLibraryService**: Pre-defined exercise templates
- **TemplateService**: Workout template management
- **ExerciseHistoryService**: Exercise tracking and history
- **NutritionService**: Nutrition planning

### Core Data Models (lib/shared/models/)
- **UserModel**: Represents users with roles (admin/trainer/trainee)
  - Trainers have `traineeIds` list
  - Trainees have `trainerId` reference
- **TrainingModel**: Workout assignments with exercises, scheduling, recurrence
  - Contains `recurrenceGroupId`, `recurrenceIndex`, `totalRecurrences` for recurring workouts
- **ExerciseModel**: Individual exercises with sets, reps, weight tracking
  - Tracks `actualSets` (List<ActualSet>) for completed workouts
- **ExerciseTemplate**: Library of pre-defined exercises
- **WorkoutTemplate**: Reusable training programs
- **GoalModel**: User fitness goals
- **MeasurementModel**: Body measurements
- **NutritionModel**: Meal plans

### Important Patterns

#### Mock Data Pattern
All services use in-memory lists for mock data (e.g., `_mockTrainings`, `_mockUsers`). No database or API integration exists. Mock API delays simulate network calls:
```dart
await Future.delayed(const Duration(milliseconds: 500));
```

#### Authentication Flow
- Mock users defined in `AuthService._mockUsers`
- Login credentials: email matches mock user email (password not validated)
- Current user stored in SharedPreferences
- Default users:
  - Admin: admin@fitness.com
  - Trainer: trainer@fitness.com (ID: '2')
  - Trainees: trainee@fitness.com, john.doe@fitness.com, jane.smith@fitness.com, mike.johnson@fitness.com

#### Workout Creation Flow
1. Trainer selects creation mode (single/recurring/from template/bulk)
2. Fills workout details via `WorkoutCreationWizard`
3. Creates training via `TrainingService.createTraining()`
4. For recurring: creates multiple trainings with linked `recurrenceGroupId`

#### Workout Execution Flow (Trainee)
1. Trainee views assigned workouts in dashboard
2. Opens workout in `WorkoutSessionDialog`
3. Logs sets with actual reps/weight (ActualSet objects)
4. Completes workout, data saved to exercise history

## Common Development Patterns

### Adding a New Service
1. Create service class in `lib/shared/services/`
2. Register in `injection_container.dart`:
   ```dart
   sl.register<YourService>(YourService());
   ```
3. Access via `sl.get<YourService>()`

### Adding a New Route
1. Add route name constant in `lib/routing/route_names.dart`
2. Register route in `lib/routing/app_router.dart`:
   ```dart
   GoRoute(
     path: RouteNames.yourRoute,
     builder: (context, state) => YourPage(),
   )
   ```

### Working with Models
- All models have `fromJson()` and `toJson()` methods for serialization
- Use `copyWith()` methods for immutable updates
- Models in `lib/shared/models/` for cross-feature use
- Feature-specific models in `lib/features/{feature}/data/`

### Debugging
- Print statements used throughout (e.g., TrainingService has debug prints)
- Run `flutter doctor` to verify environment setup
- Use Flutter DevTools for debugging: `flutter run` then press 'v' for devtools URL

## Known Technical Debt

### Data Duplication
- `ExerciseModel` exists in both `lib/shared/models/training_model.dart` (lines 90-192) and `lib/features/workout/data/exercise_model.dart`
- Different `Exercise` class in `lib/features/workout/data/exercise_model.dart` (lines 20-54)

### Mock Data Limitations
- No persistence beyond SharedPreferences for current user
- All training/workout data lost on app restart
- Services maintain separate in-memory lists without synchronization

### Inconsistent Naming
- Mix of "Training" and "Workout" terminology (same concept)
- Some files use `data/presentation` structure, others use standard `presentation/pages`

## Testing Strategy

Tests located in `test/` directory. When writing tests:
- Mock services using service locator pattern
- Test widgets using `flutter_test` framework
- Consider testing navigation flows with go_router's test utilities
