// lib/screens/auth/signup_screen.dart

import 'package:flutter/material.dart';
import '../../models/role_model.dart';
import '../../models/profile.dart';           // ← добавь импорт Profile
import '../../services/auth_service.dart';
import 'role_select_screen.dart';

import '../../screens/tabs/supplier/supplier_home.dart';
import '../../screens/tabs/hall/hall_home.dart';
import '../../screens/tabs/storage/storage_home.dart';
import '../../screens/tabs/admin/admin_home.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  AppRole? _selectedRole;
  bool _loading = false;
  final _authService = AuthService();

  // Валидация (оставляем как есть)
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
    return null;
  }

  Future<void> _selectRole() async {
    final role = await Navigator.push<AppRole>(
      context,
      MaterialPageRoute(
        builder: (_) => const RoleSelectScreen(),
        fullscreenDialog: true,
      ),
    );
    if (role != null) {
      setState(() => _selectedRole = role);
    }
  }

  // ← НОВАЯ ФУНКЦИЯ: переход на home по роли
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
        (_) => false, // удаляем все предыдущие экраны
      );
    }
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

    if (mounted) {
      setState(() => _loading = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }

      // ← УСПЕХ! Загружаем профиль и сразу переходим
      final profile = await _authService.getProfile();
      if (profile != null) {
        _navigateToHome(profile);
      }
    }
  }

  // dispose и build остаются без изменений
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // твой текущий build полностью остаётся тем же
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text('Регистрация', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _selectRole,
                      icon: Icon(_selectedRole == null ? Icons.person_outline : Icons.check),
                      label: Text(_selectedRole == null
                          ? 'Выберите роль'
                          : 'Роль: ${_selectedRole!.name}'),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя (необязательно)',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Зарегистрироваться'),
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
}