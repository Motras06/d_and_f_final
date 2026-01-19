import 'package:d_and_f_final/screens/tabs/storage/widgets/return_delivery_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
// import '/services/delivery_service.dart'; // если сервис не нужен, закомментируй

class ReceiveGoodsTab extends StatefulWidget {
  final Profile profile;
  const ReceiveGoodsTab({super.key, required this.profile});

  @override
  State<ReceiveGoodsTab> createState() => _ReceiveGoodsTabState();
}

class _ReceiveGoodsTabState extends State<ReceiveGoodsTab>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? storeName;
  List<Map<String, dynamic>> pendingDeliveries = [];
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    loadData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Загружаем имя моего магазина
      final myStore = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();

      storeName = myStore?['store_name'] as String?;

      // Загружаем ожидающие поставки для моего магазина
      final deliveries = await supabase
          .from('deliveries')
          .select('''
            id,
            supplier_id,
            created_at,
            status,
            delivery_items (
              id,
              product_id,
              quantity,
              products (
                id,
                name,
                price_with_vat,
                image_url,
                unit_of_measure
              )
            )
          ''')
          .eq('store_name', storeName!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      // Преобразуем в удобный формат
      final List<Map<String, dynamic>> formatted = deliveries.map((d) {
        final items = (d['delivery_items'] as List?) ?? [];
        final totalItems = items.fold(0, (sum, i) => sum + (i['quantity'] as int? ?? 0));

        return {
          'id': d['id'],
          'supplier_id': d['supplier_id'],
          'created_at': d['created_at'],
          'total_items': totalItems,
          'items': items.map((i) {
            final product = i['products'] ?? {};
            return {
              'product_id': i['product_id'],
              'quantity': i['quantity'],
              'name': product['name'] ?? '—',
              'price': product['price_with_vat'] ?? 0,
              'image_url': product['image_url'],
              'unit': product['unit_of_measure'] ?? 'шт',
            };
          }).toList(),
        };
      }).toList();

      setState(() {
        pendingDeliveries = formatted;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  Future<void> acceptDelivery(int deliveryId) async {
    try {
      await supabase
          .from('deliveries')
          .update({'status': 'accepted'})
          .eq('id', deliveryId);

      _showSnack('Поставка принята', isSuccess: true);
      loadData();
    } catch (e) {
      _showSnack('Ошибка при приёме: $e', isError: true);
    }
  }

  Future<void> rejectWithReturn(int deliveryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вернуть поставку отправителю?'),
        content: const Text(
          'Товары вернутся на склад отправителя.\n'
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Вернуть', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final delivery = await supabase
          .from('deliveries')
          .select('supplier_id, store_name, delivery_items(product_id, quantity)')
          .eq('id', deliveryId)
          .single();

      final supplierId = delivery['supplier_id'] as String?;
      final receiverStore = delivery['store_name'] as String?;
      final items = delivery['delivery_items'] as List<dynamic>? ?? [];

      if (supplierId == null) throw Exception('Не найден отправитель');

      final supplierStoreRes = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supplierId)
          .limit(1)
          .maybeSingle();

      final supplierStore = supplierStoreRes?['store_name'] as String?;

      if (supplierStore == null) throw Exception('У отправителя нет привязанного магазина');

      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = item['quantity'] as int;

        await supabase.from('store_stock').upsert({
          'store_name': supplierStore,
          'product_id': productId,
          'quantity': qty,
        }, onConflict: 'store_name,product_id');

        // Если товары уже зачислены получателю — уменьшить (но в pending обычно 0)
        final receiverStock = await supabase
            .from('store_stock')
            .select('quantity')
            .eq('store_name', receiverStore!)
            .eq('product_id', productId)
            .maybeSingle();

        final currentReceiver = receiverStock?['quantity'] as int? ?? 0;
        if (currentReceiver > 0) {
          final newReceiver = currentReceiver - qty;
          if (newReceiver <= 0) {
            await supabase
                .from('store_stock')
                .delete()
                .eq('store_name', receiverStore)
                .eq('product_id', productId);
          } else {
            await supabase
                .from('store_stock')
                .update({'quantity': newReceiver})
                .eq('store_name', receiverStore)
                .eq('product_id', productId);
          }
        }
      }

      await supabase
          .from('deliveries')
          .update({'status': 'returned'})
          .eq('id', deliveryId);

      _showSnack('Поставка возвращена отправителю', isSuccess: true);
      loadData();
    } catch (e) {
      _showSnack('Ошибка возврата: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openReturnedScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReturnedDeliveriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // отступ от bottom nav
        child: FloatingActionButton.extended(
          onPressed: _openReturnedScreen,
          icon: const Icon(Icons.undo),
          label: const Text('Возврат принятых поставок'),
          backgroundColor: Colors.orange[700],
          foregroundColor: Colors.white,
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: loadData,
              color: theme.colorScheme.primary,
              child: Column(
                children: [
                  if (!isLoading && errorMessage == null && pendingDeliveries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: theme.cardColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_mall_directory_outlined, size: 32, color: theme.colorScheme.primary),
                              const SizedBox(width: 16),
                              Text(
                                'Магазин: $storeName',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
                                    const SizedBox(height: 24),
                                    Text(errorMessage!, style: const TextStyle(fontSize: 18)),
                                  ],
                                ),
                              )
                            : pendingDeliveries.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey[600]),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Нет ожидающих поставок',
                                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Все поставки приняты или возвращены',
                                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: pendingDeliveries.length,
                                    itemBuilder: (context, index) {
                                      final delivery = pendingDeliveries[index];

                                      return Card(
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Icon(Icons.local_shipping_outlined, size: 40, color: Colors.orange),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Поставка #${delivery['id']}',
                                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'От: ${delivery['supplier_id']?.toString().substring(0, 8)}...',
                                                      style: theme.textTheme.bodyLarge,
                                                    ),
                                                    Text(
                                                      'Товаров: ${delivery['total_items']}',
                                                      style: theme.textTheme.bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                children: [
                                                  IconButton(
                                                    onPressed: () => acceptDelivery(delivery['id']),
                                                    icon: const Icon(Icons.check_circle, size: 48, color: Colors.green),
                                                    tooltip: 'Принять поставку',
                                                  ),
                                                  IconButton(
                                                    onPressed: () => rejectWithReturn(delivery['id']),
                                                    icon: const Icon(Icons.undo, size: 48, color: Colors.red),
                                                    tooltip: 'Вернуть поставку',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}