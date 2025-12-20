// lib/screens/tabs/supplier/new_delivery_tab.dart

import 'dart:async';

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

class _NewDeliveryTabState extends State<NewDeliveryTab> with SingleTickerProviderStateMixin {
  Future<List<Product>>? _productsFuture;
  Future<List<String>>? _storesFuture;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';

  String? _selectedStore;
  Map<int, int> _selectedQuantities = {};

  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Только debounce — без setState в listener
    _searchController.addListener(_onSearchChanged);

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

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final newQuery = _searchController.text.trim();
      if (newQuery == _searchQuery) return; // не обновляем, если ничего не изменилось

      setState(() {
        _searchQuery = newQuery;
        _filterProducts();
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
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

    if (mounted) {
      setState(() {
        _allProducts = list;
        _filterProducts();
      });
    }

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
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      _filteredProducts = _allProducts
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    // НЕ вызываем setState здесь — только в debounce или других местах
  }

  void _selectStore() async {
    final stores = await _storesFuture;
    if (stores == null || stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('У вас нет привязанных магазинов'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Выберите магазин', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(store, style: const TextStyle(fontSize: 18)),
                    trailing: _selectedStore == store
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedStore = store);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuantity(int productId, int newQuantity) {
    if (newQuantity <= 0) {
      _selectedQuantities.remove(productId);
    } else {
      _selectedQuantities[productId] = newQuantity;
    }
    setState(() {}); // ← обновляем только здесь (для кнопки "Создать поставку")
  }

  Future<void> _submitDelivery() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Выберите магазин'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    if (_selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Выберите хотя бы один товар'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;

      final deliveryResponse = await supabase.from('deliveries').insert({
        'supplier_id': widget.profile.id,
        'store_name': _selectedStore,
        'status': 'pending',
      }).select('id');

      final deliveryId = deliveryResponse[0]['id'] as int;

      final items = _selectedQuantities.entries.map((e) {
        return {
          'delivery_id': deliveryId,
          'product_id': e.key,
          'quantity': e.value,
        };
      }).toList();

      await supabase.from('delivery_items').insert(items);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Поставка создана!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (mounted) {
        setState(() {
          _selectedStore = null;
          _selectedQuantities.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: FutureBuilder(
              future: Future.wait([_productsFuture ?? Future.value([]), _storesFuture ?? Future.value([])]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
                  );
                }

                return Column(
                  children: [
                    // Поиск
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Поиск товаров...',
                        elevation: const WidgetStatePropertyAll(6),
                        backgroundColor: WidgetStatePropertyAll(theme.cardColor),
                        shadowColor: WidgetStatePropertyAll(theme.shadowColor.withOpacity(0.3)),
                        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                        shape: const WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                        ),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                        leading: Icon(Icons.search, color: theme.colorScheme.primary),
                        trailing: _searchQuery.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    if (mounted) setState(() => _searchQuery = '');
                                  },
                                ),
                              ]
                            : null,
                        textStyle: WidgetStatePropertyAll(TextStyle(color: theme.colorScheme.onSurface)),
                        hintStyle: WidgetStatePropertyAll(TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      ),
                    ),

                    // Выбор магазина
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: OutlinedButton.icon(
                        onPressed: _selectStore,
                        icon: Icon(Icons.store_mall_directory_outlined, size: 32),
                        label: Text(
                          _selectedStore ?? 'Выберите магазин для поставки',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(color: _selectedStore != null ? Colors.green : theme.colorScheme.primary, width: 2),
                          foregroundColor: _selectedStore != null ? Colors.green : theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Список товаров
                    Expanded(
                      child: _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                                    size: 100,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _searchQuery.isEmpty ? 'Товаров для поставки нет' : 'Ничего не найдено',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty ? 'Добавьте товары в "Создать"' : 'Попробуйте другой запрос',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final quantity = _selectedQuantities[product.id] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DeliveryProductCard(
                                    product: product,
                                    quantity: quantity,
                                    onQuantityChanged: (newQty) => _updateQuantity(product.id, newQty),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Кнопка создания поставки
                    if (_selectedStore != null && _selectedQuantities.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitDelivery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              elevation: 8,
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Создать поставку', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}