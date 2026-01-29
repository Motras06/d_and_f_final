// lib/screens/tabs/wholesale_warehouse/widgets/stock_item_dialog.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class StockItemDialog extends StatefulWidget {
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
  State<StockItemDialog> createState() => _StockItemDialogState();
}

class _StockItemDialogState extends State<StockItemDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _qtyController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final initialQty = widget.item['quantity'] as int? ?? 0;
    _qtyController = TextEditingController(text: initialQty.toString());

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Color _getQuantityColor(int qty, ColorScheme colorScheme) {
    if (qty > 10) return colorScheme.primary;
    if (qty > 0) return Colors.orangeAccent;
    return colorScheme.error;
  }

  String _getPriceText(num? price) {
    return price != null && price > 0
        ? '${price.toStringAsFixed(0)} BYN'
        : 'По договорённости';
  }

  void _shareProduct() {
    final name = widget.item['name'] as String? ?? 'Товар';
    final country = widget.item['country'] as String? ?? '—';
    final price = widget.item['price'] as num?;
    final qty = widget.item['quantity'] as int? ?? 0;
    final unit = widget.item['unit'] as String? ?? 'шт';

    final text =
        '$name\n'
        'Страна: $country\n'
        'Цена: ${_getPriceText(price)}\n'
        'Остаток: $qty $unit';

    Share.share(text, subject: 'Товар: $name');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = widget.item['name'] as String? ?? 'Товар без названия';
    final country = widget.item['country'] as String? ?? '—';
    final price = widget.item['price'] as num?;
    final priceWithVat = widget.item['price_with_vat'] as num?;
    final unit = widget.item['unit'] as String? ?? 'шт';
    final vatRate = widget.item['vat_rate'] as num? ?? 20.0;
    final vatAmount = widget.item['vat_amount'] as num?;
    final about = widget.item['about'] as String?;
    final imageUrl = widget.item['image_url'] as String?;
    final qty = widget.item['quantity'] as int? ?? 0;

    final priceText = _getPriceText(price);
    final priceWithVatText = priceWithVat != null && priceWithVat > 0
        ? '${priceWithVat.toStringAsFixed(0)} BYN'
        : '—';

    final vatAmountText = vatAmount != null && vatAmount > 0
        ? '${vatAmount.toStringAsFixed(2)} BYN'
        : '—';

    final qrData = jsonEncode({
      'id': widget.item['product_id'],
      'name': name,
      'price': priceText,
      'quantity': qty,
    });
    final qrUrl = 'https://quickchart.io/qr?text=$qrData&size=300&margin=20';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: colorScheme.surfaceContainerLow,
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Содержимое (скроллируемое)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Фото
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (_, __, ___) =>
                                    _placeholderImage(colorScheme),
                              ),
                            ),
                          ),
                        ),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        const SizedBox(height: 24),

                      // Основная информация
                      _buildInfoCard(
                        context,
                        title: 'Основная информация',
                        children: [
                          _buildInfoRow(
                            Icons.label_outline_rounded,
                            'Страна',
                            country,
                          ),
                          _buildInfoRow(
                            Icons.monetization_on_rounded,
                            'Цена (без НДС)',
                            priceText,
                          ),
                          _buildInfoRow(
                            Icons.price_check_rounded,
                            'Цена с НДС',
                            priceWithVatText,
                          ),
                          _buildInfoRow(
                            Icons.straighten_rounded,
                            'Единица измерения',
                            unit,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // НДС
                      _buildInfoCard(
                        context,
                        title: 'НДС',
                        children: [
                          _buildInfoRow(
                            Icons.percent_rounded,
                            'Ставка НДС',
                            '$vatRate%',
                          ),
                          _buildInfoRow(
                            Icons.attach_money_rounded,
                            'Сумма НДС',
                            vatAmountText,
                          ),
                        ],
                      ),

                      if (about != null && about.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          context,
                          title: 'Описание',
                          children: [
                            Text(
                              about,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Количество
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Текущее количество на складе',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _getQuantityColor(
                                  qty,
                                  colorScheme,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$qty $unit',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _getQuantityColor(qty, colorScheme),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Новое количество',
                                labelStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // QR-код
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'QR-код товара',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.network(
                                qrUrl,
                                width: 180,
                                height: 180,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(
                                        width: 180,
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 120,
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Кнопки в матрице 2×2
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareProduct,
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Поделиться'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(color: colorScheme.outline),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Закрыть'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_rounded, size: 18),
                            label: const Text('Удалить'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              final newQty =
                                  int.tryParse(_qtyController.text) ?? 0;
                              Navigator.pop(context);
                              widget.onUpdate(newQty);
                            },
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Сохранить'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                              shadowColor: colorScheme.primary.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Методы _buildInfoCard, _buildInfoRow, _placeholderImage остаются без изменений
  // (вставь их из предыдущей версии, если нужно)

  Widget _placeholderImage(ColorScheme colorScheme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 80,
          color: colorScheme.primary.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // Методы _buildInfoCard, _buildInfoRow, _placeholderImage остаются без изменений
  // (если нужно — вставь их из предыдущей версии)
  // ... остальные методы (_buildInfoCard, _buildInfoRow, _placeholderImage) остаются без изменений ...


}
