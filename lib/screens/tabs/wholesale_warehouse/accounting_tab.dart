import 'package:d_and_f_final/screens/tabs/wholesale_warehouse/widgets/stock_item_card.dart';
import 'package:d_and_f_final/screens/tabs/wholesale_warehouse/widgets/stock_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountingTab extends StatefulWidget {
  const AccountingTab({super.key});

  @override
  State<AccountingTab> createState() => _AccountingTabState();
}

class _AccountingTabState extends State<AccountingTab>
    with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
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
      stockItems = []; // очищаем старые данные
    });

    try {
      // 1. Получаем магазин пользователя (берём первый)
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

      // 2. Загружаем остатки + join с products (без .order на сервере)
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

      // 3. Приводим к списку карт безопасно
      final List<dynamic> rawData = response ?? [];

      // Фильтруем и преобразуем только валидные записи
      final List<Map<String, dynamic>> mappedItems = rawData
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final product = row['products'] as Map<String, dynamic>? ?? {};
            return {
              'product_id': row['product_id'] as int? ?? 0,
              'quantity': row['quantity'] as int? ?? 0,
              'name': product['name'] as String? ?? 'Без названия',
              'country': product['country'] as String? ?? '—',
              'price':
                  (product['price_with_vat'] as num?) ??
                  (product['price'] as num?) ??
                  0,
              'image_url': product['image_url'] as String?,
              'unit': product['unit_of_measure'] as String? ?? 'шт',
              'about': product['about'] as String?,
            };
          })
          .toList();

      // 4. Сортируем по имени на клиенте
      mappedItems.sort((a, b) {
        final nameA = a['name'] as String;
        final nameB = b['name'] as String;
        return nameA.compareTo(nameB);
      });

      setState(() {
        stockItems = mappedItems;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Ошибка загрузки остатков: $e');
      print(stackTrace);
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(int productId, int newQuantity) async {
    if (storeName == null) return;

    try {
      if (newQuantity <= 0) {
        // Удаляем запись, если количество 0
        await supabase
            .from('store_stock')
            .delete()
            .eq('store_name', storeName!)
            .eq('product_id', productId);
      } else {
        // upsert — если записи нет, создастся
        await supabase.from('store_stock').upsert({
          'store_name': storeName,
          'product_id': productId,
          'quantity': newQuantity,
        }, onConflict: 'store_name,product_id');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество обновлено'),
          backgroundColor: Colors.green,
        ),
      );

      _loadStock();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteProduct(int productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар удалён со склада'),
          backgroundColor: Colors.orange,
        ),
      );

      _loadStock();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                          Icons.error_outline,
                          size: 80,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 18),
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
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'На складе пусто',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Товары появятся после приёмки поставок',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Склад: $storeName',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
