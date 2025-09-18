// ==================== lib/shared/providers/auth_provider.dart ====================
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../core/dependency_injection/injection_container.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = sl.get<AuthService>();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.login(email, password);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> register(String name, String email, String password, UserRole role) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.register(name, email, password, role);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}