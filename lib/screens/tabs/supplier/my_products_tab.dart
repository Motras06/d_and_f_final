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

class _MyProductsTabState extends State<MyProductsTab> {
  late Future<List<Product>> _productsFuture;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _productsFuture = _productService.fetchMyProducts(widget.profile.id);
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _productsFuture = _productService.fetchMyProducts(widget.profile.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _searchController,
          hintText: 'Поиск по названию...',
          leading: const Icon(Icons.search),
          trailing: _searchQuery.isNotEmpty
              ? [IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)]
              : null,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));

          final allProducts = snapshot.data ?? [];
          final filtered = allProducts.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_searchQuery.isEmpty ? 'Товаров пока нет' : 'Ничего не найдено', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) => ProductCard(
              product: filtered[index],
              onEdit: () async {
                await showDialog(
                  context: context,
                  builder: (_) => ProductFormDialog(
                    productService: _productService,
                    userId: widget.profile.id,
                    existingProduct: filtered[index],
                  ),
                );
                _refresh();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => ProductFormDialog(
              productService: _productService,
              userId: widget.profile.id,
            ),
          );
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}