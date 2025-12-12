// lib/screens/create_delivery_tab.dart
import 'package:flutter/material.dart';
import '../../../models.dart';

class CreateDeliveryTab extends StatelessWidget {
  final bool isLoadingDeliveryData;
  final List<Product> products;
  final List<String> stores;
  final String? selectedStore;
  final Map<int, int> selectedProducts;
  final Function(String?) onStoreChanged;
  final Function(int, int) onQuantityChanged;
  final bool isDeliverySubmitting;
  final VoidCallback onSubmitDelivery;

  const CreateDeliveryTab({
    super.key,
    required this.isLoadingDeliveryData,
    required this.products,
    required this.stores,
    required this.selectedStore,
    required this.selectedProducts,
    required this.onStoreChanged,
    required this.onQuantityChanged,
    required this.isDeliverySubmitting,
    required this.onSubmitDelivery,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingDeliveryData) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: selectedStore,
            items: stores.map((store) => DropdownMenuItem(value: store, child: Text(store))).toList(),
            onChanged: onStoreChanged,
            decoration: const InputDecoration(labelText: 'Выберите магазин'),
          ),
          const SizedBox(height: 24),
          const Text('Выберите товары:'),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final qty = selectedProducts[product.id] ?? 0;
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${product.price} ₽'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onQuantityChanged(product.id, qty - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$qty'),
                    IconButton(
                      onPressed: () => onQuantityChanged(product.id, qty + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          isDeliverySubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: selectedStore == null || selectedProducts.isEmpty ? null : onSubmitDelivery,
                  child: const Text('Создать поставку'),
                ),
        ],
      ),
    );
  }
}