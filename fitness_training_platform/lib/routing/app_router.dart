import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/trainer/presentation/pages/trainer_dashboard_page.dart';
import '../features/trainer/presentation/pages/templates_page.dart';
import '../features/trainee/presentation/pages/trainee_dashboard_page.dart';
import 'route_names.dart';

class AppRouter {
  static GoRouter get router => _router;

  static final _router = GoRouter(
    initialLocation: RouteNames.login,
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.trainerDashboard,
        builder: (context, state) => const TrainerDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.traineeDashboard,
        builder: (context, state) => const TraineeDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.templates,
        builder: (context, state) => const TemplatesPage(),
      ),
    ],
  );
}