import 'package:flutter/material.dart';

class AccountingTab extends StatelessWidget {
  const AccountingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calculate_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 24),
          Text(
            'Учёт',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Учёт остатков, приходов, расходов, себестоимости\n(в разработке)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}