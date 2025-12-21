// lib/screens/tabs/admin/admin_home.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'package:d_and_f_final/services/auth_service.dart';
import 'package:d_and_f_final/screens/auth/login_screen.dart';

class AdminHome extends StatefulWidget {
  final Profile profile;
  const AdminHome({super.key, required this.profile});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (context.mounted) {
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
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('D&F'),
        backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.9),
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => _logout(context),
            splashRadius: 24,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Пользователи'),
            Tab(text: 'Магазины'),
            Tab(text: 'Привязки'),
            Tab(text: 'Товары'),
            Tab(text: 'Поставки'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Градиентный фон
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

          // Контент табов с анимацией
          TabBarView(
            controller: _tabController,
            children: [
              UsersTab(),
              StoresTab(),
              AssignmentsTab(),
              ProductsAdminTab(),
              DeliveriesAdminTab(),
            ],
          ),
        ],
      ),
    );
  }
}

// 1. Вкладка Пользователи — премиум дизайн
class UsersTab extends StatefulWidget {
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    loadUsers();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    final response = await Supabase.instance.client.from('profiles').select();
    setState(() {
      users = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  Future<void> updateRole(String userId, String newRole) async {
    await Supabase.instance.client
        .from('profiles')
        .update({'role': newRole})
        .eq('id', userId);
    loadUsers();
  }

  Future<void> deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('profiles').delete().eq('id', userId);
      loadUsers();
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'supplier':
        return 'Поставщик';
      case 'storage':
        return 'Кладовщик';
      case 'hall':
        return 'Менеджер зала';
      case 'admin':
        return 'Администратор';
      default:
        return role;
    }
  }

  Color _roleColor(String role, ThemeData theme) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'storage':
        return Colors.blue;
      case 'hall':
        return Colors.green;
      case 'supplier':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 100, color: Colors.grey[600]),
            const SizedBox(height: 24),
            const Text(
              'Нет пользователей',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final userId = user['id'] as String;
          final mail = user['mail'] as String? ?? 'Нет email';
          final currentRole = user['role'] as String? ?? 'supplier';
          final username = user['username'] as String?;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 16),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: theme.cardColor,
              shadowColor: theme.shadowColor.withOpacity(0.3),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    mail[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(
                  mail,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(_roleLabel(currentRole)),
                      backgroundColor: _roleColor(
                        currentRole,
                        theme,
                      ).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _roleColor(currentRole, theme),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (username != null) Text('Имя: $username'),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 32),
                  onSelected: (value) {
                    if (value.startsWith('role_')) {
                      updateRole(userId, value.substring(5));
                    } else if (value == 'delete') {
                      deleteUser(userId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'role_supplier',
                      child: Text('Поставщик'),
                    ),
                    const PopupMenuItem(
                      value: 'role_storage',
                      child: Text('Кладовщик'),
                    ),
                    const PopupMenuItem(
                      value: 'role_hall',
                      child: Text('Менеджер зала'),
                    ),
                    const PopupMenuItem(
                      value: 'role_admin',
                      child: Text('Администратор'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Удалить',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 2. Вкладка Магазины — премиум
class StoresTab extends StatefulWidget {
  @override
  State<StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<StoresTab> {
  List<String> stores = [];
  final TextEditingController _controller = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  Future<void> loadStores() async {
    final response = await Supabase.instance.client
        .from('stores')
        .select('name');
    setState(() {
      stores = response.map((e) => e['name'] as String).toList();
      loading = false;
    });
  }

  Future<void> addStore() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await Supabase.instance.client.from('stores').insert({'name': name});
    _controller.clear();
    loadStores();
  }

  Future<void> deleteStore(String name) async {
    await Supabase.instance.client.from('stores').delete().eq('name', name);
    loadStores();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading)
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Новый магазин...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    onPressed: addStore,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Icon(
                      Icons.store_mall_directory,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(store, style: theme.textTheme.titleLarge),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                        size: 32,
                      ),
                      onPressed: () => deleteStore(store),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 3. Вкладка Привязки — премиум
class AssignmentsTab extends StatefulWidget {
  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  List<Map<String, dynamic>> assignments = [];
  List<String> stores = [];
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final supa = Supabase.instance.client;

    final assignResp = await supa
        .from('store_assignments')
        .select('user_id, store_name');
    final storesResp = await supa.from('stores').select('name');
    final usersResp = await supa.from('profiles').select('id, mail');

    setState(() {
      assignments = List<Map<String, dynamic>>.from(assignResp);
      stores = (storesResp as List).map((e) => e['name'] as String).toList();
      users = List<Map<String, dynamic>>.from(usersResp);
      loading = false;
    });
  }

  Future<void> assignStore(String userId, String storeName) async {
    await Supabase.instance.client.from('store_assignments').insert({
      'user_id': userId,
      'store_name': storeName,
    });
    loadData();
  }

  Future<void> unassign(String userId, String storeName) async {
    await Supabase.instance.client
        .from('store_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('store_name', storeName);
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading)
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userAssignments = assignments
            .where((a) => a['user_id'] == user['id'])
            .toList();

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              child: Text((user['mail'] as String)[0].toUpperCase()),
            ),
            title: Text(user['mail'], style: theme.textTheme.titleLarge),
            children: [
              ...userAssignments.map(
                (a) => ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(a['store_name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () => unassign(user['id'], a['store_name']),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_link, color: Colors.green),
                title: const Text('Привязать магазин'),
                onTap: () async {
                  String? selected = stores.firstOrNull;
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Выберите магазин'),
                      content: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        items: stores
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => selected = v,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  assignStore(user['id'], selected!);
                                },
                          child: const Text('Привязать'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// 4. Вкладка Товары (админ) — премиум
class ProductsAdminTab extends StatefulWidget {
  @override
  State<ProductsAdminTab> createState() => _ProductsAdminTabState();
}

class _ProductsAdminTabState extends State<ProductsAdminTab> {
  List<Map<String, dynamic>> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, name, country, price, created_by');
    setState(() {
      products = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  Future<void> deleteProduct(int id) async {
    await Supabase.instance.client.from('products').delete().eq('id', id);
    loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading)
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: Icon(
                Icons.inventory_2,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              title: Text(p['name'], style: theme.textTheme.titleLarge),
              subtitle: Text('Страна: ${p['country']} • Цена: ${p['price']} ₽'),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 32,
                ),
                onPressed: () => deleteProduct(p['id']),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 5. Вкладка Поставки (админ) — премиум
class DeliveriesAdminTab extends StatefulWidget {
  @override
  State<DeliveriesAdminTab> createState() => _DeliveriesAdminTabState();
}

class _DeliveriesAdminTabState extends State<DeliveriesAdminTab> {
  List<Map<String, dynamic>> deliveries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDeliveries();
  }

  Future<void> loadDeliveries() async {
    final response = await Supabase.instance.client
        .from('deliveries')
        .select('id, store_name, status, created_at')
        .order('created_at', ascending: false);

    setState(() {
      deliveries = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'accepted':
        return 'Принята';
      case 'rejected':
        return 'Отклонена';
      default:
        return status;
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading)
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final d = deliveries[index];
        final status = d['status'] as String;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: Icon(
                Icons.local_shipping,
                size: 40,
                color: _statusColor(status, theme),
              ),
              title: Text(
                'Поставка #${d['id']} → ${d['store_name']}',
                style: theme.textTheme.titleLarge,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(_statusLabel(status)),
                    backgroundColor: _statusColor(
                      status,
                      theme,
                    ).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _statusColor(status, theme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Дата: ${d['created_at']}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
