import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';  // ← ЭТО ГЛАВНОЕ

class AdminHome extends StatelessWidget {
  final Profile profile;
  const AdminHome({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Администратор'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Добро пожаловать, Админ!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Email: ${profile.mail}'),
            Text('Роль: ${profile.role}'),
            if (profile.username != null) Text('Имя: ${profile.username}'),
          ],
        ),
      ),
    );
  }
}