import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistributionTab extends StatefulWidget {
  const DistributionTab({super.key});

  @override
  State<DistributionTab> createState() => _DistributionTabState();
}

class _DistributionTabState extends State<DistributionTab> {
  final supabase = Supabase.instance.client;

  String? myStoreName;
  List<String> availableStores = [];
  List<Map<String, dynamic>> myStock = [];
  String? selectedStoreName;
  Map<int, int> distributionCart = {};

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Не авторизован');

      // Мой магазин
      final myAssignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', currentUserId)
          .limit(1)
          .maybeSingle();

      if (myAssignment == null || myAssignment['store_name'] == null) {
        throw Exception('У вас нет привязанного магазина');
      }
      myStoreName = myAssignment['store_name'] as String;

      // Свободные магазины (без supplier)
      final allStoresRes = await supabase.from('stores').select('name');
      final allStoreNames = (allStoresRes as List).map((s) => s['name'] as String).toSet();

      final supplierUsers = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'supplier');

      final supplierIds = supplierUsers.map((u) => u['id']).toList();

      final supplierAssignments = await supabase
          .from('store_assignments')
          .select('store_name')
          .inFilter('user_id', supplierIds);

      final supplierStores = supplierAssignments.map((a) => a['store_name'] as String).toSet();

      final freeStores = allStoreNames.difference(supplierStores).toList();

      setState(() => availableStores = freeStores);

      // Мой склад
      await _loadMyStock();
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadMyStock() async {
    if (myStoreName == null) return;

    try {
      final response = await supabase
          .from('store_stock')
          .select('''
            product_id,
            quantity,
            products!inner (
              id,
              name,
              price_with_vat,
              image_url,
              unit_of_measure
            )
          ''')
          .eq('store_name', myStoreName!)
          .gt('quantity', 0);

      final List<dynamic> data = response;

      setState(() {
        myStock = data.map((row) {
          final product = row['products'] as Map<String, dynamic>? ?? {};
          return {
            'product_id': row['product_id'],
            'quantity': row['quantity'],
            'name': product['name'] ?? 'Без названия',
            'price': product['price_with_vat'] ?? product['price'] ?? 0,
            'image_url': product['image_url'],
            'unit': product['unit_of_measure'] ?? 'шт',
          };
        }).toList();
      });
    } catch (e) {
      _showSnack('Ошибка загрузки склада: $e', isError: true);
    }
  }

  void _updateDistribution(int productId, int qty) {
    setState(() {
      final maxQty = myStock.firstWhere((p) => p['product_id'] == productId)['quantity'] as int;
      if (qty > maxQty) qty = maxQty;
      if (qty <= 0) {
        distributionCart.remove(productId);
      } else {
        distributionCart[productId] = qty;
      }
    });
  }

  Future<void> _confirmAndSend() async {
    if (selectedStoreName == null || distributionCart.isEmpty) return;

    final totalItems = distributionCart.values.fold(0, (a, b) => a + b);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите отправку'),
        content: Text(
          'Отправить $totalItems ед. товаров в магазин "$selectedStoreName"?\n'
          'Доставка будет создана со статусом "pending" и ожидать приёмки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isSending = true);

    try {
      // Создаём доставку — вставляем id текущего пользователя как supplier_id
      final deliveryRes = await supabase
          .from('deliveries')
          .insert({
            'supplier_id': supabase.auth.currentUser?.id,  // ← просто id пользователя
            'store_name': selectedStoreName,
            'status': 'pending',
          })
          .select('id')
          .single();

      final deliveryId = deliveryRes['id'] as int;

      // Добавляем позиции
      final items = distributionCart.entries.map((entry) {
        return {
          'delivery_id': deliveryId,
          'product_id': entry.key,
          'quantity': entry.value,
        };
      }).toList();

      await supabase.from('delivery_items').insert(items);

      setState(() {
        distributionCart.clear();
      });

      _showSnack('Доставка создана и ожидает приёмки в магазине $selectedStoreName', isSuccess: true);

      setState(() => selectedStoreName = null);
    } catch (e) {
      _showSnack('Ошибка создания доставки: $e', isError: true);
    } finally {
      setState(() => isSending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)));
    }

    if (myStoreName == null) {
      return const Center(child: Text('У вас нет привязанного магазина'));
    }

    return Column(
      children: [
        // Выбор магазина
        if (selectedStoreName == null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Выберите магазин для доставки',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: availableStores.isEmpty
                ? const Center(child: Text('Нет доступных магазинов для доставки'))
                : ListView.builder(
                    itemCount: availableStores.length,
                    itemBuilder: (context, index) {
                      final store = availableStores[index];
                      return ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: Text(store),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          setState(() => selectedStoreName = store);
                        },
                      );
                    },
                  ),
          ),
        ]

        // Выбор товаров и отправка
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    selectedStoreName = null;
                    distributionCart.clear();
                  }),
                ),
                Expanded(
                  child: Text(
                    'Доставка в: $selectedStoreName',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: myStock.isEmpty
                ? const Center(child: Text('На вашем складе нет товаров для отправки'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: myStock.length,
                    itemBuilder: (context, index) {
                      final p = myStock[index];
                      final productId = p['product_id'] as int;
                      final maxQty = p['quantity'] as int;
                      final sendQty = distributionCart[productId] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              if (p['image_url'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p['image_url'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${p['price']} ₽ / ${p['unit']}'),
                                    Text('В наличии: $maxQty', style: TextStyle(color: Colors.grey[700])),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: sendQty > 0 ? () => _updateDistribution(productId, sendQty - 1) : null,
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text('$sendQty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: sendQty < maxQty ? () => _updateDistribution(productId, sendQty + 1) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (distributionCart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: isSending ? null : _confirmAndSend,
                icon: isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.local_shipping),
                label: Text(isSending ? 'Отправка...' : 'Создать доставку (${distributionCart.values.fold(0, (a, b) => a + b)} ед.)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ],
    );
  }
}