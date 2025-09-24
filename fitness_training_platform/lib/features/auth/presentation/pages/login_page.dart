import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/common/custom_button.dart';
import '../../../../shared/widgets/common/custom_text_field.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../routing/route_names.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 24),
                Text(
                  'Fitness Training Platform',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6C63FF),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    // Listen for authentication changes
                    if (authProvider.isAuthenticated) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _navigateToCorrectDashboard(authProvider.currentUser?.role);
                      });
                    }

                    if (authProvider.error != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(authProvider.error!),
                            backgroundColor: Colors.red,
                          ),
                        );
                        authProvider.clearError();
                      });
                    }

                    return CustomButton(
                      text: 'Login',
                      onPressed: () => _login(context),
                      isLoading: authProvider.isLoading,
                      icon: Icons.login,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
Text(
  'Demo Accounts:',
  style: Theme.of(context).textTheme.titleMedium,
  textAlign: TextAlign.center,
),
const SizedBox(height: 8),
_buildDemoAccountButton('Admin', 'admin@fitness.com'),
_buildDemoAccountButton('Trainer', 'trainer@fitness.com'),
_buildDemoAccountButton('Trainee (Jane)', 'trainee@fitness.com'),
const SizedBox(height: 8),
const Text(
  'Individual Trainees:',
  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
  textAlign: TextAlign.center,
),
const SizedBox(height: 4),
_buildDemoAccountButton('John Doe', 'john.doe@fitness.com'),
_buildDemoAccountButton('Jane Smith', 'jane.smith@fitness.com'),
_buildDemoAccountButton('Mike Johnson', 'mike.johnson@fitness.com'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoAccountButton(String role, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CustomButton(
        text: 'Login as $role',
        onPressed: () => _loginDemo(email),
        isOutlined: true,
        icon: Icons.person,
      ),
    );
  }

  void _login(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      _performLogin(_emailController.text, _passwordController.text);
    }
  }

  void _loginDemo(String email) {
    _emailController.text = email;
    _passwordController.text = 'password123';
    _performLogin(email, 'password123');
  }

  void _performLogin(String email, String password) async {
    print('Attempting login with: $email'); // Debug print
    
    final authProvider = context.read<AuthProvider>();
    await authProvider.login(email, password);
    
    print('Login completed. Authenticated: ${authProvider.isAuthenticated}'); // Debug print
    print('User role: ${authProvider.currentUser?.role}'); // Debug print
  }

  void _navigateToCorrectDashboard(UserRole? role) {
    print('Navigating to dashboard for role: $role'); // Debug print
    
    switch (role) {
      case UserRole.admin:
        context.go(RouteNames.adminDashboard);
        break;
      case UserRole.trainer:
        context.go(RouteNames.trainerDashboard);
        break;
      case UserRole.trainee:
        context.go(RouteNames.traineeDashboard);
        break;
      default:
        print('Unknown role or null role: $role');
    }
  }
}