// lib/screens/tabs/storage/profile_tab.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';

class ProfileTab extends StatelessWidget {
  final Profile profile;
  const ProfileTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(
                profile.username?.substring(0, 1).toUpperCase() ?? profile.mail.substring(0, 1).toUpperCase(),
                style: TextStyle(fontSize: 48, color: Theme.of(context).primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              profile.username ?? 'Кладовщик',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(profile.mail, style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Chip(
              label: Text(profile.role.toUpperCase()),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }
}