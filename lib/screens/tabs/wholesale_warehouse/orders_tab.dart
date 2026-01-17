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
  Map<int, int> cart = {}; // productId → quantity

  bool isLoading = false;
  String? searchText;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('suppliers')
          .select('id, name, email, phone')
          .order('name');
      setState(() {
        suppliers = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showSnack('Ошибка загрузки поставщиков: $e', isError: true);
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadProducts(String supplierId) async {
    setState(() {
      isLoading = true;
      products = [];
      selectedSupplierId = supplierId;
    });

    try {
      var query = supabase
          .from('products')
          .select('id, name, price, price_with_vat, unit_of_measure, image_url')
          .eq('supplier_id', supplierId);

      if (searchText != null && searchText!.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchText!.trim()}%');
      }

      final data = await query.order('name');
      setState(() {
        products = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showSnack('Ошибка загрузки товаров: $e', isError: true);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _addToCart(int productId, int qty) {
    setState(() {
      cart[productId] = (cart[productId] ?? 0) + qty;
    });
  }

  Future<void> _showAddDialog(Map<String, dynamic> product) async {
    final name = product['name'] as String? ?? 'Товар';
    final unit = product['unit_of_measure'] as String? ?? 'шт';
    final productId = product['id'];

    if (productId == null || productId is! int) {
      _showSnack('Ошибка: товар без ID', isError: true);
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
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Количество ($unit)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Обязательно';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return '≥ 1';
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

    if (confirmed == true && mounted) {
      final qty = int.tryParse(qtyController.text.trim()) ?? 1;
      _addToCart(productId as int, qty);
      _showSnack('Добавлено $qty × $name');
    }

    qtyController.dispose();
  }

  Future<void> _createOrder() async {
    if (cart.isEmpty) return _showSnack('Корзина пуста', isError: true);
    if (selectedSupplierId == null) return _showSnack('Поставщик не выбран', isError: true);

    setState(() => isLoading = true);

    try {
      // Проверка поставщика
      final sup = await supabase
          .from('suppliers')
          .select('id')
          .eq('id', selectedSupplierId!)
          .maybeSingle();

      if (sup == null) return _showSnack('Поставщик не найден', isError: true);

      // Создание заказа
      final delivery = await supabase
          .from('deliveries')
          .insert({
            'supplier_id': selectedSupplierId,
            'status': 'pending',
          })
          .select('id')
          .single();

      final deliveryId = delivery['id'] as int;

      // Позиции
      final items = cart.entries.map((e) => {
            'delivery_id': deliveryId,
            'product_id': e.key,
            'quantity': e.value,
          }).toList();

      await supabase.from('delivery_items').insert(items);

      setState(() => cart.clear());

      _showSnack('Заказ №$deliveryId создан', isSuccess: true);
    } catch (e) {
      _showSnack('Ошибка: $e', isError: true);
    }

    if (mounted) setState(() => isLoading = false);
  }

  int get totalItems => cart.values.fold(0, (a, b) => a + b);

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : null,
        duration: const Duration(seconds: 3),
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
                hintText: 'Поиск по товарам...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.cardColor,
              ),
              onChanged: (v) {
                final q = v.trim();
                setState(() => searchText = q.isEmpty ? null : q);
                if (selectedSupplierId != null) _loadProducts(selectedSupplierId!);
              },
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : selectedSupplierId == null
                    ? _buildSuppliers()
                    : _buildProducts(),
          ),
        ],
      ),

      floatingActionButton: cart.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                onPressed: isLoading ? null : _createOrder,
                label: Text('Заказ ($totalItems)'),
                icon: const Icon(Icons.send),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSuppliers() {
    if (suppliers.isEmpty) {
      return const Center(child: Text('Поставщиков нет', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      itemBuilder: (context, i) {
        final s = suppliers[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(s['name']?[0]?.toUpperCase() ?? '?')),
            title: Text(s['name'] ?? '—'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _loadProducts(s['id']),
          ),
        );
      },
    );
  }

  Widget _buildProducts() {
    final supplierName = suppliers
            .firstWhere((s) => s['id'] == selectedSupplierId, orElse: () => {'name': '—'})['name']
        as String? ??
        'Поставщик';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  selectedSupplierId = null;
                  products = [];
                  searchText = null;
                }),
              ),
              Expanded(
                child: Text(
                  supplierName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('Товаров нет', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final qty = cart[p['id'] as int? ?? 0] ?? 0;

                    return Card(
                      child: ListTile(
                        title: Text(p['name'] as String? ?? '—'),
                        subtitle: Text(
                          '${p['price_with_vat'] ?? p['price'] ?? '?'} ₽ / ${p['unit_of_measure'] ?? 'шт'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart),
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