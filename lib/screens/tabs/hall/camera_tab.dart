// lib/screens/tabs/hall/camera_tab.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );

  bool isProcessing = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    controller.dispose();
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
        setState(() => isProcessing = false);
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
      _showSnackBar('Ошибка: неверный формат или товар не найден');
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['name'] as String),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product['image_url'] != null)
                Center(
                  child: Image.network(
                    product['image_url'] as String,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Страна: ${product['country']}'),
              Text('Цена: ${product['price']} ₽'),
              if (product['about'] != null &&
                  (product['about'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Описание:\n${product['about']}'),
                ),
            ],
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
    return Stack(
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

        // Рамка для сканирования
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Подсказка
        Positioned(
          bottom: 80,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Наведите камеру на QR-код товара',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),

        // Кнопка фонарика (исправленная!)
        // Кнопка фонарика (рабочая для mobile_scanner 5.x)
        Positioned(
          top: 60,
          right: 20,
          child: IconButton(
            iconSize: 40,
            color: Colors.white,
            icon: StreamBuilder<bool>(
              stream: controller.torchEnabledStream,
              initialData: false,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return Icon(enabled ? Icons.flash_on : Icons.flash_off);
              },
            ),
            onPressed: () async {
              await controller.toggleTorch();
            },
          ),
        ),

        // Индикатор обработки
        if (isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

extension on MobileScannerController {
  Stream<bool>? get torchEnabledStream => null;
}
