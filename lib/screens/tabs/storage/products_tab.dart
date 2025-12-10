import 'package:flutter/material.dart';


class ProductsTab extends StatelessWidget {
  final String? assignedStore;
  final bool isLoadingProducts;
  final List<Map<String, dynamic>> storeProducts;
  final Function(Map<String, dynamic>, GlobalKey) showQrDialog;

  const ProductsTab({
    super.key,
    required this.assignedStore,
    required this.isLoadingProducts,
    required this.storeProducts,
    required this.showQrDialog,
  });

  @override
  Widget build(BuildContext context) {
    if (assignedStore == null) {
      return const Center(child: Text('Магазин не выбран'));
    }
    if (isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: storeProducts.length,
      itemBuilder: (context, index) {
        final product = storeProducts[index];
        final GlobalKey qrKey = GlobalKey();
        return Card(
          child: ListTile(
            leading: product['image_url'] != null
                ? Image.network(product['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported),
            title: Text(product['name'] ?? 'Без названия'),
            subtitle: Text('Количество: ${product['quantity']}'),
            trailing: ElevatedButton(
              onPressed: () => showQrDialog(product, qrKey),
              child: const Text('QR'),
            ),
          ),
        );
      },
    );
  }
}