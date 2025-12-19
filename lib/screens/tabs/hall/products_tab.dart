// lib/screens/tabs/hall/products_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class HallProduct {
  final int productId;
  final String name;
  final String country;
  final num price;
  final String? imageUrl;
  final String? about;
  final int quantity;

  HallProduct({
    required this.productId,
    required this.name,
    required this.country,
    required this.price,
    this.imageUrl,
    this.about,
    required this.quantity,
  });
}

class ProductsTab extends StatefulWidget {
  final Profile profile;
  const ProductsTab({super.key, required this.profile});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String? storeName;
  List<HallProduct> allProducts = [];
  List<HallProduct> filteredProducts = [];
  bool isLoading = true;
  String? errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadProducts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterProducts();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Получаем магазин менеджера зала
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', widget.profile.id)
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

      // 2. Получаем товары в магазине
      final stockResponse = await supabase
          .from('store_stock')
          .select('product_id, quantity, product:product_id(name, country, price, image_url, about)')
          .eq('store_name', currentStore)
          .gt('quantity', 0) // только товары в наличии
          .order('quantity', ascending: false);

      final List<HallProduct> products = [];

      for (final row in stockResponse) {
        final productJson = row['product'] as Map<String, dynamic>?;
        if (productJson == null) continue;

        products.add(HallProduct(
          productId: row['product_id'] as int,
          name: productJson['name'] as String,
          country: productJson['country'] as String,
          price: productJson['price'] as num,
          imageUrl: productJson['image_url'] as String?,
          about: productJson['about'] as String?,
          quantity: (row['quantity'] as num).toInt(),
        ));
      }

      setState(() {
        allProducts = products;
        filteredProducts = products;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      filteredProducts = allProducts;
    } else {
      filteredProducts = allProducts.where((p) =>
          p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    setState(() {});
  }

  void _showProductDetails(HallProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.imageUrl != null)
                Center(
                  child: Image.network(
                    product.imageUrl!,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Страна: ${product.country}'),
              Text('Цена: ${product.price} ₽'),
              Text('В наличии: ${product.quantity} шт.', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (product.about != null && product.about!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Описание:\n${product.about}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return Column(
      children: [
        // Заголовок с магазином и поиском
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Магазин: $storeName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SearchBar(
                controller: _searchController,
                hintText: 'Поиск по названию...',
                leading: const Icon(Icons.search),
                trailing: _searchQuery.isNotEmpty
                    ? [IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)]
                    : null,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),

        // Список товаров
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'Нет товаров в наличии' : 'Ничего не найдено',
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return ListTile(
                      leading: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.inventory),
                            )
                          : const Icon(Icons.inventory),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Цена: ${product.price} ₽ • ${product.country}'),
                      trailing: Text(
                        '${product.quantity} шт.',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      onTap: () => _showProductDetails(product),
                    );
                  },
                ),
        ),
      ],
    );
  }
}