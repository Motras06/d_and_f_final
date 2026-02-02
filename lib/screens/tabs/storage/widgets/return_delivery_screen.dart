import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReturnedDeliveriesScreen extends StatefulWidget {
  const ReturnedDeliveriesScreen({super.key});

  @override
  State<ReturnedDeliveriesScreen> createState() =>
      _ReturnedDeliveriesScreenState();
}

class _ReturnedDeliveriesScreenState extends State<ReturnedDeliveriesScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> acceptedDeliveries = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAcceptedDeliveries();
  }

  Future<void> _loadAcceptedDeliveries() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUserStore = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();

      final storeName = currentUserStore?['store_name'] as String?;

      if (storeName == null) throw Exception('Нет привязанного магазина');

      final deliveries = await supabase
          .from('deliveries')
          .select('''
            id,
            supplier_id,
            created_at,
            status,
            delivery_items (
              product_id,
              quantity,
              products (
                name,
                price_with_vat,
                image_url,
                unit_of_measure
              )
            )
          ''')
          .eq('store_name', storeName)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final formatted = deliveries.map((d) {
        final items = d['delivery_items'] as List<dynamic>? ?? [];
        final total = items.fold(
          0,
          (sum, i) => sum + (i['quantity'] as int? ?? 0),
        );

        return {
          'id': d['id'],
          'supplier_id': d['supplier_id'],
          'created_at': d['created_at'],
          'total_items': total,
          'items': items.map((i) {
            final p = i['products'] ?? {};
            return {
              'product_id': i['product_id'],
              'quantity': i['quantity'],
              'name': p['name'] ?? '—',
              'price': p['price_with_vat'] ?? 0,
              'image_url': p['image_url'],
              'unit': p['unit_of_measure'] ?? 'шт',
            };
          }).toList(),
        };
      }).toList();

      setState(() {
        acceptedDeliveries = formatted;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _returnDelivery(int deliveryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вернуть поставку?'),
        content: const Text(
          'Товары вернутся отправителю, статус изменится на "returned".',
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
          .select(
            'supplier_id, store_name, delivery_items(product_id, quantity)',
          )
          .eq('id', deliveryId)
          .single();

      final supplierId = delivery['supplier_id'] as String?;
      final receiverStore = delivery['store_name'] as String?;
      final items = delivery['delivery_items'] as List<dynamic>? ?? [];

      if (supplierId == null) throw Exception('Нет отправителя');

      final supplierStoreRes = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supplierId)
          .limit(1)
          .maybeSingle();

      final supplierStore = supplierStoreRes?['store_name'] as String?;
      if (supplierStore == null) throw Exception('У отправителя нет магазина');

      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = item['quantity'] as int;

        await supabase.from('store_stock').upsert({
          'store_name': supplierStore,
          'product_id': productId,
          'quantity': qty,
        }, onConflict: 'store_name,product_id');

        final receiverStock = await supabase
            .from('store_stock')
            .select('quantity')
            .eq('store_name', receiverStore!)
            .eq('product_id', productId)
            .maybeSingle();

        final currentReceiver = receiverStock?['quantity'] as int? ?? 0;
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

      await supabase
          .from('deliveries')
          .update({'status': 'returned'})
          .eq('id', deliveryId);

      _showSnack('Поставка возвращена отправителю', isSuccess: true);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Ошибка возврата: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : (isSuccess ? Colors.green : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Возврат поставок'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : acceptedDeliveries.isEmpty
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
                    'Нет принятых поставок для возврата',
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: acceptedDeliveries.length,
              itemBuilder: (context, index) {
                final d = acceptedDeliveries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_shipping,
                      color: Colors.orange,
                    ),
                    title: Text('Поставка #${d['id']}'),
                    subtitle: Text(
                      'Товаров: ${d['total_items']} • ${d['created_at'].toString().substring(0, 10)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.undo, color: Colors.red),
                      onPressed: () => _returnDelivery(d['id']),
                      tooltip: 'Вернуть поставку',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
