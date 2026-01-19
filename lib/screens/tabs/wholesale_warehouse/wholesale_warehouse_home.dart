import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';

import 'orders_tab.dart';          // Заказы
import 'distribution_tab.dart';   // Распределение
import 'accounting_tab.dart';     // Учёт
import 'profile_tab.dart';        // Профиль
import '../../settings/settings_screen.dart';

class WholesaleWarehouseHome extends StatefulWidget {
  final Profile profile;
  const WholesaleWarehouseHome({super.key, required this.profile});

  @override
  State<WholesaleWarehouseHome> createState() => _WholesaleWarehouseHomeState();
}

class _WholesaleWarehouseHomeState extends State<WholesaleWarehouseHome>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _pages = [
      const OrdersTab(),
      const DistributionTab(),
      const AccountingTab(),
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
      // НЕ используем extendBodyBehindAppBar — контент не должен лезть под AppBar
      appBar: AppBar(
        title: const Text('Оптовый склад • D&F'),
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
      body: SafeArea(  // ← главное исправление: контент не уходит под AppBar и системные вырезы
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [theme.colorScheme.background, theme.colorScheme.background.withOpacity(0.8)]
                      : [Colors.indigo[50]!, Colors.white],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: Padding(
                key: ValueKey<int>(_selectedIndex),
                padding: const EdgeInsets.only(top: 8.0), // небольшой отступ сверху для красоты
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_outlined),
            activeIcon: Icon(Icons.share),
            label: 'Распределение',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            activeIcon: Icon(Icons.calculate),
            label: 'Учёт',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}