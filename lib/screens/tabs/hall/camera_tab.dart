// lib/screens/tabs/hall/camera_tab.dart

import 'package:flutter/material.dart';

class CameraTab extends StatelessWidget {
  const CameraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Сканирование',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Наведите камеру на штрих-код или QR-код товара', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}