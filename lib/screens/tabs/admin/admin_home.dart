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

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Администратор'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Пользователи'),
            Tab(text: 'Магазины'),
            Tab(text: 'Привязки'),
            Tab(text: 'Товары'),
            Tab(text: 'Поставки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UsersTab(),
          StoresTab(),
          AssignmentsTab(),
          ProductsAdminTab(),
          DeliveriesAdminTab(),
        ],
      ),
    );
  }
}

// 1. Вкладка Пользователи
// Вкладка Пользователи (внутри AdminHome)
class UsersTab extends StatefulWidget {
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return const Center(child: Text('Нет пользователей'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userId = user['id'] as String;
        final mail = user['mail'] as String? ?? 'Нет email';
        final currentRole = user['role'] as String? ?? 'supplier';
        final username = user['username'] as String?;

        return ListTile(
          leading: CircleAvatar(
            child: Text(mail[0].toUpperCase()),
          ),
          title: Text(mail),
          subtitle: Text('Роль: $currentRole${username != null ? ' • $username' : ''}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value.toString().startsWith('role_')) {
                final role = value.toString().substring(5);
                updateRole(userId, role);
              } else if (value == 'delete') {
                deleteUser(userId);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'role_supplier', child: Text('Поставщик')),
              const PopupMenuItem<String>(value: 'role_storage', child: Text('Кладовщик')),
              const PopupMenuItem<String>(value: 'role_hall', child: Text('Менеджер зала')),
              const PopupMenuItem<String>(value: 'role_admin', child: Text('Администратор')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Удалить пользователя', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 2. Вкладка Магазины
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
    final response = await Supabase.instance.client.from('stores').select('name');
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
    if (loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Название магазина'))),
              IconButton(onPressed: addStore, icon: const Icon(Icons.add)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return ListTile(
                title: Text(store),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteStore(store),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 3. Вкладка Привязки
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

    final assignResp = await supa.from('store_assignments').select('user_id, store_name');
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
    await Supabase.instance.client.from('store_assignments').insert({'user_id': userId, 'store_name': storeName});
    loadData();
  }

  Future<void> unassign(String userId, String storeName) async {
    await Supabase.instance.client.from('store_assignments').delete().eq('user_id', userId).eq('store_name', storeName);
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userAssignments = assignments.where((a) => a['user_id'] == user['id']).toList();

        return ExpansionTile(
          title: Text(user['mail']),
          children: [
            ...userAssignments.map((a) => ListTile(
                  title: Text(a['store_name']),
                  trailing: IconButton(icon: const Icon(Icons.remove), onPressed: () => unassign(user['id'], a['store_name'])),
                )),
            ListTile(
              title: const Text('Добавить магазин'),
              onTap: () {
                String? selected;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Выберите магазин'),
                    content: DropdownButton<String>(
                      value: selected,
                      items: stores.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => selected = v,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                      ElevatedButton(
                        onPressed: selected == null ? null : () {
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
        );
      },
    );
  }
}

// 4. Вкладка Товары (админ)
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
    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return ListTile(
          title: Text(p['name']),
          subtitle: Text('Страна: ${p['country']} • Цена: ${p['price']}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => deleteProduct(p['id']),
          ),
        );
      },
    );
  }
}

// 5. Вкладка Поставки (админ)
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

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final d = deliveries[index];
        return ListTile(
          title: Text('Поставка #${d['id']} → ${d['store_name']}'),
          subtitle: Text('Статус: ${d['status']} • ${d['created_at']}'),
        );
      },
    );
  }
}