import 'package:flutter/material.dart';

class StockItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const StockItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = item['price'] as num?;
    final qty = item['quantity'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item['image_url'] != null
                    ? Image.network(
                        item['image_url'],
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcon(theme),
                      )
                    : _placeholderIcon(theme),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '—',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['country'] ?? '—'} • ${price?.toStringAsFixed(0) ?? '?'} ₽ / ${item['unit'] ?? 'шт'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (item['about'] != null && (item['about'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item['about'],
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Остаток', style: TextStyle(color: Colors.grey[600])),
                  Text(
                    '$qty',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: qty > 10 ? Colors.green : (qty > 0 ? Colors.orange : Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Container(
      width: 70,
      height: 70,
      color: theme.colorScheme.surfaceVariant,
      child: Icon(Icons.inventory_2_outlined, size: 36, color: theme.colorScheme.primary),
    );
  }
}