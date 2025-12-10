import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/role_select_screen.dart';
import 'services/local_storage.dart';
import 'screens/hall_home.dart';
import 'screens/supplier_home.dart';
import 'screens/storage_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
  Widget? _startScreen;

  @override
  void initState() {
    super.initState();
    _determineStartScreen();
  }

  Future<void> _determineStartScreen() async {
    final saved = await AppLocalStorage.getSavedAccount();
    Widget screen;
    if (saved != null) {
      final role = saved['role'];
      switch (role) {
        case 'user':
          screen = HallHome(username: saved['username'] ?? 'User');
          break;
        case 'storekeeper':
          screen = StorageHome(username: saved['username'] ?? 'Storekeeper');
          break;
        case 'supplier':
          screen = SupplierHome(username: saved['username'] ?? 'Supplier');
          break;
        default:
          screen = const RoleSelectScreen();
      }
    } else {
      screen = const RoleSelectScreen();
    }

    setState(() => _startScreen = screen);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D&F',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          _startScreen ??
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      debugShowCheckedModeBanner: false,
    );
  }
}
