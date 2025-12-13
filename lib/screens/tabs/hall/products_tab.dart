// lib/screens/tabs/hall/products_tab.dart

import 'package:flutter/material.dart';

class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Товары в зале',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Список доступных товаров и остатков', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}