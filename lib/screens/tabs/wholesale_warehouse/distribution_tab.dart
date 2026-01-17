import 'package:flutter/material.dart';

class DistributionTab extends StatelessWidget {
  const DistributionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 24),
          Text(
            'Распределение',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Распределение товаров по магазинам / малым складам\n(в разработке)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}