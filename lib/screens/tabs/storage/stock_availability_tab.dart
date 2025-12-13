// lib/screens/tabs/storage/stock_availability_tab.dart

import 'package:flutter/material.dart';

class StockAvailabilityTab extends StatelessWidget {
  const StockAvailabilityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Наличие товаров',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Текущие остатки на складе', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}