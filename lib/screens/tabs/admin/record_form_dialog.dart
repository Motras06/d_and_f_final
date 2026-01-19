import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class RecordFormDialog extends StatefulWidget {
  final String tableName;
  final bool isEdit;
  final Map<String, dynamic>? initialData;

  const RecordFormDialog({
    super.key,
    required this.tableName,
    required this.isEdit,
    this.initialData,
  });

  @override
  State<RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> formData = {};
  File? _selectedImage;
  String? _imageUrl;
  bool _isUploading = false;

  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.initialData != null) {
      formData = Map.from(widget.initialData!);
      _imageUrl = formData['image_url'] as String?;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isUploading = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${const Uuid().v4()}.jpg';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 70,
        minHeight: 800,
        minWidth: 800,
      );

      if (compressed == null) throw Exception('Сжатие не удалось');

      final fileBytes = await compressed.readAsBytes();
      final fileName = 'products/${const Uuid().v4()}.jpg';

      await supabase.storage.from('images').uploadBinary(fileName, fileBytes);
      final publicUrl = supabase.storage.from('images').getPublicUrl(fileName);

      setState(() {
        formData['image_url'] = publicUrl;
        _imageUrl = publicUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото загружено'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Редактировать' : 'Добавить запись'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imageUrl != null || _selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, height: 150, fit: BoxFit.cover)
                          : Image.network(_imageUrl!, height: 150, fit: BoxFit.cover),
                    ),
                  ),

                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickImage,
                  icon: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image),
                  label: Text(_isUploading ? 'Загрузка...' : 'Выбрать фото'),
                ),

                const SizedBox(height: 16),

                ..._buildFormFields(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(context, formData);
            }
          },
          child: Text(widget.isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    final fieldTypes = _getFieldTypes();

    return fieldTypes.entries.map((entry) {
      final field = entry.key;
      final type = entry.value;

      if (field == 'image_url') return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: formData[field]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.replaceAll('_', ' ').toUpperCase(),
            border: OutlineInputBorder(),
          ),
          keyboardType: type == 'numeric' ? TextInputType.number : TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              if (['name', 'price', 'quantity'].contains(field)) {
                return 'Обязательное поле';
              }
            }
            return null;
          },
          onSaved: (value) {
            if (type == 'numeric') {
              formData[field] = num.tryParse(value ?? '') ?? 0;
            } else {
              formData[field] = value;
            }
          },
        ),
      );
    }).toList();
  }

  Map<String, String> _getFieldTypes() {
    switch (widget.tableName) {
      case 'products':
        return {
          'name': 'text',
          'country': 'text',
          'price': 'numeric',
          'image_url': 'text',
          'about': 'text',
          'unit_of_measure': 'text',
          'vat_rate': 'numeric',
          'vat_amount': 'numeric',
          'price_with_vat': 'numeric',
        };
      case 'stores':
        return {'name': 'text'};
      case 'profiles':
        return {'mail': 'text', 'username': 'text', 'role': 'text'};
      case 'suppliers':
        return {
          'name': 'text',
          'email': 'text',
          'phone': 'text',
          'inn': 'text',
          'address': 'text',
          'contact_person': 'text',
          'notes': 'text',
        };
      case 'deliveries':
        return {'supplier_id': 'text', 'store_name': 'text', 'status': 'text'};
      case 'delivery_items':
        return {'delivery_id': 'number', 'product_id': 'number', 'quantity': 'number'};
      case 'store_stock':
        return {'store_name': 'text', 'product_id': 'number', 'quantity': 'number'};
      default:
        return {'name': 'text'};
    }
  }
}