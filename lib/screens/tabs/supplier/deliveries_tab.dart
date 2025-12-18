// lib/screens/tabs/supplier/new_delivery_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/product.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'widgets/delivery_product_card.dart';

class NewDeliveryTab extends StatefulWidget {
  final Profile profile;
  const NewDeliveryTab({super.key, required this.profile});

  @override
  State<NewDeliveryTab> createState() => _NewDeliveryTabState();
}

class _NewDeliveryTabState extends State<NewDeliveryTab> {
  Future<List<Product>>? _productsFuture;
  Future<List<String>>? _storesFuture;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';

  String? _selectedStore;
  Map<int, int> _selectedQuantities = {}; // productId -> quantity

  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
      _filterProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _productsFuture = _fetchMyProducts();
    _storesFuture = _fetchMyStores();
  }

  Future<List<Product>> _fetchMyProducts() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('products')
        .select()
        .eq('created_by', widget.profile.id)
        .order('name');

    final list = (response as List<dynamic>)
        .map((json) => Product.fromJson(json as Map<String, dynamic>))
        .toList();

    setState(() {
      _allProducts = list;
      _filterProducts();
    });

    return list;
  }

  Future<List<String>> _fetchMyStores() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('store_assignments')
        .select('store_name')
        .eq('user_id', widget.profile.id);

    return (response as List<dynamic>).map((e) => e['store_name'] as String).toList();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = _allProducts;
    } else {
      _filteredProducts = _allProducts.where((p) =>
          p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    setState(() {});
  }

  void _selectStore() async {
    final stores = await _storesFuture;
    if (stores == null || stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет привязанных магазинов')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return ListTile(
            title: Text(store),
            trailing: _selectedStore == store ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              setState(() => _selectedStore = store);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _updateQuantity(int productId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _selectedQuantities.remove(productId);
      } else {
        _selectedQuantities[productId] = newQuantity;
      }
    });
  }

  Future<void> _submitDelivery() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите магазин')),
      );
      return;
    }

    if (_selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один товар')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;

      // Создаём поставку
      final deliveryResponse = await supabase.from('deliveries').insert({
        'supplier_id': widget.profile.id,
        'store_name': _selectedStore,
        'status': 'pending',
      }).select('id');

      final deliveryId = deliveryResponse[0]['id'] as int;

      // Добавляем товары
      final items = _selectedQuantities.entries.map((e) {
        return {
          'delivery_id': deliveryId,
          'product_id': e.key,
          'quantity': e.value,
        };
      }).toList();

      await supabase.from('delivery_items').insert(items);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поставка создана!'), backgroundColor: Colors.green),
      );

      // Сброс
      setState(() {
        _selectedStore = null;
        _selectedQuantities.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _searchController,
          hintText: 'Поиск товаров...',
          leading: const Icon(Icons.search),
          trailing: _searchQuery.isNotEmpty
              ? [IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)]
              : null,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([_productsFuture ?? Future.value([]), _storesFuture ?? Future.value([])]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Выбор магазина
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _selectStore,
                  icon: const Icon(Icons.store),
                  label: Text(_selectedStore ?? 'Выберите магазин'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedStore != null ? Colors.green : null,
                    foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // Список товаров
              Expanded(
                child: _filteredProducts.isEmpty
                    ? Center(
                        child: Text(_searchQuery.isEmpty ? 'Товаров нет' : 'Ничего не найдено'),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final quantity = _selectedQuantities[product.id] ?? 0;

                          return DeliveryProductCard(
                            product: product,
                            quantity: quantity,
                            onQuantityChanged: (newQty) => _updateQuantity(product.id, newQty),
                          );
                        },
                      ),
              ),

              // Кнопка создания поставки
              if (_selectedStore != null && _selectedQuantities.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitDelivery,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Создать поставку', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}