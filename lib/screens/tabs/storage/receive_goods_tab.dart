// lib/screens/tabs/storage/receive_goods_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class ReceiveGoodsTab extends StatefulWidget {
  final Profile profile;
  const ReceiveGoodsTab({super.key, required this.profile});

  @override
  State<ReceiveGoodsTab> createState() => _ReceiveGoodsTabState();
}

class _ReceiveGoodsTabState extends State<ReceiveGoodsTab> {
  String? storeName;
  List<Map<String, dynamic>> pendingDeliveries = [];
  bool isLoading = true;
  String? errorMessage;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Находим магазин кладовщика
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', widget.profile.id)
          .limit(1)
          .maybeSingle();

      if (assignment == null || assignment['store_name'] == null) {
        setState(() {
          errorMessage = 'Магазин не закреплён за вами';
          isLoading = false;
        });
        return;
      }

      final currentStore = assignment['store_name'] as String;
      setState(() => storeName = currentStore);

      // 2. Находим ожидающие поставки для этого магазина
      final deliveries = await supabase
          .from('deliveries')
          .select('id, supplier_id, created_at')
          .eq('store_name', currentStore)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> deliveriesWithItems = [];

      for (final delivery in deliveries) {
        final deliveryId = delivery['id'] as int;
        final supplierId = delivery['supplier_id'] as String?;

        // Получаем email поставщика (если есть)
        String supplierEmail = 'Неизвестно';
        if (supplierId != null) {
          try {
            final profile = await supabase
                .from('profiles')
                .select('mail')
                .eq('id', supplierId)
                .maybeSingle();
            supplierEmail = profile?['mail'] ?? 'Неизвестно';
          } catch (_) {
            supplierEmail = 'Ошибка';
          }
        }

        // Получаем товары поставки
        final items = await supabase
            .from('delivery_items')
            .select('product_id, quantity')
            .eq('delivery_id', deliveryId);

        int totalQuantity = 0;
        for (final item in items) {
          final qty = item['quantity'] as num?;
          if (qty != null) totalQuantity += qty.toInt();
        }

        deliveriesWithItems.add({
          'id': deliveryId,
          'supplier_email': supplierEmail,
          'created_at': delivery['created_at'],
          'total_items': totalQuantity,
          'items': items,
        });
      }

      setState(() {
        pendingDeliveries = deliveriesWithItems;
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
      final items = await supabase
          .from('delivery_items')
          .select('product_id, quantity')
          .eq('delivery_id', deliveryId);

      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;

        if (qty <= 0) continue;

        final existing = await supabase
            .from('store_stock')
            .select('quantity')
            .eq('store_name', storeName!)
            .eq('product_id', productId)
            .maybeSingle();

        final currentQty = (existing?['quantity'] as num?)?.toInt() ?? 0;
        final newQty = currentQty + qty;

        await supabase.from('store_stock').upsert({
          'store_name': storeName!,
          'product_id': productId,
          'quantity': newQty,
        });
      }

      // Меняем статус поставки
      await supabase.from('deliveries').update({'status': 'accepted'}).eq('id', deliveryId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поставка принята'), backgroundColor: Colors.green),
      );

      loadData(); // обновляем список
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при приёме: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (pendingDeliveries.isEmpty) {
      return const Center(
        child: Text('Нет ожидающих поставок', style: TextStyle(fontSize: 18)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Магазин: $storeName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pendingDeliveries.length,
            itemBuilder: (context, index) {
              final delivery = pendingDeliveries[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Поставка #${delivery['id']}'),
                  subtitle: Text(
                    'От: ${delivery['supplier_email']}\nТоваров: ${delivery['total_items']}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => acceptDelivery(delivery['id']),
                  ),
                  onTap: () {
                    // Можно добавить детали, но пока просто приём по тапу на карточку
                    acceptDelivery(delivery['id']);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}