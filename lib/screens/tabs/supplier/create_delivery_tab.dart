// lib/screens/tabs/supplier/create_delivery_tab.dart

import 'package:flutter/material.dart';

class CreateDeliveryTab extends StatelessWidget {
  const CreateDeliveryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Новая поставка',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Нажмите, чтобы выбрать магазин и добавить товары', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}