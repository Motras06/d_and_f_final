// repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';  // Импорт моделей из предыдущего файла

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Получить текущий профиль пользователя (RLS: только свой)
  Future<Profile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client.from('profiles').select().eq('id', user.id).single();
    if (response.isEmpty) return null;
    return Profile.fromMap(response);
  }

  // Обновить профиль (RLS: только свой)
  Future<void> updateProfile(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _client.from('profiles').update({'username': username}).eq('id', user.id);
  }

  // Получить назначения магазинов для текущего кладовщика (RLS: только свои)
  Future<List<StoreAssignment>> getStoreAssignments() async {
    final response = await _client.from('store_assignments').select();
    return response.map((map) => StoreAssignment.fromMap(map)).toList();
  }

  // Получить остатки для магазина (RLS: только для назначенного кладовщика)
  Future<List<StoreStock>> getStoreStock(String storeName) async {
    final response = await _client.from('store_stock').select().eq('store_name', storeName);
    return response.map((map) => StoreStock.fromMap(map)).toList();
  }

  // Создать новую поставку (для поставщика)
  Future<int> createDelivery(String storeName, List<Map<String, dynamic>> items) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Вставка поставки
    final deliveryResponse = await _client.from('deliveries').insert({
      'supplier_id': user.id,
      'store_name': storeName,
    }).select('id').single();
    final deliveryId = deliveryResponse['id'] as int;

    // Вставка элементов поставки
    final deliveryItems = items.map((item) => {
          'delivery_id': deliveryId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        }).toList();
    await _client.from('delivery_items').insert(deliveryItems);

    return deliveryId;
  }

  // Получить свои поставки (для поставщика, RLS)
  Future<List<Delivery>> getMyDeliveries() async {
    final response = await _client.from('deliveries').select();
    return response.map((map) => Delivery.fromMap(map)).toList();
  }

  // Получить поставки для магазина (для кладовщика, RLS)
  Future<List<Delivery>> getStoreDeliveries(String storeName) async {
    final response = await _client.from('deliveries').select().eq('store_name', storeName);
    return response.map((map) => Delivery.fromMap(map)).toList();
  }

  // Обновить статус поставки (для кладовщика, добавь RLS-политику если нужно)
  Future<void> updateDeliveryStatus(int deliveryId, String status) async {
    await _client.from('deliveries').update({'status': status}).eq('id', deliveryId);
  }

  // Получить элементы поставки
  Future<List<DeliveryItem>> getDeliveryItems(int deliveryId) async {
    final response = await _client.from('delivery_items').select().eq('delivery_id', deliveryId);
    return response.map((map) => DeliveryItem.fromMap(map)).toList();
  }

  // Добавить/обновить товар (для админа или поставщика, добавь RLS если нужно)
  Future<void> upsertProduct(Product product) async {
    await _client.from('products').upsert(product.toMap());
  }

  // Получить все товары (общий каталог, без RLS?)
  Future<List<Product>> getProducts() async {
    final response = await _client.from('products').select();
    return response.map((map) => Product.fromMap(map)).toList();
  }
}