import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';

import 'products_tab.dart';
import 'camera_tab.dart';
import 'profile_tab.dart';
import '../../settings/settings_screen.dart';

class HallHome extends StatefulWidget {
  final Profile profile;
  const HallHome({super.key, required this.profile});

  @override
  State<HallHome> createState() => _HallHomeState();
}

class _HallHomeState extends State<HallHome>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _pages = [
      ProductsTab(profile: widget.profile),
      const CameraTab(),
      ProfileTab(profile: widget.profile),
    ];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SettingsScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('D&F'),
        backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.9),
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            onPressed: _openSettings,
            splashRadius: 24,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        theme.colorScheme.background,
                        theme.colorScheme.background.withOpacity(0.8),
                      ]
                    : [Colors.blue[50]!, Colors.white],
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Padding(
              key: ValueKey<int>(_selectedIndex),
              padding: const EdgeInsets.only(top: 5.0),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        backgroundColor: theme.colorScheme.surface,
        elevation: 12,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_outlined),
            activeIcon: Icon(Icons.inventory, color: theme.colorScheme.primary),
            label: 'Товары',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(
              Icons.camera_alt,
              color: theme.colorScheme.primary,
            ),
            label: 'Камера',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, color: theme.colorScheme.primary),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
