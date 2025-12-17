// lib/screens/tabs/supplier/deliveries_history_tab.dart

import 'package:flutter/material.dart';

class DeliveriesTab extends StatelessWidget {
  const DeliveriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Все товары',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Здесь будут ваши поставки', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}