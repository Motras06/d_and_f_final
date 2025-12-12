// role_select_screen.dart
// (Minor changes: Update role strings to match DB - 'storage' becomes 'storekeeper' in navigation, but keep UI labels)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import '../models/roles.dart';
import 'auth_screen.dart';
import '../app_colors.dart';

class RoleItem {
  final Role role;
  final String title;
  final IconData icon;

  RoleItem(this.role, this.title, this.icon);
}

final List<RoleItem> _roleItems = [
  // RoleItem(Role.user, 'Пользователь', Icons.person_outline),
  // RoleItem(Role.storage, 'Склад', Icons.inventory_2_outlined),
  // RoleItem(Role.supplier, 'Поставщик', Icons.local_shipping_outlined),
];

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final RoleItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 8.0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.9)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primaryLight,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 30,
                    color: isSelected
                        ? AppColors.surface
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.surface
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  //Role? _selectedRole;
  late AnimationController _animationController;

  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // void _selectRole(Role role) {
  //   setState(() {
  //     HapticFeedback.lightImpact();
  //     // _selectedRole = role;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('D&F'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: AppColors.surface,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'D&F',
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 60,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Добро пожаловать!',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Выберите вашу роль:',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                      //   crossAxisAlignment: CrossAxisAlignment.start,
                      //   children: _roleItems.map((item) {
                      //     return _RoleButton(
                      //       item: item,
                      //       isSelected: _selectedRole == item.role,
                      //       onTap: () => _selectRole(item.role),
                      //     );
                      //   }).toList(),
                      // ),
                      const SizedBox(height: 20),
                      // ElevatedButton(
                      //   onPressed: _selectedRole == null
                      //       ? null
                      //       : () {
                      //           HapticFeedback.mediumImpact();
                      //           Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (_) => AuthScreen(
                      //                 role: roleToString(_selectedRole!),
                      //                 isRegister: false,
                      //               ),
                      //             ),
                      //           );
                      //         },
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: AppColors.primary,
                      //     foregroundColor: AppColors.surface,
                      //     padding: const EdgeInsets.symmetric(vertical: 14.0),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(12.0),
                      //     ),
                      //     elevation: 5,
                      //   ),
                      //   child: const Text(
                      //     'Авторизация',
                      //     style: TextStyle(
                      //       fontSize: 16,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 12),
                      // OutlinedButton(
                      //   onPressed: _selectedRole == null
                      //       ? null
                      //       : () {
                      //           HapticFeedback.mediumImpact();
                      //           Navigator.push(
                      //             context,
                      //             MaterialPageRoute(
                      //               builder: (_) => AuthScreen(
                      //                 role: roleToString(_selectedRole!),
                      //                 isRegister: true,
                      //               ),
                      //             ),
                      //           );
                      //         },
                      //   style: OutlinedButton.styleFrom(
                      //     foregroundColor: AppColors.primary,
                      //     side: BorderSide(
                      //       color: _selectedRole == null
                      //           ? Colors.grey
                      //           : AppColors.primary,
                      //       width: 2,
                      //     ),
                      //     padding: const EdgeInsets.symmetric(vertical: 14.0),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(12.0),
                      //     ),
                      //   ),
                      //   child: const Text(
                      //     'Регистрация',
                      //     style: TextStyle(
                      //       fontSize: 16,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}