// lib/screens/storage_home.dart
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
import 'tabs/storage/supplies_tab.dart';
import 'tabs/storage/products_tab.dart';
import 'tabs/storage/storage_profile_tab.dart';

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
          SuppliesTab(
            assignedStore: assignedStore,
            isLoadingSupplies: _isLoadingSupplies,
            deliveries: _deliveries,
            onAcceptDelivery: _acceptDelivery,
            onRejectDelivery: _rejectDelivery,
          ),
          ProductsTab(
            assignedStore: assignedStore,
            isLoadingProducts: _isLoadingProducts,
            storeProducts: _storeProducts,
            showQrDialog: _showQrDialog,
          ),
          StorageProfileTab(
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
    super.dispose();
  }
}