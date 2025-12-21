import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:d_and_f_final/services/theme_service.dart';
import 'package:d_and_f_final/screens/settings/assign_stores_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Уведомления'),
            onTap: () {
              // TODO
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Язык'),
            subtitle: const Text('Русский'),
            onTap: () {
              // TODO
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
            leading: const Icon(Icons.link),
            title: const Text('Закрепление магазинов'),
            subtitle: const Text('Привязка пользователей к магазинам'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssignStoresScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}