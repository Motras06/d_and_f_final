// lib/screens/tabs/supplier/supplier_home.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';

import 'my_products_tab.dart';
import 'deliveries_tab.dart';
import 'profile_tab.dart';
import '../../settings/settings_screen.dart';

class SupplierHome extends StatefulWidget {
  final Profile profile;
  const SupplierHome({super.key, required this.profile});

  @override
  State<SupplierHome> createState() => _SupplierHomeState();
}

class _SupplierHomeState extends State<SupplierHome> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _pages = [
      MyProductsTab(profile: widget.profile),
      NewDeliveryTab(profile: widget.profile),
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
    if (_selectedIndex == index) return; // не анимируем, если уже на этом табе

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
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
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
          )
        ],
      ),
      body: Stack(
        children: [
          // Фон с градиентом (для красоты)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [theme.colorScheme.background, theme.colorScheme.background.withOpacity(0.8)]
                    : [Colors.blue[50]!, Colors.white],
              ),
            ),
          ),

          // Контент таба с анимацией
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Padding(
              key: ValueKey<int>(_selectedIndex),
              padding: const EdgeInsets.only(top: 5.0), // отступ под AppBar
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
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box, color: theme.colorScheme.primary),
            label: 'Создать',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping, color: theme.colorScheme.primary),
            label: 'Поставки',
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