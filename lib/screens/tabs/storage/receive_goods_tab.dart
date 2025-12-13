// lib/screens/tabs/storage/receive_goods_tab.dart

import 'package:flutter/material.dart';

class ReceiveGoodsTab extends StatelessWidget {
  const ReceiveGoodsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_received_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Приём товаров',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Здесь будут ожидающие поставки для приёма', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}