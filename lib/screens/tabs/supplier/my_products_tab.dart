// lib/screens/tabs/supplier/my_products_tab.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/product.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'services/product_service.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_dialog.dart';

class MyProductsTab extends StatefulWidget {
  final Profile profile;
  const MyProductsTab({super.key, required this.profile});

  @override
  State<MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<MyProductsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Product> _cachedProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _loadProducts(forceRefresh: false);

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({required bool forceRefresh}) async {
    if (!forceRefresh && _cachedProducts.isNotEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final products = await _productService.fetchMyProducts(widget.profile.id);
      setState(() {
        _cachedProducts = products;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadProducts(forceRefresh: true);
  }

  void _onProductChanged() {
    _loadProducts(forceRefresh: true);
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _cachedProducts;
    return _cachedProducts.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _openAddProduct() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(
        productService: _productService,
        userId: widget.profile.id,
      ),
    );
    if (result == true) {
      _onProductChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // для keepAlive

    final theme = Theme.of(context);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _onRefresh,
          color: theme.colorScheme.primary,
          child: _buildBody(theme),
        ),

        // ← Только это добавлено: кнопка + в правом нижнем углу
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: _openAddProduct,
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProducts(forceRefresh: true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
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
              _searchQuery.isEmpty ? 'Товаров пока нет' : 'Ничего не найдено',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_searchQuery.isEmpty)
              const Text(
                'Нажмите + чтобы добавить первый товар',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Поиск по названию...',
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
                          setState(() => _searchQuery = '');
                        },
                      ),
                    ]
                  : null,
              textStyle: WidgetStatePropertyAll(TextStyle(color: theme.colorScheme.onSurface)),
              hintStyle: WidgetStatePropertyAll(TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = _filteredProducts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ProductCard(
                    product: product,
                    onEdit: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => ProductFormDialog(
                          productService: _productService,
                          userId: widget.profile.id,
                          existingProduct: product,
                        ),
                      );
                      if (result == true) {
                        _onProductChanged();
                      }
                    },
                  ),
                );
              },
              childCount: _filteredProducts.length,
            ),
          ),
        ),
      ],
    );
  }
}