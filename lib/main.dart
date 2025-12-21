// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/tabs/supplier/supplier_home.dart';
import 'screens/tabs/hall/hall_home.dart';
import 'screens/tabs/storage/storage_home.dart';
import 'screens/tabs/admin/admin_home.dart';

import 'screens/settings/app_colors.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем .env файл
  await dotenv.load(fileName: ".env");

  // Инициализируем Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MainApp());
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

    _determineStartScreen();

    _authService.authStateStream.listen((_) {
      if (mounted) {
        _determineStartScreen();
      }
    });
  }

  Future<void> _determineStartScreen() async {
    final user = _authService.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _currentScreen = const LoginScreen();
        });
      }
      return;
    }

    final profile = await _authService.getProfile();

    if (profile == null || !mounted) {
      setState(() {
        _currentScreen = const LoginScreen();
      });
      return;
    }

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
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'D&F',
            debugShowCheckedModeBanner: false,
            theme: AppColors.light,
            darkTheme: AppColors.dark,
            themeMode: themeService.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: _currentScreen,
          );
        },
      ),
    );
  }
}
