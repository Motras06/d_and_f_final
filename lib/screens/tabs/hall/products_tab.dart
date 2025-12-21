import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';
import 'package:share_plus/share_plus.dart';

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

class _ProductsTabState extends State<ProductsTab>
    with SingleTickerProviderStateMixin {
  String? storeName;
  List<HallProduct> allProducts = [];
  List<HallProduct> filteredProducts = [];
  bool isLoading = true;
  String? errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final supabase = Supabase.instance.client;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
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

      final stockResponse = await supabase
          .from('store_stock')
          .select(
            'product_id, quantity, product:product_id(name, country, price, image_url, about)',
          )
          .eq('store_name', currentStore)
          .gt('quantity', 0)
          .order('quantity', ascending: false);

      final List<HallProduct> products = [];

      for (final row in stockResponse) {
        final productJson = row['product'] as Map<String, dynamic>?;
        if (productJson == null) continue;

        products.add(
          HallProduct(
            productId: row['product_id'] as int,
            name: productJson['name'] as String,
            country: productJson['country'] as String,
            price: productJson['price'] as num,
            imageUrl: productJson['image_url'] as String?,
            about: productJson['about'] as String?,
            quantity: (row['quantity'] as num).toInt(),
          ),
        );
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
      filteredProducts = allProducts
          .where(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
  }

  void _showProductDetails(HallProduct product) {
    final safeProduct = {
      'id': product.productId,
      'name': product.name,
      'country': product.country,
      'price': product.price,
      'quantity': product.quantity,
      'about': product.about ?? '',
    };

    final qrData = jsonEncode(safeProduct);
    final qrUrl =
        'https://quickchart.io/qr?text=$qrData&size=300&margin=20&light=ffffff&dark=121212';

    void shareQR() {
      Share.share(
        'QR-код товара: ${product.name}\nЦена: ${product.price} ₽\nОстаток: ${product.quantity}\n\nСсылка: $qrUrl',
        subject: 'Товар: ${product.name}',
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(product.name, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (product.imageUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        product.imageUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Image.network(
                      qrUrl,
                      width: 220,
                      height: 220,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.qr_code, size: 100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Отсканируйте QR-код',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 24),

                Text(
                  'Страна: ${product.country}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Цена: ${product.price} ₽',
                  style: const TextStyle(fontSize: 16),
                ),
                if (product.about != null && product.about!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Описание: ${product.about}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                const SizedBox(height: 24),

                Text(
                  'В наличии: ${product.quantity} шт.',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            onPressed: shareQR,
            icon: const Icon(Icons.share),
            label: const Text('Поделиться QR'),
          ),
        ],
      ),
    );
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
            child: RefreshIndicator(
              onRefresh: loadProducts,
              color: theme.colorScheme.primary,
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 80,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 100,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Нет товаров в наличии',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Товары появятся после приёмки поставок',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            color: theme.cardColor,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory_outlined,
                                    size: 32,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Магазин: $storeName',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: SearchBar(
                            controller: _searchController,
                            hintText: 'Поиск по названию...',
                            elevation: const WidgetStatePropertyAll(6),
                            backgroundColor: WidgetStatePropertyAll(
                              theme.cardColor,
                            ),
                            shadowColor: WidgetStatePropertyAll(
                              theme.shadowColor.withOpacity(0.3),
                            ),
                            surfaceTintColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
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
                                      onPressed: _searchController.clear,
                                    ),
                                  ]
                                : null,
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(color: theme.colorScheme.onSurface),
                            ),
                            hintStyle: WidgetStatePropertyAll(
                              TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  color: theme.cardColor,
                                  shadowColor: theme.shadowColor.withOpacity(
                                    0.3,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            _showProductDetails(product),
                                        splashColor: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                            isDark ? 0.4 : 0.1,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child:
                                                      product.imageUrl != null
                                                      ? Image.network(
                                                          product.imageUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Icon(
                                                                Icons
                                                                    .inventory_2_outlined,
                                                                size: 40,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                              ),
                                                        )
                                                      : Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          size: 40,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 20),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '${product.country} • ${product.price} ₽',
                                                      style: theme
                                                          .textTheme
                                                          .bodyLarge,
                                                    ),
                                                    if (product.about != null &&
                                                        product
                                                            .about!
                                                            .isNotEmpty)
                                                      Text(
                                                        product.about!,
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),

                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'В наличии',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${product.quantity} шт.',
                                                    style: theme
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              product.quantity >
                                                                  10
                                                              ? Colors.green
                                                              : (product.quantity >
                                                                        0
                                                                    ? Colors
                                                                          .orange
                                                                    : Colors
                                                                          .red),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
