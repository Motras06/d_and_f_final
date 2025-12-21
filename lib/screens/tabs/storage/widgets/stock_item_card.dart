// lib/screens/tabs/storage/widgets/stock_item_card.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/stock_item.dart';

class StockItemCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onTap;

  const StockItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: theme.cardColor,
        shadowColor: theme.shadowColor.withOpacity(0.3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Фото товара
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_outlined,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: theme.colorScheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Информация
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.country} • ${item.price} ₽',
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (item.about != null && item.about!.isNotEmpty)
                            Text(
                              item.about!,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // Остаток
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Остаток',
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          '${item.quantity}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: item.quantity > 10
                                ? Colors.green
                                : (item.quantity > 0 ? Colors.orange : Colors.red),
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
}