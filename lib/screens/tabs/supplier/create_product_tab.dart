// lib/screens/create_product_tab.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '/app_colors.dart';

class CreateProductTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController countryController;
  final TextEditingController aboutController;
  final TextEditingController priceController;
  final File? selectedImage;
  final bool isProductSubmitting;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;

  const CreateProductTab({
    super.key,
    required this.nameController,
    required this.countryController,
    required this.aboutController,
    required this.priceController,
    required this.selectedImage,
    required this.isProductSubmitting,
    required this.onPickImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            decoration: _buildInputDecoration(
              labelText: 'Название товара',
              icon: Icons.label_outline,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: countryController,
            decoration: _buildInputDecoration(
              labelText: 'Страна',
              icon: Icons.public_outlined,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: aboutController,
            decoration: _buildInputDecoration(
              labelText: 'Описание',
              icon: Icons.description_outlined,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: priceController,
            decoration: _buildInputDecoration(
              labelText: 'Цена',
              icon: Icons.attach_money_outlined,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Выбрать изображение'),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Image.file(selectedImage!, height: 200),
            ),
          const SizedBox(height: 24),
          isProductSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: onSubmit,
                  child: const Text('Добавить товар'),
                ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppColors.primaryLight),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error, width: 2.0),
      ),
    );
  }
}