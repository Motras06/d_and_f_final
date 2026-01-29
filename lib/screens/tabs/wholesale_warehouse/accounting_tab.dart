// lib/screens/tabs/wholesale_warehouse/accounting_tab.dart
import 'package:d_and_f_final/screens/tabs/wholesale_warehouse/widgets/stock_item_card.dart';
import 'package:d_and_f_final/screens/tabs/wholesale_warehouse/widgets/stock_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountingTab extends StatefulWidget {
  const AccountingTab({super.key});

  @override
  State<AccountingTab> createState() => _AccountingTabState();
}

class _AccountingTabState extends State<AccountingTab> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? storeName;
  List<Map<String, dynamic>> stockItems = [];
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadStock();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      stockItems = [];
    });

    try {
      // 1. Магазин пользователя (берём первый)
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .limit(1)
          .maybeSingle();

      if (assignment == null || assignment['store_name'] == null) {
        throw Exception('У вас нет привязанного магазина');
      }

      final store = assignment['store_name'] as String;
      setState(() => storeName = store);

      // 2. Остатки + продукты
      final response = await supabase
          .from('store_stock')
          .select('''
            product_id,
            quantity,
            products!inner (
              id,
              name,
              country,
              price,
              price_with_vat,
              image_url,
              unit_of_measure,
              about
            )
          ''')
          .eq('store_name', store);

      final List<dynamic> rawData = response ?? [];

      final List<Map<String, dynamic>> mappedItems = rawData
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final product = row['products'] as Map<String, dynamic>? ?? {};
            return {
              'product_id': row['product_id'] as int? ?? 0,
              'quantity': row['quantity'] as int? ?? 0,
              'name': product['name'] as String? ?? 'Без названия',
              'country': product['country'] as String? ?? '—',
              'price': (product['price_with_vat'] as num?) ??
                  (product['price'] as num?) ??
                  0,
              'image_url': product['image_url'] as String?,
              'unit': product['unit_of_measure'] as String? ?? 'шт',
              'about': product['about'] as String?,
            };
          })
          .toList();

      // Сортировка по имени
      mappedItems.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          stockItems = mappedItems;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      print('Ошибка загрузки остатков: $e\n$stack');
      if (mounted) {
        setState(() {
          errorMessage = 'Не удалось загрузить склад: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(int productId, int newQuantity) async {
    if (storeName == null) return;

    try {
      if (newQuantity <= 0) {
        await supabase
            .from('store_stock')
            .delete()
            .eq('store_name', storeName!)
            .eq('product_id', productId);
      } else {
        await supabase.from('store_stock').upsert({
          'store_name': storeName,
          'product_id': productId,
          'quantity': newQuantity,
        }, onConflict: 'store_name,product_id');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Количество обновлено'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStock();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteProduct(int productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true || storeName == null) return;

    try {
      await supabase
          .from('store_stock')
          .delete()
          .eq('store_name', storeName!)
          .eq('product_id', productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар удалён со склада'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadStock();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  void _showProductDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => StockItemDialog(
        item: item,
        onUpdate: (newQty) => _updateQuantity(item['product_id'], newQty),
        onDelete: () => _deleteProduct(item['product_id']),
      ),
    ).then((_) => _loadStock());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
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
                              errorMessage!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _loadStock,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    : stockItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 100,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Склад пуст',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Добавьте товары через приёмку поставок',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Карточка со складом
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  color: colorScheme.surfaceContainerLow,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.store_outlined,
                                          color: colorScheme.primary,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Склад: $storeName',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              Expanded(
                                child: RefreshIndicator.adaptive(
                                  onRefresh: _loadStock,
                                  color: colorScheme.primary,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    itemCount: stockItems.length,
                                    itemBuilder: (context, index) {
                                      final item = stockItems[index];
                                      return StockItemCard(
                                        item: item,
                                        onTap: () => _showProductDetails(item),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
          ),
        ),
      ),
    );
  }
}