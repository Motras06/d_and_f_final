// lib/screens/tabs/supplier/widgets/delivery_product_card.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/product.dart';

class DeliveryProductCard extends StatefulWidget {
  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  const DeliveryProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  State<DeliveryProductCard> createState() => _DeliveryProductCardState();
}

class _DeliveryProductCardState extends State<DeliveryProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _increment() {
    widget.onQuantityChanged(widget.quantity + 1);
  }

  void _decrement() {
    if (widget.quantity > 0) {
      widget.onQuantityChanged(widget.quantity - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[700];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(_isHovered ? 0.3 : 0.15),
                blurRadius: _isHovered ? 24 : 12,
                offset: const Offset(0, 8),
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: theme.colorScheme.primary.withOpacity(0.1),
                highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Фото товара
                      Hero(
                        tag: 'delivery_product_image_${widget.product.id}',
                        child: Container(
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
                            child: widget.product.imageUrl != null
                                ? Image.network(
                                    widget.product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 40,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  )
                                : Icon(
                                    Icons.inventory_2_outlined,
                                    size: 40,
                                    color: theme.colorScheme.primary,
                                  ),
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
                              widget.product.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Цена: ${widget.product.price} Руб',
                              style: TextStyle(
                                fontSize: 16,
                                color: subtitleColor,
                              ),
                            ),
                            if (widget.product.country.isNotEmpty)
                              Text(
                                widget.product.country,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Количество с кнопками +/-
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _decrement,
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: widget.quantity > 0 ? theme.colorScheme.primary : theme.disabledColor,
                              size: 32,
                            ),
                            splashRadius: 24,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${widget.quantity}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _increment,
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            splashRadius: 24,
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
      ),
    );
  }
}