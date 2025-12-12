import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart'; // Экран входа
import 'screens/tabs/supplier/supplier_home.dart'; // Домашний экран поставщика
import 'screens/tabs/hall/hall_home.dart'; // Домашний экран менеджера зала
import 'screens/tabs/storage/storage_home.dart'; // Домашний экран склада
import 'screens/tabs/admin/admin_home.dart'; // Раскомментировать, когда добавишь админа

import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем .env файл (SUPABASE_URL и SUPABASE_ANON_KEY)
  await dotenv.load(fileName: ".env");

  // Инициализация Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // Опционально: включаем отладку в dev
    // debug: true,
  );

  runApp(
    DevicePreview(
      // Включаем только в debug-режиме (чтобы в продакшене не попало)
      enabled: !bool.fromEnvironment('dart.vm.product'),
      builder: (context) => const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Widget _currentScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();

    // Первичная проверка при запуске
    _determineStartScreen();

    // Подписываемся на изменения авторизации (login, logout, session refresh)
    _authService.authStateStream.listen((_) {
      if (mounted) {
        _determineStartScreen();
      }
    });
  }

  Future<void> _determineStartScreen() async {
    final user = _authService.currentUser;

    if (user == null) {
      // Не авторизован → экран логина
      if (mounted) {
        setState(() {
          _currentScreen = const LoginScreen();
        });
      }
      return;
    }

    // Авторизован → загружаем профиль
    final profile = await _authService.getProfile();

    if (profile == null || !mounted) {
      // Профиль не найден (редкий случай) → возвращаем на логин
      setState(() {
        _currentScreen = const LoginScreen();
      });
      return;
    }

    // Определяем домашний экран по роли
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
        // Неизвестная роль → на логин (или можно сделать отдельный экран ошибки)
        homeScreen = const LoginScreen();
    }

    if (mounted) {
      setState(() {
        _currentScreen = homeScreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D&F',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true, // ← важно для DevicePreview
      locale: DevicePreview.locale(context), // ← важно
      builder: DevicePreview.appBuilder, // ← важно (включает оверлеи)
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: _currentScreen,
    );
  }
}
