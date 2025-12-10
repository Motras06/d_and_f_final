import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/local_storage.dart';
import '../screens/role_select_screen.dart';
import '/app_colors.dart';
import '../repository.dart';

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product['name'] ?? 'Товар'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product['image_url'] != null &&
                  product['image_url'].toString().isNotEmpty)
                Center(
                  child: Image.network(
                    product['image_url'],
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 250,
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 100,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Без названия',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Цена:",
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          "${product['price'] ?? '-'} ₽",
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Количество:",
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          "${product['quantity'] ?? '-'}",
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      "Описание",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product['about'] ?? 'Описание отсутствует',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HallHome extends StatefulWidget {
  final String username;
  const HallHome({required this.username, super.key});

  @override
  State<HallHome> createState() => _HallHomeState();
}

class _HallHomeState extends State<HallHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> stores = ["Магазин 1", "Магазин 2", "Магазин 3"];
  String? _selectedStoreForProducts;
  List<Map<String, dynamic>> _storeProducts = [];
  bool _isLoadingProducts = false;

  String? mail;
  String? username;
  String? role;
  String? passwordMasked;
  bool isLoadingProfile = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repo = SupabaseRepository();

  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _torchEnabled = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => isLoadingProfile = true);
    try {
      final profile = await _repo.getCurrentProfile();
      if (profile != null) {
        setState(() {
          mail = profile.mail;
          username = profile.username;
          role = profile.role;
          passwordMasked = '********'; // No masked password from DB, handle differently if needed
          _usernameController.text = username ?? '';
          _passwordController.text = '';
          isLoadingProfile = false;
        });
      } else {
        _showStyledSnackBar('Ошибка: профиль не найден', isError: true);
        setState(() => isLoadingProfile = false);
      }
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
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

  Future<void> _loadProductsForStore(String storeName) async {
    setState(() => _isLoadingProducts = true);
    try {
      // Get products with stock for the store (custom query: join products and store_stock)
      final response = await Supabase.instance.client.from('products').select('*, store_stock!inner(quantity)').eq('store_stock.store_name', storeName);
      setState(() {
        _storeProducts = response.map((p) => {
          'id': p['id'],
          'name': p['name'],
          'price': p['price'],
          'image_url': p['image_url'],
          'about': p['about'],
          'quantity': p['store_stock'][0]['quantity'] ?? 0,
        }).toList();
        _isLoadingProducts = false;
      });
    } catch (e) {
      _showStyledSnackBar('Ошибка загрузки продуктов: $e', isError: true);
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _fetchProductById(String id) async {
    try {
      final response = await Supabase.instance.client.from('products').select().eq('id', int.parse(id)).single();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: response),
          ),
        );
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Пользователь'),
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
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Сканер'),
            Tab(icon: Icon(Icons.store_outlined), text: 'Товары'),
            Tab(icon: Icon(Icons.person_outline), text: 'Профиль'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScannerTab(),
          _buildProductsTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        if (_isScanning)
          MobileScanner(
            controller: cameraController,
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue != _lastScannedCode) {
                  setState(() {
                    _lastScannedCode = barcode.rawValue;
                    _isScanning = false;
                  });
                  _fetchProductById(barcode.rawValue!);
                }
              }
            },
          ),
        if (!_isScanning)
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _lastScannedCode = null;
                });
              },
              child: const Text('Повторить сканирование'),
            ),
          ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: () {
              cameraController.toggleTorch();
              setState(() => _torchEnabled = !_torchEnabled);
            },
            child: Icon(_torchEnabled ? Icons.flash_off : Icons.flash_on),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            value: _selectedStoreForProducts,
            items: stores.map((store) => DropdownMenuItem(value: store, child: Text(store))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStoreForProducts = value);
                _loadProductsForStore(value);
              }
            },
            decoration: const InputDecoration(labelText: 'Выберите магазин'),
          ),
        ),
        if (_isLoadingProducts)
          const Center(child: CircularProgressIndicator()),
        if (!_isLoadingProducts && _storeProducts.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _storeProducts.length,
              itemBuilder: (context, index) {
                final product = _storeProducts[index];
                return ListTile(
                  leading: product['image_url'] != null
                      ? Image.network(product['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported),
                  title: Text(product['name'] ?? 'Без названия'),
                  subtitle: Text('${product['price'] ?? '-'} ₽'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  ),
                );
              },
            ),
          ),
        if (!_isLoadingProducts && _storeProducts.isEmpty && _selectedStoreForProducts != null)
          const Center(child: Text('Нет товаров в этом магазине')),
      ],
    );
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
    cameraController.dispose();
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
    // ignore: unused_element_parameter
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