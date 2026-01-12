import 'package:d_and_f_final/screens/tabs/supplier/widgets/product_filter_dialog.dart';
import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/product.dart';
import 'package:d_and_f_final/models/profile.dart';
import '../../../services/product_service.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_dialog.dart';

class MyProductsTab extends StatefulWidget {
  final Profile profile;
  const MyProductsTab({super.key, required this.profile});

  @override
  State<MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<MyProductsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Product> _cachedProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();

  // Фильтры
  Map<String, dynamic> _activeFilters = {};
  bool get _hasActiveFilters => _activeFilters.isNotEmpty;

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
    var result = List<Product>.from(_cachedProducts);

    // Поиск по названию
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Дополнительные фильтры
    if (_activeFilters.isNotEmpty) {
      if (_activeFilters['minPrice'] != null) {
        final minPrice = _activeFilters['minPrice'] as double;
        result = result.where((p) => (p.price) >= minPrice).toList();
      }
      if (_activeFilters['maxPrice'] != null) {
        final maxPrice = _activeFilters['maxPrice'] as double;
        result = result.where((p) => (p.price) <= maxPrice).toList();
      }
      // if (_activeFilters['inStockOnly'] == true) {
      //   result = result.where((p) => (p.stock ?? 0) > 0).toList();
      // }
      // Можно легко добавить другие фильтры позже
    }

    return result;
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

  void _openFilterDialog() async {
    final newFilters = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductFilterDialog(initialFilters: _activeFilters),
    );

    if (newFilters != null) {
      setState(() {
        _activeFilters = newFilters;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _activeFilters = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _onRefresh,
          color: theme.colorScheme.primary,
          child: _buildBody(theme),
        ),

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
      return const Center(child: CircularProgressIndicator());
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

    // Основной контейнер — всегда со SliverAppBar сверху
    return CustomScrollView(
      slivers: [
        // Поиск и фильтры всегда видны
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Поиск по названию...',
                    elevation: const WidgetStatePropertyAll(6),
                    backgroundColor: WidgetStatePropertyAll(theme.cardColor),
                    shadowColor: WidgetStatePropertyAll(
                      theme.shadowColor.withOpacity(0.3),
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    shape: const WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16),
                    ),
                    leading: Icon(
                      Icons.search,
                      color: theme.colorScheme.primary,
                    ),
                    trailing: _searchQuery.isNotEmpty
                        ? [
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                // setState не нужен — listener сам обновит
                              },
                            ),
                          ]
                        : null,
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    hintStyle: WidgetStatePropertyAll(
                      TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: _hasActiveFilters
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      onPressed: _openFilterDialog,
                      tooltip: 'Фильтры',
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_hasActiveFilters)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 26),
                    color: theme.colorScheme.error,
                    tooltip: 'Сбросить фильтры',
                    onPressed: _resetFilters,
                  ),
              ],
            ),
          ),
        ),

        // Теперь в зависимости от наличия товаров — либо список, либо сообщение
        if (_filteredProducts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isEmpty && !_hasActiveFilters
                        ? Icons.inventory_2_outlined
                        : Icons.search_off,
                    size: 100,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _searchQuery.isNotEmpty || _hasActiveFilters
                        ? 'Ничего не найдено'
                        : 'Товаров пока нет',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_searchQuery.isEmpty && !_hasActiveFilters)
                    const Text(
                      'Нажмите + чтобы добавить первый товар',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
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
              }, childCount: _filteredProducts.length),
            ),
          ),
      ],
    );
  }
}
