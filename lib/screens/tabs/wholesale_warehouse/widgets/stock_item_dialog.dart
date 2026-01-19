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

    final name = item['name'] as String? ?? 'Товар без названия';
    final country = item['country'] as String? ?? '—';
    final price = (item['price'] as num?)?.toStringAsFixed(2) ?? '—';
    final priceWithVat = (item['price_with_vat'] as num?)?.toStringAsFixed(2) ?? '—';
    final unit = item['unit'] as String? ?? 'шт';
    final vatRate = (item['vat_rate'] as num?)?.toStringAsFixed(1) ?? '20.0';
    final vatAmount = (item['vat_amount'] as num?)?.toStringAsFixed(2) ?? '—';
    final about = item['about'] as String?;
    final imageUrl = item['image_url'] as String?;
    final createdAt = item['created_at'] as String?; // можно отформатировать позже

    final qty = item['quantity'] as int? ?? 0;
    final qtyColor = qty > 10
        ? Colors.green
        : (qty > 0 ? Colors.orange : Colors.red);

    // QR-код
    final safeData = {
      'id': item['product_id'],
      'name': name,
      'price': price,
      'quantity': qty,
    };
    final qrData = jsonEncode(safeData);
    final qrUrl = 'https://quickchart.io/qr?text=$qrData&size=300&margin=20';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.cardColor,
      elevation: 16,
      contentPadding: const EdgeInsets.all(0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок с именем товара
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фото товара
                  if (imageUrl != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage(theme),
                        ),
                      ),
                    ),
                  if (imageUrl != null) const SizedBox(height: 24),

                  // Основная информация
                  _infoCard(
                    context,
                    title: 'Основная информация',
                    children: [
                      _infoRow(Icons.label_outline, 'Страна', country),
                      _infoRow(Icons.monetization_on_outlined, 'Цена (без НДС)', '$price ₽'),
                      _infoRow(Icons.price_check, 'Цена с НДС', '$priceWithVat ₽'),
                      _infoRow(Icons.straighten, 'Единица измерения', unit),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // НДС информация
                  _infoCard(
                    context,
                    title: 'НДС',
                    children: [
                      _infoRow(Icons.percent, 'Ставка НДС', '$vatRate%'),
                      _infoRow(Icons.attach_money, 'Сумма НДС', '$vatAmount ₽'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Описание
                  if (about != null && about.isNotEmpty)
                    _infoCard(
                      context,
                      title: 'Описание',
                      children: [
                        Text(
                          about,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Текущее количество + поле ввода
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

                  const SizedBox(height: 24),

                  // QR-код
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'QR-код товара',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.network(
                            qrUrl,
                            width: 180,
                            height: 180,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 180,
                                height: 180,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.qr_code_2,
                              size: 120,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                Share.share(
                  'Товар: $name\n'
                  'Страна: $country\n'
                  'Цена: $price ₽ (с НДС $priceWithVat ₽)\n'
                  'Остаток: $qty $unit\n'
                  'QR-код: $qrUrl',
                  subject: 'Информация о товаре: $name',
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Поделиться'),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDelete,
                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final newQty = int.tryParse(controller.text) ?? 0;
                    Navigator.pop(context);
                    onUpdate(newQty);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ],
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

  Widget _placeholderImage(ThemeData theme) {
    return Container(
      height: 180,
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 80,
          color: theme.colorScheme.primary.withOpacity(0.4),
        ),
      ),
    );
  }
}