import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Тёмная тема'),
            value: themeService.isDarkMode,
            onChanged: (value) {
              themeService.toggleTheme();
            },
          ),

          const Divider(),

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

          ListTile(
            leading: Icon(
              Icons.support_agent_rounded,
              color: colorScheme.primary,
            ),
            title: const Text('Связаться с администратором'),
            subtitle: const Text('Проблема, вопрос, предложение, баг'),
            onTap: () => _showSupportDialog(context),
          ),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Удалить мой аккаунт полностью',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Удалится профиль + аккаунт в Supabase навсегда',
            ),
            onTap: () => _confirmAndDeleteEverything(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Написать администратору'),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Опишите проблему, вопрос или предложение...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, напишите сообщение';
                }
                if (value.trim().length < 10) {
                  return 'Сообщение слишком короткое';
                }
                return null;
              },
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final message = controller.text.trim();
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await supabase.from('support_messages').insert({
        'user_id': userId,
        'message': message,
        'status': 'new',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сообщение отправлено администратору'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не авторизован')));
      }
      return;
    }

    try {
      final serviceRoleKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
        throw Exception('SUPABASE_ANON_KEY не найден в .env');
      }

      final adminClient = SupabaseClient(
        dotenv.env['SUPABASE_URL']!,
        serviceRoleKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: const EmptyLocalStorage(),
        ),
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
        },
      );

      await supabase.from('profiles').delete().eq('id', currentUser.id);

      await adminClient.auth.admin.deleteUser(currentUser.id);

      await supabase.auth.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аккаунт полностью удалён • выполнен выход'),
          ),
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить аккаунт: $e')),
        );
      }
    }
  }
}
