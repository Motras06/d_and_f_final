import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];

  String? selectedSupplierId;
  Map<int, int> cart = {};

  bool isLoading = false;
  String searchQuery = '';

  String? userStoreName; // кэшируем магазин пользователя один раз

  @override
  void initState() {
    super.initState();
    _loadUserStore(); // сначала узнаём магазин
    _loadSuppliers();
  }

  /// Загружаем магазин текущего пользователя один раз
  Future<void> _loadUserStore() async {
    try {
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();

      if (assignment != null && assignment['store_name'] != null) {
        setState(() {
          userStoreName = assignment['store_name'] as String;
        });
      }
    } catch (e) {
      // тихо игнорируем, покажем ошибку только при попытке заказа
    }
  }

  Future<void> _loadSuppliers() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('suppliers')
          .select('id, name, email, phone')
          .order('name');
      if (mounted) {
        setState(() {
          suppliers = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showSnack('Ошибка загрузки поставщиков: $e', isError: true);
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadProducts() async {
    if (selectedSupplierId == null) return;

    setState(() {
      isLoading = true;
      products = [];
    });

    try {
      var query = supabase
          .from('products')
          .select('id, name, price, price_with_vat, unit_of_measure, image_url')
          .eq('supplier_id', selectedSupplierId!);

      if (searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }

      final data = await query.order('name');

      if (mounted) {
        setState(() {
          products = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showSnack('Ошибка загрузки товаров: $e', isError: true);
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _addToCart(int productId, int qty) {
    setState(() {
      cart[productId] = (cart[productId] ?? 0) + qty;
      if (cart[productId] == 0) cart.remove(productId);
    });
  }

  Future<void> _showAddDialog(Map<String, dynamic> product) async {
    final name = product['name'] as String? ?? 'Товар';
    final unit = product['unit_of_measure'] as String? ?? 'шт';
    final productId = product['id'] as int?;

    if (productId == null) {
      _showSnack('Ошибка: у товара нет ID', isError: true);
      return;
    }

    final qtyController = TextEditingController(text: '1');

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(name),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Количество ($unit)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Обязательно';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Минимум 1';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );

    final qtyText = qtyController.text.trim();
    final qty = int.tryParse(qtyText) ?? 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      qtyController.dispose();
    });

    if (confirmed != true || !mounted) return;

    _addToCart(productId, qty);
    _showSnack('Добавлено $qty × $name в корзину', isSuccess: true);
  }

  Future<void> _addToStore() async {
    if (cart.isEmpty) {
      _showSnack('Корзина пуста', isError: true);
      return;
    }

    if (userStoreName == null) {
      _showSnack('У вас нет привязанного магазина. Обратитесь к администратору.', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Для каждого товара в корзине — upsert в store_stock
      for (final entry in cart.entries) {
        final productId = entry.key;
        final addedQty = entry.value;

        // Получаем текущее количество (если есть)
        final existing = await supabase
            .from('store_stock')
            .select('quantity')
            .eq('store_name', userStoreName!)
            .eq('product_id', productId)
            .maybeSingle();

        final currentQty = (existing?['quantity'] as int?) ?? 0;
        final newQty = currentQty + addedQty;

        await supabase.from('store_stock').upsert({
          'store_name': userStoreName,
          'product_id': productId,
          'quantity': newQty,
        }, onConflict: 'store_name,product_id');
      }

      setState(() {
        cart.clear();
      });

      _showSnack('Товары успешно добавлены на склад $userStoreName', isSuccess: true);
    } catch (e) {
      _showSnack('Ошибка добавления на склад: $e', isError: true);
    }

    if (mounted) setState(() => isLoading = false);
  }

  int get totalItems => cart.values.fold(0, (sum, q) => sum + q);

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red[700]
            : isSuccess
                ? Colors.green[700]
                : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: selectedSupplierId == null
                    ? 'Сначала выберите поставщика...'
                    : 'Поиск по товарам...',
                prefixIcon: const Icon(Icons.search, size: 22),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              enabled: selectedSupplierId != null,
              onChanged: (value) {
                setState(() => searchQuery = value);
                _loadProducts();
              },
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : selectedSupplierId == null
                    ? _buildSuppliersList()
                    : _buildProductsList(),
          ),
        ],
      ),

      floatingActionButton: cart.isNotEmpty && selectedSupplierId != null
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 80 + MediaQuery.of(context).padding.bottom,
              ),
              child: FloatingActionButton.extended(
                onPressed: isLoading ? null : _addToStore,
                icon: const Icon(Icons.add_box),
                label: Text('Добавить на склад ($totalItems)'),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                elevation: 6,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSuppliersList() {
    if (suppliers.isEmpty) {
      return const Center(
        child: Text(
          'Поставщиков пока нет',
          style: TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final sup = suppliers[index];
        final name = sup['name'] as String? ?? 'Без названия';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(name),
            subtitle: Text(sup['email'] as String? ?? '—'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                selectedSupplierId = sup['id'] as String?;
                searchQuery = '';
              });
              _loadProducts();
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsList() {
    final supplier = suppliers.firstWhere(
      (s) => s['id'] == selectedSupplierId,
      orElse: () => {'name': 'Неизвестный поставщик'},
    );
    final supplierName = supplier['name'] as String? ?? 'Поставщик';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedSupplierId = null;
                    searchQuery = '';
                    products = [];
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  supplierName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty ? 'У этого поставщика нет товаров' : 'Ничего не найдено',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final id = p['id'] as int?;
                    if (id == null) return const SizedBox.shrink();

                    final qty = cart[id] ?? 0;
                    final price = p['price_with_vat'] ?? p['price'] ?? 0;
                    final unit = p['unit_of_measure'] ?? 'шт';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(p['name'] as String? ?? '—'),
                        subtitle: Text('$price ₽ / $unit'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart),
                              tooltip: 'Добавить в заказ',
                              onPressed: () => _showAddDialog(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}