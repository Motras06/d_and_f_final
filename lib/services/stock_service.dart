// lib/services/stock_service.dart

import 'package:d_and_f_final/models/stock_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class StockService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> loadStock(Profile profile) async {
    // 1. Получаем магазин кладовщика
    final assignment = await supabase
        .from('store_assignments')
        .select('store_name')
        .eq('user_id', profile.id)
        .maybeSingle();

    if (assignment == null || assignment['store_name'] == null) {
      throw 'Магазин не закреплён';
    }

    final storeName = assignment['store_name'] as String;

    // 2. Получаем остатки
    final stockResponse = await supabase
        .from('store_stock')
        .select('product_id, quantity, product:product_id(name, country, price, image_url, about)')
        .eq('store_name', storeName)
        .order('quantity', ascending: false);

    final List<StockItem> items = [];

    for (final row in stockResponse) {
      final productJson = row['product'] as Map<String, dynamic>?;
      if (productJson == null) continue;

      items.add(StockItem(
        productId: row['product_id'] as int,
        name: productJson['name'] as String,
        country: productJson['country'] as String,
        price: productJson['price'] as num,
        imageUrl: productJson['image_url'] as String?,
        about: productJson['about'] as String?,
        quantity: (row['quantity'] as num).toInt(),
      ));
    }

    return {
      'storeName': storeName,
      'stockItems': items,
    };
  }

  Future<void> updateQuantity(String storeName, int productId, int newQuantity) async {
    if (newQuantity < 0) newQuantity = 0;

    await supabase.from('store_stock').update({
      'quantity': newQuantity,
    }).eq('store_name', storeName).eq('product_id', productId);
  }
}