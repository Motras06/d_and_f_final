import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          // Тёмная тема
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Тёмная тема'),
            value: themeService.isDarkMode,
            onChanged: (value) {
              themeService.toggleTheme();
            },
          ),

          const Divider(),

          // О приложении
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'D&F',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.local_shipping, size: 50),
              );
            },
          ),

          // Связаться с администратором (затычка)
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Связаться с администратором'),
            subtitle: const Text('Проблема / вопрос / баг'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Пока пиши в Telegram или на почту • в разработке'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),

          // УДАЛЕНИЕ АККАУНТА ПОЛНОСТЬЮ
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Удалить мой аккаунт полностью', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Удалится профиль + аккаунт в Supabase навсегда'),
            onTap: () => _confirmAndDeleteEverything(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteEverything(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Удалить аккаунт НАВСЕГДА?'),
      content: const Text(
        'Это тестовый проект → полное удаление:\n'
        '• профиль (public.profiles)\n'
        '• пользователь в auth.users\n\n'
        'После этого можно зарегистрироваться заново тем же email.\n\n'
        'Продолжить?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить всё'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;

  if (currentUser == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не авторизован')),
      );
    }
    return;
  }

  try {
    final serviceRoleKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY не найден в .env');
    }

    // Создаём чистый клиент ТОЛЬКО с service_role → без любой сессии
    final adminClient = SupabaseClient(
      dotenv.env['SUPABASE_URL']!,
      serviceRoleKey,
      authOptions: FlutterAuthClientOptions(
        // Самое важное: отключаем хранение/использование любой сессии
        localStorage: const EmptyLocalStorage(),
      ),
      // Явно переопределяем заголовки (на всякий случай)
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
      },
    );

    // 1. Удаляем профиль обычным клиентом (если RLS позволяет твоему пользователю)
    await supabase.from('profiles').delete().eq('id', currentUser.id);

    // 2. Удаляем пользователя из auth.users через admin-клиент
    await adminClient.auth.admin.deleteUser(currentUser.id);

    // 3. Выход из обычной сессии
    await supabase.auth.signOut();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аккаунт полностью удалён • выполнен выход')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  } catch (e) {
    debugPrint('Ошибка удаления: $e'); // ← смотри в консоль
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить аккаунт: $e')),
      );
    }
  }
}
}