import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_storage.dart';
import '../screens/role_select_screen.dart';
import '/app_colors.dart';
import '../repository.dart';
import '../models.dart';

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
          _buildCreateProductTab(),
          _buildCreateDeliveryTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  Widget _buildCreateProductTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _buildInputDecoration(
              labelText: 'Название товара',
              icon: Icons.label_outline,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: _buildInputDecoration(
              labelText: 'Страна',
              icon: Icons.public_outlined,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aboutController,
            decoration: _buildInputDecoration(
              labelText: 'Описание',
              icon: Icons.description_outlined,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            decoration: _buildInputDecoration(
              labelText: 'Цена',
              icon: Icons.attach_money_outlined,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Выбрать изображение'),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Image.file(_selectedImage!, height: 200),
            ),
          const SizedBox(height: 24),
          _isProductSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: submitProduct,
                  child: const Text('Добавить товар'),
                ),
        ],
      ),
    );
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
      await Supabase.instance.client.storage.from('product_images').upload(fileName, _selectedImage!);
      final imageUrl = Supabase.instance.client.storage.from('product_images').getPublicUrl(fileName);

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

  Widget _buildCreateDeliveryTab() {
    if (_isLoadingDeliveryData) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStore,
            items: _stores.map((store) => DropdownMenuItem(value: store, child: Text(store))).toList(),
            onChanged: (value) => setState(() => _selectedStore = value),
            decoration: const InputDecoration(labelText: 'Выберите магазин'),
          ),
          const SizedBox(height: 24),
          const Text('Выберите товары:'),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final qty = _selectedProducts[product.id] ?? 0;
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${product.price} ₽'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (qty > 0) {
                          setState(() => _selectedProducts[product.id] = qty - 1);
                        }
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$qty'),
                    IconButton(
                      onPressed: () => setState(() => _selectedProducts[product.id] = qty + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _isDeliverySubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _selectedStore == null || _selectedProducts.isEmpty ? null : submitDelivery,
                  child: const Text('Создать поставку'),
                ),
        ],
      ),
    );
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

  Widget _buildProfileTab() {
    if (isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 100),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary,
              child: Icon(
                Icons.person,
                size: 60,
                color: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 200),
            child: Card(
              elevation: 2,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.email_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(mail ?? 'Email не найден'),
                    subtitle: const Text('Email (нельзя изменить'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.security_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(passwordMasked ?? 'Пароль не задан'),
                    subtitle: const Text('Текущий пароль'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 300),
            child: TextFormField(
              controller: _usernameController,
              decoration: _buildInputDecoration(
                labelText: 'Имя пользователя',
                icon: Icons.person_outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 400),
            child: TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: _buildInputDecoration(
                labelText: 'Новый пароль (необязательно)',
                icon: Icons.vpn_key_outlined,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 500),
            child: ElevatedButton.icon(
              onPressed: _updateProfile,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить изменения'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FadeInSlideUp(
            delay: const Duration(milliseconds: 600),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Выйти из аккаунта'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
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

class _FadeInSlideUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const _FadeInSlideUp({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<_FadeInSlideUp> createState() => _FadeInSlideUpState();
}

class _FadeInSlideUpState extends State<_FadeInSlideUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}