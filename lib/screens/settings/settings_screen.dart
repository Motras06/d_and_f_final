// lib/screens/settings/settings_screen.dart

import 'package:d_and_f_final/screens/settings/assign_stores_screen.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('Тема приложения'),
            subtitle: const Text('Светлая / Тёмная'),
            onTap: () {
              // TODO: переключение темы
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Уведомления'),
            onTap: () {
              // TODO: настройки уведомлений
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Язык'),
            subtitle: const Text('Русский'),
            onTap: () {
              // TODO: выбор языка
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
