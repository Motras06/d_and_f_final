import 'package:flutter/material.dart';
import '/app_colors.dart';

class StorageProfileTab extends StatelessWidget {
  final bool isLoadingProfile;
  final String? mail;
  final String? passwordMasked;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onUpdateProfile;
  final VoidCallback onLogout;

  const StorageProfileTab({
    super.key,
    required this.isLoadingProfile,
    required this.mail,
    required this.passwordMasked,
    required this.usernameController,
    required this.passwordController,
    required this.onUpdateProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 100),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 60, color: AppColors.surface),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 200),
            child: Card(
              elevation: 2,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                    title: Text(mail ?? 'Email не найден'),
                    subtitle: const Text('Email (нельзя изменить'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: AppColors.primary),
                    title: Text(passwordMasked ?? 'Пароль не задан'),
                    subtitle: const Text('Текущий пароль'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 300),
            child: TextFormField(
              controller: usernameController,
              decoration: _buildInputDecoration(
                labelText: 'Имя пользователя',
                icon: Icons.person_outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 400),
            child: TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: _buildInputDecoration(
                labelText: 'Новый пароль (необязательно)',
                icon: Icons.vpn_key_outlined,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 500),
            child: ElevatedButton.icon(
              onPressed: onUpdateProfile,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить изменения'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 600),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Выйти из аккаунта'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppColors.primaryLight),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 2.0),
      ),
    );
  }
}

// Вынесем _FadeInSlideUp сюда
class _FadeInSlideUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const _FadeInSlideUp({
    required this.child,
    this.delay = Duration.zero,
    // ignore: unused_element_parameter
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<_FadeInSlideUp> createState() => _FadeInSlideUpState();
}

class _FadeInSlideUpState extends State<_FadeInSlideUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}