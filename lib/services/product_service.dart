import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:d_and_f_final/models/product.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String bucketName = 'image_s';

  // Загрузка всех товаров поставщика
  Future<List<Product>> fetchMyProducts(String userId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Product.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Создание товара
  Future<void> createProduct({
    required String name,
    required String country,
    required num price,
    String? about,
    XFile? image,
    required String userId,
  }) async {
    String? imageUrl;

    if (image != null) {
      final fileBytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      imageUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);
    }

    await _supabase.from('products').insert({
      'name': name,
      'country': country,
      'price': price,
      'about': about,
      'image_url': imageUrl,
      'created_by': userId,
    });
  }

  // Обновление товара
  Future<void> updateProduct({
    required int productId,
    required String name,
    required String country,
    required num price,
    String? about,
    XFile? newImage,
    String? currentImageUrl,
  }) async {
    String? updatedImageUrl = currentImageUrl;

    if (newImage != null) {
      final fileBytes = await newImage.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${newImage.name}';

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      updatedImageUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);
    }

    await _supabase
        .from('products')
        .update({
          'name': name,
          'country': country,
          'price': price,
          'about': about,
          'image_url': updatedImageUrl,
        })
        .eq('id', productId);
  }

  Future<void> deleteProduct(int productId) async {
    final supabase = Supabase.instance.client;

    // 1. Удаляем все записи в delivery_items с этим product_id
    await supabase.from('delivery_items').delete().eq('product_id', productId);

    // 2. Удаляем все записи в store_stock с этим product_id
    await supabase.from('store_stock').delete().eq('product_id', productId);

    // 3. Теперь можно удалить сам товар
    await supabase.from('products').delete().eq('id', productId);
  }
}
