// auth_screen.dart
// (Rewritten to use Supabase auth and repository for profiles)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hall_home.dart';
import 'storage_home.dart';
import 'supplier_home.dart';
import '../services/local_storage.dart';
import '../app_colors.dart';
import '../repository.dart';

class AuthScreen extends StatefulWidget {
  final String role;
  final bool isRegister;
  const AuthScreen({required this.role, required this.isRegister, super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _loading = false;
  final _repo = SupabaseRepository();

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введите email';
    final email = v.trim();
    final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$');
    if (!emailRegex.hasMatch(email)) return 'Неверный формат email';
    final parts = email.split('@');
    if (parts.length != 2 || !parts[1].contains('.')) {
      return 'Неверный домен email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Введите пароль';
    if (v.length < 8) return 'Минимум 8 символов';
    if (v.length > 15) return 'Максимум 15 символов';
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введите имя';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _mailController.text.trim();
    final password = _passwordController.text;
    String role = widget.role;
    if (role == 'storage') role = 'storekeeper'; // Map to DB role
    // Note: Assuming 'user' is added to DB role check; if not, handle accordingly

    try {
      if (widget.isRegister) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.user != null) {
          // Create profile
          await Supabase.instance.client.from('profiles').insert({
            'id': response.user!.id,
            'mail': email,
            'username': _usernameController.text.trim(),
            'role': role,
          });
          await AppLocalStorage.saveAccount({
            'mail': email,
            'username': _usernameController.text.trim(),
            'role': widget.role, // Keep original for local
          });
          _goToRoleHome(_usernameController.text.trim(), widget.role);
        } else {
          _showError('Ошибка регистрации');
        }
      } else {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.user != null) {
          final profile = await _repo.getCurrentProfile();
          if (profile != null && (profile.role == role || (profile.role == 'storekeeper' && widget.role == 'storage'))) {
            await AppLocalStorage.saveAccount({
              'mail': email,
              'username': profile.username ?? 'User',
              'role': widget.role,
            });
            _goToRoleHome(profile.username ?? 'User', widget.role);
          } else {
            _showError('Неверная роль или профиль не найден');
          }
        } else {
          _showError('Ошибка авторизации');
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.surface)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goToRoleHome(String username, String role) {
    Widget screen;
    switch (role) {
      case 'user':
        screen = HallHome(username: username);
        break;
      case 'storage':
        screen = StorageHome(username: username);
        break;
      case 'supplier':
        screen = SupplierHome(username: username);
        break;
      default:
        screen = HallHome(username: username);
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => screen),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _mailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isRegister ? 'Регистрация' : 'Авторизация';
    final textTheme = Theme.of(context).textTheme;

    final delayUsername = const Duration(milliseconds: 200);
    final delayEmail = Duration(milliseconds: widget.isRegister ? 300 : 200);
    final delayPassword = Duration(milliseconds: widget.isRegister ? 400 : 300);
    final delayButton = Duration(milliseconds: widget.isRegister ? 500 : 400);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FadeInSlideUp(
                      delay: Duration.zero,
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeInSlideUp(
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: textTheme.headlineMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Вход для: ${widget.role}',
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.isRegister)
                      _FadeInSlideUp(
                        delay: delayUsername,
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: _buildInputDecoration(
                            labelText: 'Имя',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: _validateUsername,
                        ),
                      ),
                    if (widget.isRegister) const SizedBox(height: 16),
                    _FadeInSlideUp(
                      delay: delayEmail,
                      child: TextFormField(
                        controller: _mailController,
                        decoration: _buildInputDecoration(
                          labelText: 'Email',
                          icon: Icons.email_outlined,
                        ),
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeInSlideUp(
                      delay: delayPassword,
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: _buildInputDecoration(
                          labelText: 'Пароль',
                          icon: Icons.vpn_key_outlined,
                        ),
                        validator: _validatePassword,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FadeInSlideUp(
                      delay: delayButton,
                      child: _loading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.surface,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 2,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: Center(
                                  child: Text(
                                    widget.isRegister
                                        ? 'Зарегистрироваться'
                                        : 'Войти',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppColors.primaryLight),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 2.0),
      ),
    );
  }
}

class _FadeInSlideUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const _FadeInSlideUp({
    required this.child,
    this.delay = Duration.zero,
    // ignore: unused_element_parameter
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<_FadeInSlideUp> createState() => _FadeInSlideUpState();
}

class _FadeInSlideUpState extends State<_FadeInSlideUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}