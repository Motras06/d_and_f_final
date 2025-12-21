// lib/screens/tabs/supplier/widgets/product_form_dialog.dart

import 'dart:io';

import 'package:d_and_f_final/models/product.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:d_and_f_final/services/product_service.dart';

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
  bool isUploading = false;

  final ImagePicker _picker = ImagePicker();

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
    _animationController.dispose();
    nameController.dispose();
    countryController.dispose();
    priceController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Это действие нельзя отменить. Товар будет удалён навсегда.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isUploading = true);

    try {
      await widget.productService.deleteProduct(widget.existingProduct!.id);

      if (mounted) {
        Navigator.pop(context, true); // возвращаем true — товар удалён
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingProduct != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.cardColor,
      elevation: 20,
      shadowColor: theme.shadowColor.withOpacity(0.3),
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
                // Фото товара
                GestureDetector(
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() => pickedImage = image);
                    }
                  },
                  child: Hero(
                    tag: 'product_image_${widget.existingProduct?.id ?? 'new'}',
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
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
                                      Icons.image_not_supported_outlined,
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
                ),
                const SizedBox(height: 32),

                // Поля ввода
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Название товара',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countryController,
                  decoration: InputDecoration(
                    labelText: 'Страна',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Цена (₽)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.1),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.1),
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
          child: Text('Отмена', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
        ),
        if (isEdit)
          TextButton(
            onPressed: isUploading ? null : _deleteProduct,
            child: const Text('Удалить товар', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ElevatedButton(
          onPressed: isUploading
              ? null
              : () async {
                  if (nameController.text.trim().isEmpty ||
                      countryController.text.trim().isEmpty ||
                      priceController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Заполните обязательные поля'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  setState(() => isUploading = true);

                  try {
                    if (isEdit) {
                      await widget.productService.updateProduct(
                        productId: widget.existingProduct!.id,
                        name: nameController.text.trim(),
                        country: countryController.text.trim(),
                        price: num.parse(priceController.text.trim()),
                        about: aboutController.text.trim().isEmpty ? null : aboutController.text.trim(),
                        newImage: pickedImage,
                        currentImageUrl: currentImageUrl,
                      );
                    } else {
                      await widget.productService.createProduct(
                        name: nameController.text.trim(),
                        country: countryController.text.trim(),
                        price: num.parse(priceController.text.trim()),
                        about: aboutController.text.trim().isEmpty ? null : aboutController.text.trim(),
                        image: pickedImage,
                        userId: widget.userId,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Товар обновлён!' : 'Товар создан!'),
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
                    if (mounted) setState(() => isUploading = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 6,
          ),
          child: isUploading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 3),
                )
              : Text(isEdit ? 'Сохранить' : 'Создать', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}