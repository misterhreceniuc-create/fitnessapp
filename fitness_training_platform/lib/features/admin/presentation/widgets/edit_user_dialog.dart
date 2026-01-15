/// @file edit_user_dialog.dart
/// @brief Dialog widget for admin user editing
/// @details Provides a comprehensive form dialog for administrators to edit existing users,
/// including changing their role, updating credentials, and reassigning trainers for trainees.
/// Handles form validation, service integration, error display, and success feedback.

import 'package:flutter/material.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/user_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';

/// @class EditUserDialog
/// @brief Stateful dialog for editing existing users through admin operations
/// @details Displays a modal dialog with form fields for name, email, password (optional),
/// role selection, and conditional trainer assignment (for trainees only). Pre-populates
/// fields with existing user data and allows updating all fields except ID.
class EditUserDialog extends StatefulWidget {
  /// @brief The user to edit
  final UserModel user;

  /// @brief Optional callback triggered after successful user update
  /// @details Called when a user is successfully updated, allowing parent
  /// widgets to refresh their data or update UI state
  final VoidCallback? onUserUpdated;

  /// @brief Constructor for EditUserDialog
  /// @param user The user to edit
  /// @param onUserUpdated Optional callback for post-update actions
  const EditUserDialog({
    Key? key,
    required this.user,
    this.onUserUpdated,
  }) : super(key: key);

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

/// @class _EditUserDialogState
/// @brief State management for the EditUserDialog widget
/// @details Manages form state, text controllers, validation, service calls,
/// loading states, and trainer list retrieval. Pre-populates fields with
/// existing user data.
class _EditUserDialogState extends State<EditUserDialog> {
  /// @brief Form key for validation management
  final _formKey = GlobalKey<FormState>();

  /// @brief Text controller for name input field
  late final TextEditingController _nameController;

  /// @brief Text controller for email input field
  late final TextEditingController _emailController;

  /// @brief Text controller for password input field
  late final TextEditingController _passwordController;

  /// @brief Authentication service instance for user updates
  final AuthService _authService = sl.get<AuthService>();

  /// @brief User service instance for retrieving trainer list
  final UserService _userService = sl.get<UserService>();

  /// @brief Currently selected user role
  late UserRole _selectedRole;

  /// @brief Currently selected trainer ID (null if no trainer selected)
  String? _selectedTrainerId;

  /// @brief List of available trainers for assignment
  List<UserModel> _trainers = [];

  /// @brief Loading state flag to prevent double submissions
  bool _isLoading = false;

  /// @brief Password visibility toggle state
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with existing user data
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
    _selectedRole = widget.user.role;
    _selectedTrainerId = widget.user.trainerId;
    _loadTrainers();
  }

