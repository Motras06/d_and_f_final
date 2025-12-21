import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class AssignStoresScreen extends StatefulWidget {
  const AssignStoresScreen({super.key});

  @override
  State<AssignStoresScreen> createState() => _AssignStoresScreenState();
}

class _AssignStoresScreenState extends State<AssignStoresScreen> {
  List<Profile> _users = [];
  List<String> _allStores = [];
  Map<String, List<String>> _userStores = {}; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final usersResponse = await supabase.from('profiles').select('id, mail, username, role');

      final users = (usersResponse as List<dynamic>)
          .map((json) => Profile.fromJson(json as Map<String, dynamic>))
          .toList();

      final storesResponse = await supabase.from('stores').select('name').order('name');
      final stores = (storesResponse as List<dynamic>).map((e) => e['name'] as String).toList();

      final assignmentsResponse = await supabase.from('store_assignments').select('user_id, store_name');
      final Map<String, List<String>> assignments = {};
      for (final a in assignmentsResponse) {
        final userId = a['user_id'] as String;
        final store = a['store_name'] as String;
        assignments.putIfAbsent(userId, () => []).add(store);
      }

      setState(() {
        _users = users;
        _allStores = stores;
        _userStores = assignments;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignStore(String userId, String storeName) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('store_assignments').insert({
        'user_id': userId,
        'store_name': storeName,
      });

      setState(() {
        _userStores.putIfAbsent(userId, () => []).add(storeName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Магазин закреплён'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _unassignStore(String userId, String storeName) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('store_assignments')
          .delete()
          .eq('user_id', userId)
          .eq('store_name', storeName);

      setState(() {
        _userStores[userId]?.remove(storeName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Магазин отвязан'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAssignDialog(String userId, String userMail) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedStore;

        return AlertDialog(
          title: Text('Закрепить магазин за $userMail'),
          content: DropdownButtonFormField<String>(
            hint: const Text('Выберите магазин'),
            items: _allStores.map((store) {
              final isAssigned = _userStores[userId]?.contains(store) ?? false;
              return DropdownMenuItem(
                value: store,
                enabled: !isAssigned,
                child: Text(isAssigned ? '$store (уже закреплён)' : store),
              );
            }).toList(),
            onChanged: (value) => selectedStore = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: selectedStore == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      _assignStore(userId, selectedStore!);
                    },
              child: const Text('Закрепить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Закрепление магазинов'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final assignedStores = _userStores[user.id] ?? [];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              leading: CircleAvatar(child: Text(user.mail[0].toUpperCase())),
              title: Text(user.mail),
              subtitle: Text('Роль: ${user.role} • Магазинов: ${assignedStores.length}'),
              children: [
                ...assignedStores.map((store) => ListTile(
                      title: Text(store),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _unassignStore(user.id, store),
                      ),
                    )),
                ListTile(
                  title: const Text('Добавить магазин'),
                  leading: const Icon(Icons.add, color: Colors.green),
                  onTap: () => _showAssignDialog(user.id, user.mail),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}