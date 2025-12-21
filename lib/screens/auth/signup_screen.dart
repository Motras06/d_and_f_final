import 'package:flutter/material.dart';
import 'package:d_and_f_final/screens/auth/role_select_screen.dart';

import '../../models/role_model.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';

import '../../screens/tabs/supplier/supplier_home.dart';
import '../../screens/tabs/hall/hall_home.dart';
import '../../screens/tabs/storage/storage_home.dart';
import '../../screens/tabs/admin/admin_home.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  AppRole? _selectedRole;
  bool _loading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _authService = AuthService();

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введите email';
    final email = v.trim();
    if (!email.contains('@') || !email.contains('.') || email.endsWith('.') || email.startsWith('@')) {
      return 'Неверный формат email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Введите пароль';
    if (v.length < 8) return 'Минимум 8 символов';
    if (v.length > 12) return 'Максимум 12 символов';
    return null;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _selectRole() async {
    final role = await Navigator.push<AppRole>(
      context,
      MaterialPageRoute(
        builder: (_) => const RoleSelectScreen(),
        fullscreenDialog: true,
      ),
    );
    if (role != null && mounted) {
      setState(() => _selectedRole = role);
    }
  }

  void _navigateToHome(Profile profile) {
    Widget homeScreen;
    switch (profile.role) {
      case 'supplier':
        homeScreen = SupplierHome(profile: profile);
        break;
      case 'hall':
        homeScreen = HallHome(profile: profile);
        break;
      case 'storage':
        homeScreen = StorageHome(profile: profile);
        break;
      case 'admin':
        homeScreen = AdminHome(profile: profile);
        break;
      default:
        homeScreen = SupplierHome(profile: profile);
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => homeScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите роль')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final error = await _authService.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
      role: _selectedRole!,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final profile = await _authService.getProfile();

    if (!mounted) return;

    if (profile != null) {
      _navigateToHome(profile);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль не найден после регистрации'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 12.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            size: 80.0,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 24.0),
                          Text(
                            'Создание аккаунта',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _selectRole,
                              icon: Icon(_selectedRole == null ? Icons.person_outline : Icons.check_circle),
                              label: Text(
                                _selectedRole == null ? 'Выберите роль' : 'Роль: ${_selectedRole!.name}',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Имя (необязательно)',
                              prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.1),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16.0),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            maxLength: 12,
                            decoration: InputDecoration(
                              labelText: 'Пароль (8–12 символов)',
                              prefixIcon: Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    key: ValueKey(_obscurePassword),
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.1),
                              counterText: '',
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 32.0),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                                elevation: 4.0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text(
                                      'Зарегистрироваться',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}