import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class StockItemDialog extends StatelessWidget {
  final Map<String, dynamic> item;
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

    final controller = TextEditingController(text: (item['quantity'] ?? 0).toString());

    // Извлекаем все поля безопасно
    final name = item['name'] as String? ?? 'Товар без названия';
    final country = item['country'] as String? ?? '—';
    final price = (item['price'] as num?)?.toStringAsFixed(2) ?? '—';
    final priceWithVat = (item['price_with_vat'] as num?)?.toStringAsFixed(2) ?? '—';
    final unit = item['unit_of_measure'] as String? ?? 'шт';
    final vatRate = (item['vat_rate'] as num?)?.toStringAsFixed(1) ?? '20.0';
    final vatAmount = (item['vat_amount'] as num?)?.toStringAsFixed(2) ?? '—';
    final about = item['about'] as String?;
    final imageUrl = item['image_url'] as String?;
    final createdAt = item['created_at'] != null
        ? (item['created_at'] as String).substring(0, 10)
        : '—';

    final qty = item['quantity'] as int? ?? 0;
    final qtyColor = qty > 10
        ? Colors.green
        : (qty > 0 ? Colors.orange : Colors.red);

    // QR-код
    final safeData = {
      'id': item['product_id'],
      'name': name,
      'country': country,
      'price': price,
      'priceWithVat': priceWithVat,
      'quantity': qty,
      'unit': unit,
    };
    final qrData = jsonEncode(safeData);
    final qrUrl = 'https://quickchart.io/qr?text=$qrData&size=300&margin=20&light=ffffff&dark=121212';

    void shareQR() {
      Share.share(
        'QR-код товара\n\n'
        'Название: $name\n'
        'Страна: $country\n'
        'Цена: $price BYN (с НДС $priceWithVat BYN)\n'
        'Остаток: $qty $unit\n'
        'Описание: ${about ?? '—'}\n'
        'Ссылка для сканирования: $qrUrl',
        subject: 'QR-код товара: $name',
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
                ? [theme.colorScheme.primary.withOpacity(0.3), Colors.transparent]
                : [theme.colorScheme.primary.withOpacity(0.2), Colors.transparent],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Text(
          name,
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
              if (imageUrl != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
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
              if (imageUrl != null) const SizedBox(height: 32),

              // QR-код
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
                          return const SizedBox(
                            width: 260,
                            height: 260,
                            child: Center(child: CircularProgressIndicator()),
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

              // Основная информация
              _infoCard(
                context,
                title: 'Основные характеристики',
                children: [
                  _infoRow(Icons.flag_outlined, 'Страна происхождения', country),
                  _infoRow(Icons.monetization_on_outlined, 'Цена без НДС', '$price BYN'),
                  _infoRow(Icons.price_check, 'Цена с НДС', '$priceWithVat BYN'),
                  _infoRow(Icons.straighten, 'Единица измерения', unit),
                  _infoRow(Icons.calendar_today_outlined, 'Добавлен', createdAt),
                ],
              ),

              const SizedBox(height: 16),

              // НДС
              _infoCard(
                context,
                title: 'НДС',
                children: [
                  _infoRow(Icons.percent, 'Ставка НДС', '$vatRate%'),
                  _infoRow(Icons.attach_money, 'Сумма НДС', '$vatAmount BYN'),
                ],
              ),

              const SizedBox(height: 16),

              // Описание
              if (about != null && about.isNotEmpty)
                _infoCard(
                  context,
                  title: 'Описание товара',
                  children: [
                    Text(
                      about,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // Количество
              Center(
                child: Column(
                  children: [
                    Text(
                      'Текущее количество на складе',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$qty $unit',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: qtyColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Новое количество',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: shareQR,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Поделиться QR'),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final newQty = int.tryParse(controller.text) ?? qty;
                    Navigator.pop(context);
                    onUpdate(newQty);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                  child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceEvenly,
    );
  }

  Widget _infoCard(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}