  @override
  void dispose() {
    // Clean up text controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// @brief Loads the list of trainers from UserService
  /// @details Asynchronously fetches all trainer users for the trainer assignment dropdown.
  /// Called during widget initialization. Handles errors silently to prevent dialog crash.
  Future<void> _loadTrainers() async {
    try {
      final trainers = await _userService.getTrainers();
      if (mounted) {
        setState(() {
          _trainers = trainers;
        });
      }
    } catch (e) {
      print('Error loading trainers: $e');
      // Silently fail - trainers list remains empty
    }
  }

  /// @brief Handles form submission and user update
  /// @details Validates all form fields, calls AuthService.updateUser(), handles errors,
  /// and provides user feedback via SnackBar. On success, closes the dialog and triggers
  /// the onUserUpdated callback. Prevents double submissions via loading state.
  /// If password field is empty, keeps the existing password.
  Future<void> _handleUpdateUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if email changed and validate uniqueness
    if (_emailController.text.trim() != widget.user.email) {
      final allUsers = _authService.getAllUsers();
      final existingUser = allUsers.where(
        (u) => u.email == _emailController.text.trim() && u.id != widget.user.id
      );
      if (existingUser.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Email already in use by another user'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Handle trainer assignment changes
      final oldTrainerId = widget.user.trainerId;
      final newTrainerId = _selectedRole == UserRole.trainee ? _selectedTrainerId : null;

      // Create updated user with new values
      final updatedUser = widget.user.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        trainerId: newTrainerId,
        // Only update password if a new one is provided
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : widget.user.password,
      );

      // If trainer assignment changed, handle the relationship updates
      if (oldTrainerId != newTrainerId) {
        await _updateTrainerAssignments(widget.user.id, oldTrainerId, newTrainerId);
      }

      // Update the user
      await _authService.updateUser(updatedUser);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User updated successfully: ${_nameController.text}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Close dialog and trigger callback
        Navigator.of(context).pop();
        widget.onUserUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// @brief Updates trainer-trainee relationships when trainer assignment changes
  /// @details Removes trainee from old trainer's list and adds to new trainer's list
  /// @param traineeId The ID of the trainee being reassigned
  /// @param oldTrainerId The previous trainer's ID (null if no previous trainer)
  /// @param newTrainerId The new trainer's ID (null if removing trainer)
  Future<void> _updateTrainerAssignments(
    String traineeId,
    String? oldTrainerId,
    String? newTrainerId,
  ) async {
    final allUsers = _authService.getAllUsers();

    // Remove from old trainer's list
    if (oldTrainerId != null) {
      final oldTrainer = allUsers.firstWhere((u) => u.id == oldTrainerId);
      final updatedTraineeIds = List<String>.from(oldTrainer.traineeIds ?? []);
      updatedTraineeIds.remove(traineeId);
      await _authService.updateUser(oldTrainer.copyWith(traineeIds: updatedTraineeIds));
    }

    // Add to new trainer's list
    if (newTrainerId != null) {
      final newTrainer = allUsers.firstWhere((u) => u.id == newTrainerId);
      final updatedTraineeIds = List<String>.from(newTrainer.traineeIds ?? []);
      if (!updatedTraineeIds.contains(traineeId)) {
        updatedTraineeIds.add(traineeId);
        await _authService.updateUser(newTrainer.copyWith(traineeIds: updatedTraineeIds));
      }
    }
  }

  /// @brief Validator for name field
  /// @details Ensures name is not empty and has at least 2 characters
  /// @param value The input value to validate
  /// @return Error message or null if valid
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// @brief Validator for email field
  /// @details Ensures email is not empty and matches basic email format regex
  /// @param value The input value to validate
  /// @return Error message or null if valid
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Basic email regex pattern
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// @brief Validator for password field
  /// @details Password is optional when editing (keeps existing if empty)
  /// If provided, must be at least 6 characters
  /// @param value The input value to validate
  /// @return Error message or null if valid
  String? _validatePassword(String? value) {
    // Password is optional when editing
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// @brief Returns an icon for a given user role
  /// @details Provides visual role identification with color-coded icons
  /// @param role The user role to get an icon for
  /// @return Icon widget with appropriate role representation
  Icon _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Icon(Icons.admin_panel_settings, color: Colors.red);
      case UserRole.trainer:
        return const Icon(Icons.fitness_center, color: Colors.blue);
      case UserRole.trainee:
        return const Icon(Icons.person, color: Colors.green);
    }
  }

  /// @brief Returns a helper text description for a given user role
  /// @details Provides context-sensitive guidance for each role type
  /// @param role The user role to get help text for
  /// @return Human-readable description of the role's capabilities
  String _getRoleHelperText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Full system access - can manage all users and settings';
      case UserRole.trainer:
        return 'Can create workouts and manage assigned trainees';
      case UserRole.trainee:
        return 'Receives workout assignments and tracks progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit User: ${widget.user.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Dialog Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter user\'s full name',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: _validateName,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'user@example.com',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password (leave empty to keep current)',
                          hintText: 'Enter new password or leave empty',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: _obscurePassword,
                        validator: _validatePassword,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),

                      // Role Selection
                      const Text(
                        'User Role',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserRole>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: UserRole.values.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Row(
                                  children: [
                                    _getRoleIcon(role),
                                    const SizedBox(width: 12),
                                    Text(
                                      role.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading
                                ? null
                                : (UserRole? newRole) {
                                    if (newRole != null) {
                                      setState(() {
                                        _selectedRole = newRole;
                                        // Reset trainer selection when role changes
                                        if (newRole != UserRole.trainee) {
                                          _selectedTrainerId = null;
                                        }
                                      });
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Role helper text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getRoleHelperText(_selectedRole),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Trainer Assignment (conditional for trainees)
                      if (_selectedRole == UserRole.trainee) ...[
                        const Text(
                          'Assign Trainer (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_trainers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'No trainers available in the system',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedTrainerId,
                                isExpanded: true,
                                hint: const Text('Select a trainer'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('No trainer (assign later)'),
                                  ),
                                  ..._trainers.map((trainer) {
                                    return DropdownMenuItem<String?>(
                                      value: trainer.id,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.fitness_center, size: 20),
                                          const SizedBox(width: 8),
                                          Text(trainer.name),
                                          const SizedBox(width: 8),
                                          Text(
                                            '(${trainer.email})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: _isLoading
                                    ? null
                                    : (String? trainerId) {
                                        setState(() {
                                          _selectedTrainerId = trainerId;
                                        });
                                      },
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleUpdateUser,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
