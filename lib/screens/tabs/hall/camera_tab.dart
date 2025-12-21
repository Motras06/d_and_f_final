import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );

  bool isProcessing = false;
  final supabase = Supabase.instance.client;

  late AnimationController _scanAnimationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanLineAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    controller.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_updateUI);
    controller.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(Barcode barcode) async {
    if (isProcessing) return;
    final code = barcode.rawValue;
    if (code == null) return;

    setState(() => isProcessing = true);

    try {
      final data = Map<String, dynamic>.from(jsonDecode(code));
      final productId = data['id'] as int?;

      if (productId == null) {
        _showSnackBar('Неверный QR-код: нет ID товара');
        return;
      }

      final response = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      if (!mounted) return;

      _showProductDetails(response);
    } catch (e) {
      _showSnackBar('Товар не найден или неверный QR-код');
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(product['name'] as String, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (product['image_url'] != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        product['image_url'] as String,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Страна: ${product['country']}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Цена: ${product['price']} ₽',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product['about'] != null &&
                    (product['about'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Описание:\n${product['about']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlayColor = isDark
        ? Colors.black.withOpacity(0.7)
        : Colors.black.withOpacity(0.5);

    final torchState = controller.value.torchState;
    final torchEnabled = torchState == TorchState.on;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleBarcode(barcode);
                  break;
                }
              }
            },
          ),

          Container(color: overlayColor),

          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),

                ...List.generate(4, (index) {
                  return Positioned(
                    top: index < 2 ? 0 : null,
                    bottom: index >= 2 ? 0 : null,
                    left: index == 0 || index == 3 ? 0 : null,
                    right: index == 1 || index == 2 ? 0 : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border(
                          top: index < 2
                              ? BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 6,
                                )
                              : BorderSide.none,
                          bottom: index >= 2
                              ? BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 6,
                                )
                              : BorderSide.none,
                          left: index == 0 || index == 3
                              ? BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 6,
                                )
                              : BorderSide.none,
                          right: index == 1 || index == 2
                              ? BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 6,
                                )
                              : BorderSide.none,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: index == 0
                              ? const Radius.circular(32)
                              : Radius.zero,
                          topRight: index == 1
                              ? const Radius.circular(32)
                              : Radius.zero,
                          bottomLeft: index == 3
                              ? const Radius.circular(32)
                              : Radius.zero,
                          bottomRight: index == 2
                              ? const Radius.circular(32)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  );
                }),

                AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(0, _scanLineAnimation.value),
                      child: Container(
                        width: 260,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 100,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(
                'Наведите камеру на QR-код товара',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: theme.cardColor.withOpacity(0.8),
              foregroundColor: theme.colorScheme.primary,
              onPressed: () => controller.toggleTorch(),
              child: Icon(torchEnabled ? Icons.flash_on : Icons.flash_off),
            ),
          ),

          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 5,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Обработка QR-кода...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
