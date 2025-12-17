// lib/screens/tabs/supplier/widgets/product_form_dialog.dart

import 'dart:io';

import 'package:d_and_f_final/models/product.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:d_and_f_final/screens/tabs/supplier/services/product_service.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductService productService;
  final String userId;
  final Product? existingProduct; // null = создание, не null = редактирование

  const ProductFormDialog({
    super.key,
    required this.productService,
    required this.userId,
    this.existingProduct,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late TextEditingController nameController;
  late TextEditingController countryController;
  late TextEditingController priceController;
  late TextEditingController aboutController;

  XFile? pickedImage;
  String? currentImageUrl;
  bool isUploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final product = widget.existingProduct;

    nameController = TextEditingController(text: product?.name ?? '');
    countryController = TextEditingController(text: product?.country ?? '');
    priceController = TextEditingController(text: product?.price.toString() ?? '');
    aboutController = TextEditingController(text: product?.about ?? '');
    currentImageUrl = product?.imageUrl;
  }

  @override
  void dispose() {
    nameController.dispose();
    countryController.dispose();
    priceController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProduct != null;

    return AlertDialog(
      title: Text(isEdit ? 'Редактирование товара' : 'Новый товар'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => pickedImage = image);
                }
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(pickedImage!.path), fit: BoxFit.cover),
                      )
                    : currentImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(currentImageUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.add_a_photo_outlined, size: 60, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: countryController, decoration: const InputDecoration(labelText: 'Страна', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена (₽)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: aboutController, maxLines: 4, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(
          onPressed: isUploading ? null : () async {
            if (nameController.text.trim().isEmpty || countryController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните обязательные поля'), backgroundColor: Colors.red));
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

              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEdit ? 'Товар обновлён!' : 'Товар создан!'), backgroundColor: Colors.green),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
            } finally {
              setState(() => isUploading = false);
            }
          },
          child: isUploading ? const CircularProgressIndicator() : Text(isEdit ? 'Сохранить' : 'Создать'),
        ),
      ],
    );
  }
}