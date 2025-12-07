import 'dart:typed_data' show ByteData, Uint8List;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/local_storage.dart';
import '../screens/role_select_screen.dart';
import '/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repository.dart';

class StorageHome extends StatefulWidget {
  final String username;
  const StorageHome({required this.username, super.key});

  @override
  State<StorageHome> createState() => _StorageHomeState();
}

class _StorageHomeState extends State<StorageHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String? mail;
  String? username;
  String? role;
  String? passwordMasked;
  bool isLoadingProfile = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<String> stores = ["Магазин 1", "Магазин 2", "Магазин 3"];

  String? assignedStore;

  bool _isLoadingSupplies = false;
  List<Map<String, dynamic>> _deliveries = [];

  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> _storeProducts = [];

  final _repo = SupabaseRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadAssignedStore().then((_) {
      if (assignedStore != null) {
        _loadDeliveriesForStore(assignedStore!);
        _loadProductsForStore(assignedStore!);
      } else {
        Future.microtask(() => _showStoreSelectionDialog(initial: true));
      }
    });
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
    await AppLocalStorage.saveStore(null);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _loadAssignedStore() async {
    try {
      final s = await AppLocalStorage.getSavedStore();
      setState(() {
        assignedStore = s;
      });
    } catch (e) {
      setState(() {
        assignedStore = null;
      });
    }
  }

  Future<void> _showStoreSelectionDialog({bool initial = false}) async {
    String? picked = initial ? null : assignedStore;

    await showDialog(
      context: context,
      barrierDismissible: !initial,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState2) {
          return AlertDialog(
            title: Text(initial ? 'Выберите магазин' : 'Сменить магазин'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: picked,
                  items: stores
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState2(() {
                      picked = v;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Магазин'),
                ),
              ],
            ),
            actions: [
              if (!initial)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ElevatedButton(
                onPressed: picked == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _saveAndAssignStore(picked!);
                      },
                child: const Text('Сохранить'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _saveAndAssignStore(String store) async {
    try {
      await Supabase.instance.client.from('store_assignments').insert({
        'store_name': store,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
      });
      await AppLocalStorage.saveStore(store);
      setState(() => assignedStore = store);
      _loadDeliveriesForStore(store);
      _loadProductsForStore(store);
      _showStyledSnackBar('Магазин назначен');
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    }
  }

  Future<void> _loadDeliveriesForStore(String storeName) async {
    setState(() => _isLoadingSupplies = true);
    try {
      final deliveries = await _repo.getStoreDeliveries(storeName);
      final deliveriesWithItems = <Map<String, dynamic>>[];
      for (var delivery in deliveries) {
        final items = await _repo.getDeliveryItems(delivery.id);
        deliveriesWithItems.add({
          ...delivery.toMap(),
          'items': items.map((item) => item.toMap()).toList(),
        });
      }
      setState(() {
        _deliveries = deliveriesWithItems;
        _isLoadingSupplies = false;
      });
    } catch (e) {
      _showStyledSnackBar('Ошибка загрузки поставок: $e', isError: true);
      setState(() => _isLoadingSupplies = false);
    }
  }

  Future<void> _acceptDelivery(int deliveryId, String storeName, List<Map<String, dynamic>> items) async {
    try {
      await _repo.updateDeliveryStatus(deliveryId, 'accepted');
      for (var item in items) {
        await Supabase.instance.client.from('store_stock').upsert({
          'store_name': storeName,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        }, onConflict: 'store_name, product_id');
      }
      _showStyledSnackBar('Поставка принята');
      _loadDeliveriesForStore(storeName);
      _loadProductsForStore(storeName);
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    }
  }

  Future<void> _rejectDelivery(int deliveryId, String storeName) async {
    try {
      await _repo.updateDeliveryStatus(deliveryId, 'rejected');
      _showStyledSnackBar('Поставка отклонена');
      _loadDeliveriesForStore(storeName);
    } catch (e) {
      _showStyledSnackBar('Ошибка: $e', isError: true);
    }
  }

  Future<void> _loadProductsForStore(String storeName) async {
    setState(() => _isLoadingProducts = true);
    try {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Склад'),
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
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Поставки'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Товары'),
            Tab(icon: Icon(Icons.person_outline), text: 'Профиль'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuppliesTab(),
          _buildProductsTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  Widget _buildSuppliesTab() {
    if (assignedStore == null) {
      return const Center(child: Text('Магазин не выбран'));
    }
    if (_isLoadingSupplies) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _deliveries.length,
      itemBuilder: (context, index) {
        final delivery = _deliveries[index];
        return Card(
          child: ExpansionTile(
            title: Text('Поставка #${delivery['id']} - ${delivery['status']}'),
            subtitle: Text('От: ${delivery['supplier_id']}'),
            children: [
              ...delivery['items'].map((item) => ListTile(
                    title: Text('Товар ID: ${item['product_id']}'),
                    subtitle: Text('Количество: ${item['quantity']}'),
                  )),
              if (delivery['status'] == 'pending')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptDelivery(delivery['id'], assignedStore!, delivery['items']),
                      child: const Text('Принять'),
                    ),
                    ElevatedButton(
                      onPressed: () => _rejectDelivery(delivery['id'], assignedStore!),
                      child: const Text('Отклонить'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (assignedStore == null) {
      return const Center(child: Text('Магазин не выбран'));
    }
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _storeProducts.length,
      itemBuilder: (context, index) {
        final product = _storeProducts[index];
        final GlobalKey qrKey = GlobalKey();
        return Card(
          child: ListTile(
            leading: product['image_url'] != null
                ? Image.network(product['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported),
            title: Text(product['name'] ?? 'Без названия'),
            subtitle: Text('Количество: ${product['quantity']}'),
            trailing: ElevatedButton(
              onPressed: () => _showQrDialog(product, qrKey),
              child: const Text('QR'),
            ),
          ),
        );
      },
    );
  }

  void _showQrDialog(Map<String, dynamic> product, GlobalKey qrKey) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('QR для ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: qrKey,
                child: QrImageView(
                  data: '${product['id']}',
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        RenderRepaintBoundary boundary =
                            qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        Uint8List pngBytes = byteData!.buffer.asUint8List();
                        final tempDir = await getTemporaryDirectory();
                        final file = await File('${tempDir.path}/qr_${product['id']}.png').create();
                        await file.writeAsBytes(pngBytes);
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          text: "QR-код товара: ${product['name']} (${product['price']} ₽)",
                        );
                      } catch (e) {
                        _showStyledSnackBar("Ошибка при создании QR: $e", isError: true);
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Поделиться"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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