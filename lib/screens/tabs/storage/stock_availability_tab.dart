import 'dart:io';
import 'package:d_and_f_final/models/stock_item.dart';
import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';
import '/services/stock_service.dart';
import 'widgets/stock_item_card.dart';
import 'widgets/stock_item_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      loadStock();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }

  void showProductDetails(StockItem stockItem) {
  // Костыль: преобразуем StockItem в Map
  final itemMap = {
    'product_id': stockItem.productId,
    'name': stockItem.name,
    'country': stockItem.country,
    'price': stockItem.price,
    'quantity': stockItem.quantity,
    'image_url': stockItem.imageUrl,
    'about': stockItem.about,
    // если есть другие поля — добавь их сюда
  };

  showDialog(
    context: context,
    builder: (context) => StockItemDialog(
      item: itemMap,
      onUpdate: (newQty) => updateQuantity(stockItem.productId, newQty),
      onDelete: () => deleteProduct(stockItem.productId),
    ),
  );
}

  // НОВЫЙ МЕТОД: Экспорт ВСЕГО склада в CSV
  Future<void> _exportFullStockToCsv() async {
    if (stockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На складе нет товаров для экспорта')),
      );
      return;
    }

    try {
      // Формируем CSV
      final List<List<String>> csvData = [
        ['№', 'Товар', 'Количество', 'Ед. изм.', 'Цена с НДС (₽)', 'Сумма (₽)'],
      ];

      double totalValue = 0;

      for (int i = 0; i < stockItems.length; i++) {
        final item = stockItems[i];
        final sum = item.quantity * (item.price);
        totalValue += sum;

        csvData.add([
          '${i + 1}',
          item.name,
          item.quantity.toString(),
          'шт',
          (item.price).toStringAsFixed(2),
          sum.toStringAsFixed(2),
        ]);
      }

      csvData.add([]); // пустая строка
      csvData.add(['Итого по складу:', '', '', '', '', totalValue.toStringAsFixed(2)]);

      final csvString = csvData.map((row) => row.join(';')).join('\n');

      // Сохраняем файл
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/остатки_склада_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final file = File(path);
      await file.writeAsString('sep=;\n$csvString'); // sep=; для корректного открытия в Excel RU

      // Открываем файл (Excel / Sheets предложит открыть и распечатать)
      final result = await OpenFilex.open(path);

      if (result.type != ResultType.done) {
        _showSnack('Не удалось открыть файл: ${result.message}', isError: true);
      } else {
        _showSnack('Файл открыт! Распечатайте из Excel / Google Sheets', isSuccess: true);
      }
    } catch (e) {
      _showSnack('Ошибка экспорта: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // отступ от bottom nav
        child: FloatingActionButton.extended(
          onPressed: stockItems.isEmpty ? null : _exportFullStockToCsv,
          icon: const Icon(Icons.table_chart),
          label: const Text('Экспорт всего склада в CSV (Excel)'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
                            const SizedBox(height: 24),
                            Text(errorMessage!, style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      )
                    : stockItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey[600]),
                                const SizedBox(height: 24),
                                const Text(
                                  'На складе пусто',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Товары появятся после приёмки поставок',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  color: theme.cardColor,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.storage_outlined, size: 32, color: theme.colorScheme.primary),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Склад: $storeName',
                                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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