// lib/screens/tabs/storage/widgets/stock_item_dialog.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:d_and_f_final/models/stock_item.dart';

class StockItemDialog extends StatelessWidget {
  final StockItem item;
  final ValueChanged<int> onUpdate;
  final VoidCallback onDelete;

  const StockItemDialog({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController(text: item.quantity.toString());

    final safeProduct = {
      'id': item.productId,
      'name': item.name,
      'country': item.country,
      'price': item.price,
      'quantity': item.quantity,
      'about': item.about ?? '',
    };

    final qrData = jsonEncode(safeProduct);

    // QuickChart.io — стабильный и быстрый
    final qrUrl =
        'https://quickchart.io/qr?text=$qrData&size=300&margin=20&light=ffffff&dark=121212';

    void shareQR() {
      Share.share(
        'QR-код товара\n\n${item.name}\nЦена: ${item.price} ₽\nОстаток: ${item.quantity}\n\nСсылка для сканирования: $qrUrl',
        subject: 'QR-код товара: ${item.name}',
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: theme.cardColor,
      elevation: 20,
      shadowColor: theme.shadowColor.withOpacity(0.5),
      title: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.primary.withOpacity(0.3),
                    Colors.transparent,
                  ]
                : [
                    theme.colorScheme.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Text(
          item.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Фото товара
              if (item.imageUrl != null)
                Center(
                  child: Hero(
                    tag: 'product_image_${item.productId}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        item.imageUrl!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 100,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // QR-код — супер пупер дизайн
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        qrUrl,
                        width: 260,
                        height: 260,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: 260,
                            height: 260,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.qr_code_2,
                          size: 120,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Отсканируйте для деталей',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Информация о товаре
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(
                    isDark ? 0.3 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Страна происхождения', item.country, theme),
                    const SizedBox(height: 12),
                    _infoRow('Цена', '${item.price} Руб', theme),
                    if (item.about != null && item.about!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Описание',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.about!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Редактирование количества — супер пупер
              Text(
                'Изменить количество на складе',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '${item.quantity}',
                  filled: true,
                  fillColor: theme.colorScheme.surface.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Закрыть',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: shareQR,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Поделиться QR'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final newQty = int.tryParse(controller.text) ?? item.quantity;
            Navigator.pop(context);
            onUpdate(newQty);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: const Text(
            'Сохранить',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          child: const Text(
            'Удалить товар',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
