// lib/screens/supplier_home.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_storage.dart';
import '../screens/role_select_screen.dart';
import '/app_colors.dart';
import '../repository.dart';
import '../models.dart';
import 'tabs/supplier/create_product_tab.dart';
import 'tabs/supplier/create_delivery_tab.dart';
import 'tabs/supplier/profile_tab.dart';

class SupplierHome extends StatefulWidget {
  final String username;
  const SupplierHome({required this.username, super.key});

  @override
  State<SupplierHome> createState() => _SupplierHomeState();
}

class _SupplierHomeState extends State<SupplierHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _aboutController = TextEditingController();
  final _priceController = TextEditingController();
  File? _selectedImage;
  final picker = ImagePicker();
  bool _isProductSubmitting = false;

  String? mail;
  String? username;
  String? role;
  String? passwordMasked;
  bool isLoadingProfile = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Map<int, int> _selectedProducts = {};
  String? _selectedStore;
  bool _isDeliverySubmitting = false;

  List<Product> _products = [];
  List<String> _stores = [];
  bool _isLoadingDeliveryData = true;

  final _repo = SupabaseRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadDeliveryData();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoadingProfile = true);
    try {
      final profile = await _repo.getCurrentProfile();
      if (profile != null) {
        setState(() {
          mail = profile.mail;
          username = profile.username;
          role = profile.role;
          passwordMasked = '********';
          _usernameController.text = username ?? '';
          _passwordController.text = '';
          isLoadingProfile = false;
        });
      } else {
        _showStyledSnackBar('Ошибка: профиль не найден', isError: true);
      }
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    } finally {
      setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _updateProfile() async {
    try {
      await _repo.updateProfile(_usernameController.text);
      if (_passwordController.text.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passwordController.text));
      }
      _showStyledSnackBar('Профиль обновлён');
      await _loadProfile();
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    await AppLocalStorage.clearAccount();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _loadDeliveryData() async {
    setState(() => _isLoadingDeliveryData = true);
    try {
      final products = await _repo.getProducts();
      final storesResponse = await Supabase.instance.client.from('stores').select('name');
      setState(() {
        _products = products;
        _stores = storesResponse.map((s) => s['name'] as String).toList();
        _isLoadingDeliveryData = false;
      });
    } catch (e) {
      _showStyledSnackBar('Ошибка загрузки данных: $e', isError: true);
      setState(() => _isLoadingDeliveryData = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> submitProduct() async {
    if (_nameController.text.isEmpty ||
        _countryController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedImage == null) {
      _showStyledSnackBar(
        "Пожалуйста, заполните все обязательные поля",
        isError: true,
      );
      return;
    }
    setState(() => _isProductSubmitting = true);
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('image_s').upload(fileName, _selectedImage!);
      final imageUrl = Supabase.instance.client.storage.from('image_s').getPublicUrl(fileName);

      await _repo.upsertProduct(Product(
        id: 0,
        name: _nameController.text,
        country: _countryController.text,
        about: _aboutController.text,
        price: double.parse(_priceController.text),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      ));

      _showStyledSnackBar("Товар успешно добавлен");
      _nameController.clear();
      _countryController.clear();
      _aboutController.clear();
      _priceController.clear();
      setState(() => _selectedImage = null);
      _loadDeliveryData(); // Reload products after adding
    } catch (e) {
      _showStyledSnackBar("Ошибка: $e", isError: true);
    } finally {
      setState(() => _isProductSubmitting = false);
    }
  }

  Future<void> submitDelivery() async {
    setState(() => _isDeliverySubmitting = true);
    try {
      final items = _selectedProducts.entries
          .where((e) => e.value > 0)
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList();
      await _repo.createDelivery(_selectedStore!, items);
      _showStyledSnackBar('Поставка создана');
      setState(() {
        _selectedProducts = {};
        _selectedStore = null;
      });
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    } finally {
      setState(() => _isDeliverySubmitting = false);
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.surface),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Поставщик'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.surface,
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.surface.withOpacity(0.7),
          tabAlignment: TabAlignment.fill,
          tabs: const [
            Tab(icon: Icon(Icons.add_box_outlined), text: 'Создать'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Поставка'),
            Tab(icon: Icon(Icons.person_outline), text: 'Профиль'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateProductTab(
            nameController: _nameController,
            countryController: _countryController,
            aboutController: _aboutController,
            priceController: _priceController,
            selectedImage: _selectedImage,
            isProductSubmitting: _isProductSubmitting,
            onPickImage: pickImage,
            onSubmit: submitProduct,
          ),
          CreateDeliveryTab(
            isLoadingDeliveryData: _isLoadingDeliveryData,
            products: _products,
            stores: _stores,
            selectedStore: _selectedStore,
            selectedProducts: _selectedProducts,
            onStoreChanged: (v) => setState(() => _selectedStore = v),
            onQuantityChanged: (id, qty) {
              if (qty < 0) qty = 0;
              setState(() => _selectedProducts[id] = qty);
            },
            isDeliverySubmitting: _isDeliverySubmitting,
            onSubmitDelivery: submitDelivery,
          ),
          ProfileTab(
            isLoadingProfile: isLoadingProfile,
            mail: mail,
            passwordMasked: passwordMasked,
            usernameController: _usernameController,
            passwordController: _passwordController,
            onUpdateProfile: _updateProfile,
            onLogout: () => _logout(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _aboutController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}