import 'dart:io';
import 'package:d_and_f_final/models/stock_item.dart';
import 'package:d_and_f_final/models/profile.dart';
import '/services/stock_service.dart';
import 'widgets/stock_item_card.dart';
import 'widgets/stock_item_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/material.dart';

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

  void showProductDetails(StockItem stockItem) {
    final itemMap = {
      'product_id': stockItem.productId,
      'name': stockItem.name,
      'country': stockItem.country,
      'price': stockItem.price,
      'quantity': stockItem.quantity,
      'image_url': stockItem.imageUrl,
      'about': stockItem.about,
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

  Future<void> _exportFullStockToCsv() async {
    if (stockItems.isEmpty) {
      _showSnack('На складе нет товаров для экспорта');
      return;
    }

    try {
      final List<List<String>> csvData = [
        [
          '#',
          'Product',
          'Country',
          'Price (BYN)',
          'Quantity',
          'Unit',
          'Total (BYN)',
        ],
      ];

      double totalValue = 0;

      for (int i = 0; i < stockItems.length; i++) {
        final item = stockItems[i];
        final sum = item.quantity * item.price;
        totalValue += sum;

        csvData.add([
          '${i + 1}',
          item.name,
          item.country,
          item.price.toStringAsFixed(2),
          item.quantity.toString(),
          'шт',
          sum.toStringAsFixed(2),
        ]);
      }

      csvData.add(['', '', '', '', '', '', '']);
      csvData.add([
        'Итого:',
        '',
        '',
        '',
        '',
        '',
        totalValue.toStringAsFixed(2),
      ]);

      final csvString = csvData.map((row) => row.join(';')).join('\n');

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/остатки_склада_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final file = File(path);
      await file.writeAsString('sep=;\n$csvString');

      final result = await OpenFilex.open(path);

      if (result.type != ResultType.done) {
        _showSnack('Не удалось открыть файл: ${result.message}', isError: true);
      } else {
        _showSnack('CSV открыт! Распечатайте из Excel', isSuccess: true);
      }
    } catch (e) {
      _showSnack('Ошибка экспорта CSV: $e', isError: true);
    }
  }

  Future<void> _exportFullStockToPdf() async {
    if (stockItems.isEmpty) {
      _showSnack('На складе нет товаров для экспорта');
      return;
    }

    try {
      final pdf = PdfDocument();
      final page = pdf.pages.add();

      final fontData = await DefaultAssetBundle.of(
        context,
      ).load('assets/fonts/DejaVuSans.ttf');
      final fontBytes = fontData.buffer.asUint8List();
      final ttf = PdfTrueTypeFont(fontBytes, 12);
      final boldTtf = PdfTrueTypeFont(fontBytes, 12, style: PdfFontStyle.bold);

      page.graphics.drawString(
        'Остатки склада: $storeName',
        boldTtf,
        bounds: const Rect.fromLTWH(0, 0, 500, 50),
      );

      final grid = PdfGrid();
      grid.columns.add(count: 7);

      final headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = '№';
      headerRow.cells[1].value = 'Товар';
      headerRow.cells[2].value = 'Страна';
      headerRow.cells[3].value = 'Цена (BYN)';
      headerRow.cells[4].value = 'Количество';
      headerRow.cells[5].value = 'Ед. изм.';
      headerRow.cells[6].value = 'Сумма (BYN)';

      headerRow.style.font = boldTtf;
      headerRow.style.backgroundBrush = PdfSolidBrush(PdfColor(200, 200, 200));

      double totalValue = 0;

      for (int i = 0; i < stockItems.length; i++) {
        final item = stockItems[i];
        final sum = item.quantity * item.price;
        totalValue += sum;

        final row = grid.rows.add();
        row.cells[0].value = '${i + 1}';
        row.cells[1].value = item.name;
        row.cells[2].value = item.country;
        row.cells[3].value = item.price.toStringAsFixed(2);
        row.cells[4].value = item.quantity.toString();
        row.cells[5].value = 'шт';
        row.cells[6].value = sum.toStringAsFixed(2);
      }

      final totalRow = grid.rows.add();
      totalRow.cells[0].value = 'Итого:';
      totalRow.cells[6].value = totalValue.toStringAsFixed(2);
      totalRow.style.font = boldTtf;
      totalRow.style.backgroundBrush = PdfSolidBrush(PdfColor(220, 220, 220));

      grid.style.cellPadding = PdfPaddings(
        left: 5,
        top: 5,
        right: 5,
        bottom: 5,
      );
      grid.style.font = ttf;

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          80,
          page.getClientSize().width,
          page.getClientSize().height - 80,
        ),
      );

      final bytes = await pdf.save();
      pdf.dispose();

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/остатки_склада_${DateTime.now().toIso8601String().substring(0, 10)}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(path);

      if (result.type != ResultType.done) {
        _showSnack('Не удалось открыть PDF: ${result.message}', isError: true);
      } else {
        _showSnack(
          'PDF открыт! Распечатайте или импортируйте',
          isSuccess: true,
        );
      }
    } catch (e) {
      _showSnack('Ошибка экспорта PDF: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Остатки склада'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: stockItems.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: 80 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _exportFullStockToCsv,
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Экспорт CSV'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: colorScheme.primary.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _exportFullStockToPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Экспорт PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: colorScheme.secondary.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 80,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          errorMessage!,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: loadStock,
                          child: const Text('Повторить'),
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
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'На складе пусто',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Товары появятся после приёмки поставок',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: colorScheme.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  color: colorScheme.primary,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Склад: $storeName',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator.adaptive(
                          onRefresh: loadStock,
                          color: colorScheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
