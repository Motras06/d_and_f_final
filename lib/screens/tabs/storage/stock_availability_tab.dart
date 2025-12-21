// lib/screens/tabs/storage/stock_availability_tab.dart

import 'package:d_and_f_final/models/stock_item.dart';
import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';
import '/services/stock_service.dart';
import 'widgets/stock_item_card.dart';
import 'widgets/stock_item_dialog.dart';

class StockAvailabilityTab extends StatefulWidget {
  final Profile profile;
  const StockAvailabilityTab({super.key, required this.profile});

  @override
  State<StockAvailabilityTab> createState() => _StockAvailabilityTabState();
}

class _StockAvailabilityTabState extends State<StockAvailabilityTab>
    with SingleTickerProviderStateMixin {
  String? storeName;
  List<StockItem> stockItems = [];
  bool isLoading = true;
  String? errorMessage;

  final StockService _stockService = StockService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    loadStock();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadStock() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _stockService.loadStock(widget.profile);

      setState(() {
        storeName = data['storeName'];
        stockItems = data['stockItems'] as List<StockItem>;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  Future<void> updateQuantity(int productId, int newQuantity) async {
    try {
      await _stockService.updateQuantity(storeName!, productId, newQuantity);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Количество обновлено'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      loadStock();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> deleteProduct(int productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _stockService.updateQuantity(storeName!, productId, 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Товар удалён со склада'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      loadStock();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  void showProductDetails(StockItem item) {
    showDialog(
      context: context,
      builder: (context) => StockItemDialog(
        item: item,
        onUpdate: (newQty) =>
            updateQuantity(item.productId, newQty), // ← правильно
        onDelete: () => deleteProduct(item.productId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : stockItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 100,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'На складе пусто',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Товары появятся после приёмки поставок',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          color: theme.cardColor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storage_outlined,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Склад: $storeName',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: stockItems.length,
                          itemBuilder: (context, index) {
                            final item = stockItems[index];
                            return StockItemCard(
                              item: item,
                              onTap: () => showProductDetails(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
