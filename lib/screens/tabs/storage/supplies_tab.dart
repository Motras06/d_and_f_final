import 'package:flutter/material.dart';


class SuppliesTab extends StatelessWidget {
  final String? assignedStore;
  final bool isLoadingSupplies;
  final List<Map<String, dynamic>> deliveries;
  final Function(int, String, List<Map<String, dynamic>>) onAcceptDelivery;
  final Function(int, String) onRejectDelivery;

  const SuppliesTab({
    super.key,
    required this.assignedStore,
    required this.isLoadingSupplies,
    required this.deliveries,
    required this.onAcceptDelivery,
    required this.onRejectDelivery,
  });

  @override
  Widget build(BuildContext context) {
    if (assignedStore == null) {
      return const Center(child: Text('Магазин не выбран'));
    }
    if (isLoadingSupplies) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        return Card(
          child: ExpansionTile(
            title: Text('Поставка #${delivery['id']} - ${delivery['status']}'),
            subtitle: Text('От: ${delivery['supplier_id']}'),
            children: [
              ...delivery['items'].map((item) => ListTile(
                    title: Text('Товар ID: ${item['product_id']}'),
                    subtitle: Text('Количество: ${item['quantity']}'),
                  )),
              if (delivery['status'] == 'pending')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => onAcceptDelivery(delivery['id'], assignedStore!, delivery['items']),
                      child: const Text('Принять'),
                    ),
                    ElevatedButton(
                      onPressed: () => onRejectDelivery(delivery['id'], assignedStore!),
                      child: const Text('Отклонить'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}