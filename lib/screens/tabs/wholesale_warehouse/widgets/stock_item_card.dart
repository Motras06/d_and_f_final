// lib/screens/tabs/wholesale_warehouse/widgets/stock_item_card.dart
import 'package:flutter/material.dart';

class StockItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const StockItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<StockItemCard> createState() => _StockItemCardState();
}

class _StockItemCardState extends State<StockItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    // Запускаем анимацию с небольшой задержкой (для stagger-эффекта в списке)
    Future.delayed(Duration(milliseconds: 100 * (widget.item.hashCode % 10)), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getQuantityColor(int qty, ColorScheme colorScheme) {
    if (qty > 10) return colorScheme.primary; // синий (много)
    if (qty > 0) return Colors.orangeAccent;   // оранжевый (мало)
    return colorScheme.error;                  // красный (0)
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = widget.item['name'] as String? ?? 'Без названия';
    final country = widget.item['country'] as String? ?? '—';
    final price = widget.item['price'] as num? ?? 0;
    final unit = widget.item['unit'] as String? ?? 'шт';
    final qty = widget.item['quantity'] as int? ?? 0;
    final imageUrl = widget.item['image_url'] as String?;
    final about = widget.item['about'] as String?;

    final priceText = price > 0 ? '${price.toStringAsFixed(0)} BYN / $unit' : 'Цена не указана';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.20),
                blurRadius: 16,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Card(
            elevation: 0, // тень уже от контейнера
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: colorScheme.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фото товара
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              },
                              errorBuilder: (_, __, ___) => _placeholderIcon(colorScheme),
                            )
                          : _placeholderIcon(colorScheme),
                    ),

                    const SizedBox(width: 16),

                    // Основная информация
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          Text(
                            '$country • $priceText',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),

                          if (about != null && about.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              about,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withOpacity(0.85),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Остаток (большой и заметный)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Остаток',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getQuantityColor(qty, colorScheme).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$qty',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _getQuantityColor(qty, colorScheme),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 80,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 40,
        color: colorScheme.primary.withOpacity(0.6),
      ),
    );
  }
}