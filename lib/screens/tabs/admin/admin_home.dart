import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'package:d_and_f_final/services/auth_service.dart';
import 'package:d_and_f_final/screens/auth/login_screen.dart';
import 'record_form_dialog.dart';

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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Выйти'),
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

  static String formatTableName(String name) {
    final map = {
      'profiles': 'Пользователи',
      'stores': 'Магазины',
      'store_assignments': 'Привязки магазинов',
      'products': 'Товары',
      'suppliers': 'Поставщики',
      'deliveries': 'Доставки',
      'delivery_items': 'Позиции доставок',
      'store_stock': 'Остатки на складе',
    };
    return map[name] ??
        name
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Админ-панель D&F'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Выйти',
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: tables
              .map((table) => Tab(text: formatTableName(table)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tables
            .map((table) => _TableManagementView(tableName: table))
            .toList(),
      ),
    );
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
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      PostgrestTransformBuilder<PostgrestList> query = Supabase.instance.client
          .from(widget.tableName)
          .select();

      if (widget.tableName != 'store_assignments' &&
          widget.tableName != 'store_stock') {
        query = query.order('id', ascending: false);
      }

      final response = await query;

      if (mounted) {
        setState(() {
          records = List<Map<String, dynamic>>.from(response);
          loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Ошибка загрузки таблицы ${widget.tableName}: $e');
      debugPrint('$stack');

      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _addRecord() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          RecordFormDialog(tableName: widget.tableName, isEdit: false),
    );

    if (result != null && mounted) {
      try {
        await Supabase.instance.client.from(widget.tableName).insert(result);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Запись успешно добавлена'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка добавления: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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

    if (result != null && mounted) {
      try {
        final idColumn = _getIdColumn(widget.tableName);
        await Supabase.instance.client
            .from(widget.tableName)
            .update(result)
            .eq(idColumn, record[idColumn]);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Запись обновлена'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final idColumn = _getIdColumn(widget.tableName);
        await Supabase.instance.client
            .from(widget.tableName)
            .delete()
            .eq(idColumn, record[idColumn]);
        loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Запись удалена'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
      }
    }
  }

  String _getIdColumn(String table) {
    switch (table) {
      case 'profiles':
      case 'suppliers':
      case 'products':
      case 'stores':
      case 'deliveries':
      case 'delivery_items':
        return 'id';
      case 'store_assignments':
        return 'user_id';
      case 'store_stock':
        return 'product_id';
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить запись'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 80,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ошибка: $error',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: loadRecords,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          : records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_rows_outlined,
                    size: 80,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Нет записей в таблице «${_AdminHomeState.formatTableName(widget.tableName)}»',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator.adaptive(
              onRefresh: loadRecords,
              color: colorScheme.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shadowColor: colorScheme.shadow.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: colorScheme.surfaceContainerLowest,
                    child: ListTile(
                      title: Text(
                        _formatValue(record.values.first),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: record.entries
                            .skip(1)
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${e.key.replaceAll('_', ' ').toUpperCase()}: ${_formatValue(e.value)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              color: colorScheme.primary,
                            ),
                            onPressed: () => _editRecord(record),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_rounded,
                              color: colorScheme.error,
                            ),
                            onPressed: () => _deleteRecord(record),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
