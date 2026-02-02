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

  final _priceController = TextEditingController();
  final _vatRateController = TextEditingController();
  final _vatAmountController = TextEditingController();
  final _priceWithVatController = TextEditingController();

  final _supplierEmailController = TextEditingController();
  String? _foundSupplierName;
  String? _foundSupplierId;
  bool _searchingSupplier = false;

  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  static const int _targetImageSizeBytes = 500 * 1024; // 500 КБ

  @override
  void initState() {
    super.initState();

    _vatRateController.text = '20';

    if (widget.isEdit && widget.initialData != null) {
      formData = Map.from(widget.initialData!);
      _imageUrl = formData['image_url'] as String?;

      _priceController.text = (formData['price'] ?? 0).toString();
      _vatRateController.text = (formData['vat_rate'] ?? 20).toString();
      _vatAmountController.text = (formData['vat_amount'] ?? 0).toStringAsFixed(
        2,
      );
      _priceWithVatController.text = (formData['price_with_vat'] ?? 0)
          .toStringAsFixed(2);

      if (formData['supplier_id'] != null) {
        _loadSupplierName(formData['supplier_id']);
      }
    }

    _priceController.addListener(_recalculateVat);
    _vatRateController.addListener(_recalculateVat);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateVat();
    });
  }

  Future<void> _loadSupplierName(String supplierId) async {
    try {
      final res = await supabase
          .from('profiles')
          .select('username, mail')
          .eq('id', supplierId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _foundSupplierName = res['username'] ?? res['mail'] ?? 'Поставщик';
          _foundSupplierId = supplierId;
        });
      }
    } catch (_) {}
  }

  Future<void> _searchSupplierByEmail() async {
    final email = _supplierEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _searchingSupplier = true);

    try {
      final res = await supabase
          .from('profiles')
          .select('id, username, mail')
          .eq('mail', email)
          .eq('role', 'supplier')
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _foundSupplierId = res['id'];
          _foundSupplierName = res['username'] ?? res['mail'] ?? 'Без имени';
          formData['supplier_id'] = _foundSupplierId;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Поставщик: $_foundSupplierName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Поставщик с таким email не найден'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка поиска: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searchingSupplier = false);
    }
  }

  void _recalculateVat() {
    final priceText = _priceController.text.trim();
    final vatRateText = _vatRateController.text.trim();

    double price = double.tryParse(priceText) ?? 0;
    double vatRate = double.tryParse(vatRateText) ?? 20;

    if (price < 0) price = 0;
    if (vatRate < 0) vatRate = 0;

    final vatAmount = price * (vatRate / 100);
    final priceWithVat = price + vatAmount;

    _vatAmountController.text = vatAmount.toStringAsFixed(2);
    _priceWithVatController.text = priceWithVat.toStringAsFixed(2);

    formData['price'] = price;
    formData['vat_rate'] = vatRate;
    formData['vat_amount'] = vatAmount;
    formData['price_with_vat'] = priceWithVat;
  }

  Future<File> _compressToTargetSize(File original) async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final unique = const Uuid().v4();
      final targetPath = '${tempDir.path}/img_compress_$unique.jpg';

      XFile? result = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        targetPath,
        quality: 80,
        minHeight: 1200,
        minWidth: 1200,
        rotate: 0,
        format: CompressFormat.jpeg,
        numberOfRetries: 5,
      );

      if (result != null) {
        final size = await result.length();
        debugPrint("Сжато (80): ${size / 1024} KB");

        if (size <= _targetImageSizeBytes) {
          return File(result.path);
        }

        final targetPath2 = '${tempDir.path}/img_compress_${unique}_low.jpg';
        result = await FlutterImageCompress.compressAndGetFile(
          original.absolute.path,
          targetPath2,
          quality: 60,
          minHeight: 1000,
          minWidth: 1000,
          format: CompressFormat.jpeg,
        );

        if (result != null) {
          debugPrint("Сжато (60): ${(await result.length()) / 1024} KB");
          return File(result.path);
        }
      }

      debugPrint("Сжатие вернуло null → оригинал");
      return original;
    } catch (e, st) {
      debugPrint("Ошибка сжатия: $e\n$st");
      return original;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final originalFile = File(picked.path);

      setState(() {
        _selectedImage = originalFile;
        _isUploading = true;
      });

      final fileToUpload = await _compressToTargetSize(originalFile);
      final bytes = await fileToUpload.readAsBytes();
      final sizeKb = (bytes.lengthInBytes / 1024).toStringAsFixed(1);

      final fileName = 'products/product_${const Uuid().v4()}.jpg';

      await supabase.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = supabase.storage.from('images').getPublicUrl(fileName);

      if (!mounted) return;

      setState(() {
        formData['image_url'] = publicUrl;
        _imageUrl = publicUrl;
        _selectedImage = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Фото загружено (~$sizeKb КБ)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Ошибка загрузки фото: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colorScheme.surfaceContainerLow,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      title: Text(
        widget.isEdit ? 'Редактировать запись' : 'Добавить новую запись',
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Фото
                if (_imageUrl != null || _selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _imageUrl != null
                            ? Image.network(
                                _imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      size: 80,
                                      color: Colors.grey,
                                    ),
                              )
                            : Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ),

                Center(
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(_isUploading ? 'Загрузка...' : 'Выбрать фото'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                if (widget.tableName == 'products') ...[
                  Text('Поставщик', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _supplierEmailController,
                          decoration: InputDecoration(
                            labelText: 'Email поставщика',
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: _searchingSupplier
                            ? null
                            : _searchSupplierByEmail,
                        icon: _searchingSupplier
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (_foundSupplierName != null) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(_foundSupplierName!),
                      subtitle: Text('ID: $_foundSupplierId'),
                      tileColor: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _foundSupplierName = null;
                            _foundSupplierId = null;
                            _supplierEmailController.clear();
                            formData.remove('supplier_id');
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                ..._buildFormFields(),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              _recalculateVat();
              Navigator.pop(context, formData);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(widget.isEdit ? 'Сохранить изменения' : 'Добавить'),
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fieldTypes = _getFieldTypes();

    List<Widget> fields = [];

    fieldTypes.entries.forEach((entry) {
      final field = entry.key;
      final type = entry.value;

      if ([
        'vat_amount',
        'price_with_vat',
        'supplier_id',
        'image_url',
      ].contains(field)) {
        return;
      }

      final label = field
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');

      if (field == 'price') {
        fields.add(
          _buildNumberField(
            label: label,
            controller: _priceController,
            required: true,
            suffixText: 'BYN',
          ),
        );
        return;
      }

      if (field == 'vat_rate') {
        fields.add(
          _buildNumberField(
            label: 'Ставка НДС',
            controller: _vatRateController,
            required: true,
            suffixText: '%',
          ),
        );
        return;
      }

      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextFormField(
            initialValue: formData[field]?.toString() ?? '',
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
            ),
            keyboardType: type == 'numeric'
                ? TextInputType.number
                : TextInputType.text,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                if (['name', 'price', 'quantity', 'vat_rate'].contains(field)) {
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
        ),
      );
    });

    fields.add(_buildReadonlyField('Сумма НДС', _vatAmountController, 'BYN'));
    fields.add(
      _buildReadonlyField('Цена с НДС', _priceWithVatController, 'BYN'),
    );

    return fields;
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? suffixText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: required
            ? (value) {
                final trimmed = value?.trim();
                if (trimmed == null || trimmed.isEmpty)
                  return 'Обязательное поле';
                if (double.tryParse(trimmed) == null) return 'Введите число';
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildReadonlyField(
    String label,
    TextEditingController controller,
    String suffix,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.65),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
      ),
    );
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
        return {
          'delivery_id': 'number',
          'product_id': 'number',
          'quantity': 'number',
        };
      case 'store_stock':
        return {
          'store_name': 'text',
          'product_id': 'number',
          'quantity': 'number',
        };
      default:
        return {'name': 'text'};
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _vatRateController.dispose();
    _vatAmountController.dispose();
    _priceWithVatController.dispose();
    _supplierEmailController.dispose();
    super.dispose();
  }
}
