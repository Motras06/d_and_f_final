// lib/services/delivery_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class DeliveryService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> loadPendingDeliveries(Profile profile) async {
    // 1. Находим магазин кладовщика
    final assignment = await supabase
        .from('store_assignments')
        .select('store_name')
        .eq('user_id', profile.id)
        .limit(1)
        .maybeSingle();

    if (assignment == null || assignment['store_name'] == null) {
      throw 'Магазин не закреплён за вами';
    }

    final storeName = assignment['store_name'] as String;

    // 2. Находим ожидающие поставки
    final deliveries = await supabase
        .from('deliveries')
        .select('id, supplier_id, created_at')
        .eq('store_name', storeName)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    List<Map<String, dynamic>> deliveriesWithItems = [];

    for (final delivery in deliveries) {
      final deliveryId = delivery['id'] as int;
      final supplierId = delivery['supplier_id'] as String?;

      String supplierEmail = 'Неизвестно';
      if (supplierId != null) {
        try {
          final profileData = await supabase
              .from('profiles')
              .select('mail')
              .eq('id', supplierId)
              .maybeSingle();
          supplierEmail = profileData?['mail'] ?? 'Неизвестно';
        } catch (_) {
          supplierEmail = 'Ошибка';
        }
      }

      final items = await supabase
          .from('delivery_items')
          .select('product_id, quantity')
          .eq('delivery_id', deliveryId);

      int totalQuantity = items.fold(
        0,
        (sum, item) => sum + (item['quantity'] as num? ?? 0).toInt(),
      );

      deliveriesWithItems.add({
        'id': deliveryId,
        'supplier_email': supplierEmail,
        'created_at': delivery['created_at'],
        'total_items': totalQuantity,
        'items': items,
      });
    }

    return {'storeName': storeName, 'deliveries': deliveriesWithItems};
  }

  Future<void> acceptDelivery(String storeName, int deliveryId) async {
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
          .eq('store_name', storeName)
          .eq('product_id', productId)
          .maybeSingle();

      final currentQty = (existing?['quantity'] as num?)?.toInt() ?? 0;
      final newQty = currentQty + qty;

      await supabase.from('store_stock').upsert({
        'store_name': storeName,
        'product_id': productId,
        'quantity': newQty,
      });
    }

    await supabase
        .from('deliveries')
        .update({'status': 'accepted'})
        .eq('id', deliveryId);
  }

  Future<void> rejectDelivery(int deliveryId) async {
    await supabase
        .from('deliveries')
        .update({'status': 'rejected'})
        .eq('id', deliveryId);
    // Или если хочешь полностью удалить:
    await supabase
        .from('delivery_items')
        .delete()
        .eq('delivery_id', deliveryId);
    await supabase.from('deliveries').delete().eq('id', deliveryId);
  }

  Future<void> deleteDelivery(int deliveryId) async {
    final supabase = Supabase.instance.client;

    // 1. Сначала удаляем все товары поставки
    await supabase
        .from('delivery_items')
        .delete()
        .eq('delivery_id', deliveryId);

    // 2. Потом удаляем саму поставку
    await supabase.from('deliveries').delete().eq('id', deliveryId);
  }
}
