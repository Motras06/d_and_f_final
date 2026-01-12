// lib/screens/tabs/supplier/widgets/product_filter_dialog.dart
import 'package:flutter/material.dart';

class ProductFilterDialog extends StatefulWidget {
  final Map<String, dynamic> initialFilters;

  const ProductFilterDialog({
    super.key,
    required this.initialFilters,
  });

  @override
  State<ProductFilterDialog> createState() => _ProductFilterDialogState();
}

class _ProductFilterDialogState extends State<ProductFilterDialog> {
  late double? _minPrice;
  late double? _maxPrice;
  late bool _inStockOnly;

  @override
  void initState() {
    super.initState();
    _minPrice = widget.initialFilters['minPrice'] as double?;
    _maxPrice = widget.initialFilters['maxPrice'] as double?;
    _inStockOnly = widget.initialFilters['inStockOnly'] == true;
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};

    if (_minPrice != null && _minPrice! > 0) {
      filters['minPrice'] = _minPrice;
    }
    if (_maxPrice != null && _maxPrice! > 0) {
      filters['maxPrice'] = _maxPrice;
    }
    if (_inStockOnly) {
      filters['inStockOnly'] = true;
    }

    Navigator.pop(context, filters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Фильтры',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Цена от
            Text('Цена от', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Например: 100',
                suffixText: 'Руб',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? ''),
              onChanged: (value) {
                _minPrice = double.tryParse(value);
              },
            ),
            const SizedBox(height: 20),

            // Цена до
            Text('Цена до', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Например: 5000',
                suffixText: 'Руб',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? ''),
              onChanged: (value) {
                _maxPrice = double.tryParse(value);
              },
            ),
            const SizedBox(height: 24),

            // Только в наличии
            SwitchListTile(
              title: const Text('Только в наличии'),
              value: _inStockOnly,
              onChanged: (value) {
                setState(() => _inStockOnly = value);
              },
              activeColor: theme.colorScheme.primary,
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _applyFilters,
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}