import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'package:d_and_f_final/services/auth_service.dart';
import 'package:d_and_f_final/screens/auth/login_screen.dart';

class ProfileTab extends StatefulWidget {
  final Profile profile;
  const ProfileTab({super.key, required this.profile});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _usernameController;
  bool _isEditingUsername = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Сохранение имени
  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername == widget.profile.username) {
      setState(() => _isEditingUsername = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'username': newUsername.isEmpty ? null : newUsername})
          .eq('id', widget.profile.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя обновлено!'), backgroundColor: Colors.green),
      );
      setState(() => _isEditingUsername = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Смена пароля
  Future<void> _changePassword() async {
    final supabase = Supabase.instance.client;
    final auth = supabase.auth;

    TextEditingController oldPassController = TextEditingController();
    TextEditingController newPassController = TextEditingController();
    TextEditingController confirmPassController = TextEditingController();

    bool oldPasswordCorrect = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Смена пароля'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!oldPasswordCorrect) ...[
                  TextField(
                    controller: oldPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Старый пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Подтвердите новый пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!oldPasswordCorrect) {
                        // Проверяем старый пароль
                        try {
                          await auth.signInWithPassword(
                            email: widget.profile.mail,
                            password: oldPassController.text,
                          );
                          setDialogState(() => oldPasswordCorrect = true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Старый пароль неверный'), backgroundColor: Colors.red),
                          );
                        }
                      } else {
                        // Меняем пароль
                        if (newPassController.text != confirmPassController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Пароли не совпадают'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (newPassController.text.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Новый пароль должен быть не менее 8 символов'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        try {
                          await auth.updateUser(UserAttributes(password: newPassController.text));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Пароль успешно изменён!'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка смены пароля: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: Text(oldPasswordCorrect ? 'Сменить' : 'Проверить'),
            ),
          ],
        ),
      ),
    );

    oldPassController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
  }

  // Выход из аккаунта
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Аватар
          CircleAvatar(
            radius: 70,
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            child: Text(
              _usernameController.text.isEmpty
                  ? widget.profile.mail[0].toUpperCase()
                  : _usernameController.text[0].toUpperCase(),
              style: TextStyle(fontSize: 60, color: theme.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 32),

          // Редактируемое имя
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: _isEditingUsername
                  ? TextField(
                      controller: _usernameController,
                      autofocus: true,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Введите имя'),
                    )
                  : Text(_usernameController.text.isEmpty ? 'Имя не указано' : _usernameController.text),
              trailing: IconButton(
                icon: Icon(_isEditingUsername ? Icons.check : Icons.edit_outlined),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_isEditingUsername) {
                          _saveUsername();
                        } else {
                          setState(() => _isEditingUsername = true);
                        }
                      },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Почта
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(widget.profile.mail),
            ),
          ),

          const SizedBox(height: 16),

          // Роль
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Роль'),
              subtitle: Text(widget.profile.role.toUpperCase()),
            ),
          ),

          const SizedBox(height: 32),

          // Кнопка смены пароля
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Сменить пароль'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: theme.primaryColor),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка выхода
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Выйти из аккаунта'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          if (_isLoading) const Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}