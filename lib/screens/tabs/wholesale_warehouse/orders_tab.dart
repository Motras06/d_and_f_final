import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];

  String? selectedSupplierId;
  Map<int, int> cart = {};

  bool isLoading = false;
  String searchQuery = '';

  String? userStoreName;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserStore();
    _loadSuppliers();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getPriceText(num? price) {
    if (price == null || price <= 0) {
      return 'По договорённости';
    }
    return '${price.toStringAsFixed(0)} BYN';
  }

  Future<void> _loadUserStore() async {
    try {
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();

      if (assignment != null && assignment['store_name'] != null && mounted) {
        setState(() {
          userStoreName = assignment['store_name'] as String;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadSuppliers() async {
    if (!mounted) return;
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
    if (selectedSupplierId == null || !mounted) return;

    if (mounted) {
      setState(() {
        isLoading = true;
        products = [];
      });
    }

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
    if (!mounted) return;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text(name),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Количество ($unit)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
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
            FilledButton(
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

    qtyController.dispose();

    if (confirmed != true || !mounted) return;

    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    _addToCart(productId, qty);
    _showSnack('Добавлено $qty × $name в корзину', isSuccess: true);
  }

  Future<void> _addToStore() async {
    if (cart.isEmpty) {
      _showSnack('Корзина пуста', isError: true);
      return;
    }

    if (userStoreName == null) {
      _showSnack(
        'У вас нет привязанного магазина. Обратитесь к администратору.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      for (final entry in cart.entries) {
        final productId = entry.key;
        final addedQty = entry.value;

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

      if (mounted) {
        setState(() {
          cart.clear();
        });
        _showSnack(
          'Товары успешно добавлены на склад $userStoreName',
          isSuccess: true,
        );
      }
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
            : (isSuccess ? Colors.green[700] : null),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Заказы у поставщиков'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: selectedSupplierId == null
                        ? 'Сначала выберите поставщика...'
                        : 'Поиск по товарам...',
                    prefixIcon: const Icon(Icons.search_rounded),
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
                  enabled: selectedSupplierId != null,
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => searchQuery = value);
                      _loadProducts();
                    }
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
        ),
      ),

      floatingActionButton: cart.isNotEmpty && selectedSupplierId != null
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 80 + MediaQuery.of(context).padding.bottom,
              ),
              child: FloatingActionButton.extended(
                onPressed: isLoading ? null : _addToStore,
                icon: const Icon(Icons.add_box_rounded),
                label: Text('Добавить на склад ($totalItems)'),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSuppliersList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Поставщиков пока нет',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
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
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shadowColor: colorScheme.shadow.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: colorScheme.surfaceContainerLowest,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              sup['email'] as String? ?? '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              if (mounted) {
                setState(() {
                  selectedSupplierId = sup['id'] as String?;
                  searchQuery = '';
                });
                _loadProducts();
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      selectedSupplierId = null;
                      searchQuery = '';
                      products = [];
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  supplierName,
                  style: theme.textTheme.titleLarge?.copyWith(
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        searchQuery.isEmpty
                            ? 'У этого поставщика нет товаров'
                            : 'Ничего не найдено',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shadowColor: colorScheme.shadow.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: colorScheme.surfaceContainerLowest,
                      child: ListTile(
                        leading: p['image_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  p['image_url'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                        title: Text(
                          p['name'] as String? ?? '—',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_getPriceText(price)} / $unit',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$qty',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              tooltip: 'Добавить в заказ',
                              color: colorScheme.primary,
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
