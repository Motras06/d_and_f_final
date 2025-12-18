// lib/screens/tabs/supplier/widgets/delivery_product_card.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/product.dart';

class DeliveryProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  const DeliveryProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: product.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(product.imageUrl!, width: 60, height: 60, fit: BoxFit.cover),
              )
            : const Icon(Icons.inventory),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Цена: ${product.price} ₽'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: quantity > 0 ? () => onQuantityChanged(quantity - 1) : null,
            ),
            Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onQuantityChanged(quantity + 1),
            ),
          ],
        ),
      ),
    );
  }
}