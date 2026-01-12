import 'dart:io';

import 'package:d_and_f_final/models/product.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:d_and_f_final/services/product_service.dart';
import 'package:image/image.dart' as img; // зависимость: image: ^4.2.0

class ProductFormDialog extends StatefulWidget {
  final ProductService productService;
  final String userId;
  final Product? existingProduct;

  const ProductFormDialog({
    super.key,
    required this.productService,
    required this.userId,
    this.existingProduct,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> with SingleTickerProviderStateMixin {
  late TextEditingController nameController;
  late TextEditingController countryController;
  late TextEditingController priceController;
  late TextEditingController aboutController;

  XFile? pickedImage;
  String? currentImageUrl;
  bool isProcessing = false;

  final ImagePicker _picker = ImagePicker();
  final int targetSizeKb = 500;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final product = widget.existingProduct;

    nameController = TextEditingController(text: product?.name ?? '');
    countryController = TextEditingController(text: product?.country ?? '');
    priceController = TextEditingController(text: product?.price.toString() ?? '');
    aboutController = TextEditingController(text: product?.about ?? '');

    currentImageUrl = product?.imageUrl;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    countryController.dispose();
    priceController.dispose();
    aboutController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить. Товар будет удалён навсегда.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isProcessing = true);

    try {
      await widget.productService.deleteProduct(widget.existingProduct!.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар удалён'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<XFile?> _compressImage(XFile original) async {
    try {
      final bytes = await original.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return original;

      int quality = 85;
      List<int> compressed = img.encodeJpg(image, quality: quality);

      while (compressed.length > targetSizeKb * 1024 && quality > 30) {
        quality -= 10;
        compressed = img.encodeJpg(image, quality: quality);
      }

      if (compressed.length > targetSizeKb * 1024) {
        final resized = img.copyResize(image, width: (image.width * 0.7).round());
        compressed = img.encodeJpg(resized, quality: 75);
      }

      final tempDir = await Directory.systemTemp.createTemp();
      final path = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(compressed);

      return XFile(path);
    } catch (e) {
      debugPrint('Ошибка сжатия изображения: $e');
      return original;
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isProcessing = true);

    final compressed = await _compressImage(image);
    if (compressed != null) {
      setState(() {
        pickedImage = compressed;
      });
    }

    setState(() => isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingProduct != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.cardColor,
      elevation: 20,
      contentPadding: const EdgeInsets.all(24),
      title: Text(
        isEdit ? 'Редактирование товара' : 'Новый товар',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Блок изображения
                GestureDetector(
                  onTap: isProcessing ? null : _pickImage,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: pickedImage != null
                          ? Image.file(File(pickedImage!.path), fit: BoxFit.cover)
                          : currentImageUrl != null
                              ? Image.network(
                                  currentImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 60,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 60,
                                  color: theme.colorScheme.primary,
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  pickedImage != null || (isEdit && currentImageUrl != null)
                      ? 'Нажмите, чтобы заменить фото'
                      : 'Нажмите, чтобы добавить фото',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 32),

                // Поля ввода
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Название товара',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countryController,
                  decoration: InputDecoration(
                    labelText: 'Страна',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Цена (Руб)',
                    prefixIcon: const Icon(Icons.money_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: aboutController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Описание (необязательно)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        if (isEdit)
          TextButton(
            onPressed: isProcessing ? null : _deleteProduct,
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        FilledButton(
          onPressed: isProcessing
              ? null
              : () async {
                  final name = nameController.text.trim();
                  final country = countryController.text.trim();
                  final priceText = priceController.text.trim();

                  if (name.isEmpty || country.isEmpty || priceText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заполните обязательные поля')),
                    );
                    return;
                  }

                  final price = num.tryParse(priceText);
                  if (price == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Некорректная цена')),
                    );
                    return;
                  }

                  setState(() => isProcessing = true);

                  try {
                    if (isEdit) {
                      await widget.productService.updateProduct(
                        productId: widget.existingProduct!.id,
                        name: name,
                        country: country,
                        price: price,
                        about: aboutController.text.trim().isEmpty ? null : aboutController.text.trim(),
                        newImage: pickedImage,
                        currentImageUrl: currentImageUrl,
                      );
                    } else {
                      await widget.productService.createProduct(
                        name: name,
                        country: country,
                        price: price,
                        about: aboutController.text.trim().isEmpty ? null : aboutController.text.trim(),
                        image: pickedImage,
                        userId: widget.userId,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Товар обновлён' : 'Товар добавлен'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка: $e'),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isProcessing = false);
                  }
                },
          child: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}