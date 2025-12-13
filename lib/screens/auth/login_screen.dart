// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/screens/auth/signup_screen.dart'; // для кнопки "Зарегистрироваться"

import '../../models/profile.dart';           // ← важно!
import '../../services/auth_service.dart';

import '../../screens/tabs/supplier/supplier_home.dart';
import '../../screens/tabs/hall/hall_home.dart';
import '../../screens/tabs/storage/storage_home.dart';
import '../../screens/tabs/admin/admin_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;

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
    return null;
  }

  // ← НОВАЯ ФУНКЦИЯ: переход на домашний экран по роли
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
        homeScreen = SupplierHome(profile: profile); // fallback
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => homeScreen),
        (route) => false, // очищаем весь стек — больше нет пути назад к логину
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final error = await _authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() => _loading = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ← УСПЕХ! Загружаем профиль и сразу переходим на нужный экран
      final profile = await _authService.getProfile();
      if (profile != null) {
        _navigateToHome(profile);
      } else {
        // Очень редкий случай — профиль не найден
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль не найден. Обратитесь к администратору.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      'Авторизация',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Войти',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text('Нет аккаунта? Зарегистрироваться'),
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
}