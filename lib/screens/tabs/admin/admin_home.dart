import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'package:d_and_f_final/services/auth_service.dart';
import 'package:d_and_f_final/screens/auth/login_screen.dart';
import 'record_form_dialog.dart'; // ← подключаем второй файл

class AdminHome extends StatefulWidget {
  final Profile profile;
  const AdminHome({super.key, required this.profile});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  final List<String> tables = [
    'profiles',
    'stores',
    'store_assignments',
    'products',
    'suppliers',
    'deliveries',
    'delivery_items',
    'store_stock',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tables.length, vsync: this);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель D&F'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tables.map((table) => Tab(text: _formatTableName(table))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tables.map((table) => _TableManagementView(tableName: table)).toList(),
      ),
    );
  }

  String _formatTableName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _TableManagementView extends StatefulWidget {
  final String tableName;
  const _TableManagementView({required this.tableName});

  @override
  State<_TableManagementView> createState() => _TableManagementViewState();
}

class _TableManagementViewState extends State<_TableManagementView> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.from(widget.tableName).select();
      setState(() {
        records = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _addRecord() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RecordFormDialog(tableName: widget.tableName, isEdit: false),
    );

    if (result != null) {
      try {
        await Supabase.instance.client.from(widget.tableName).insert(result);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись добавлена'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка добавления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RecordFormDialog(
        tableName: widget.tableName,
        isEdit: true,
        initialData: record,
      ),
    );

    if (result != null) {
      try {
        final idColumn = _getIdColumn(widget.tableName);
        await Supabase.instance.client
            .from(widget.tableName)
            .update(result)
            .eq(idColumn, record[idColumn]);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись обновлена'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
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
      try {
        final idColumn = _getIdColumn(widget.tableName);
        await Supabase.instance.client
            .from(widget.tableName)
            .delete()
            .eq(idColumn, record[idColumn]);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись удалена'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getIdColumn(String table) {
    switch (table) {
      case 'profiles':
      case 'suppliers':
        return 'id';
      case 'products':
      case 'stores':
      case 'deliveries':
      case 'delivery_items':
      case 'store_stock':
        return 'id';
      case 'store_assignments':
        return 'user_id';
      default:
        return 'id';
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';

    if (value is String && value.contains('T') && value.contains(':')) {
      try {
        final date = DateTime.parse(value);
        return '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.'
            '${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return value;
      }
    }

    if (value is num) return value.toStringAsFixed(2);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecord,
        child: const Icon(Icons.add),
        tooltip: 'Добавить запись',
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Ошибка: $error', style: const TextStyle(color: Colors.red)))
              : records.isEmpty
                  ? const Center(child: Text('Нет записей в таблице'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              _formatValue(record.values.first),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: record.entries
                                  .skip(1)
                                  .map((e) => Text('${e.key}: ${_formatValue(e.value)}'))
                                  .toList(),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editRecord(record),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRecord(record),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}