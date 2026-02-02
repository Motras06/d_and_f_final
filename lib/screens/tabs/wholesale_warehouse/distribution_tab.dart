import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistributionTab extends StatefulWidget {
  const DistributionTab({super.key});

  @override
  State<DistributionTab> createState() => _DistributionTabState();
}

class _DistributionTabState extends State<DistributionTab>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? myStoreName;
  List<String> availableStores = [];
  List<Map<String, dynamic>> myStock = [];
  String? selectedStoreName;
  Map<int, int> distributionCart = {};

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

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

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Не авторизован');

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

      final allStoresRes = await supabase.from('stores').select('name');
      final allStoreNames = (allStoresRes as List)
          .map((s) => s['name'] as String)
          .toSet();

      final supplierUsers = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'supplier');

      final supplierIds = supplierUsers.map((u) => u['id']).toList();

      final supplierAssignments = await supabase
          .from('store_assignments')
          .select('store_name')
          .inFilter('user_id', supplierIds);

      final supplierStores = supplierAssignments
          .map((a) => a['store_name'] as String)
          .toSet();

      final freeStores = allStoreNames.difference(supplierStores).toList();

      setState(() => availableStores = freeStores);

      await _loadMyStock();
    } catch (e, stack) {
      print('Ошибка загрузки: $e\n$stack');
      setState(() {
        errorMessage = 'Не удалось загрузить данные: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadMyStock() async {
    if (myStoreName == null) {
      if (mounted) {
        setState(() {
          errorMessage = 'Магазин не найден';
          isLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      print('Загрузка склада для магазина: $myStoreName');

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

      if (!mounted) {
        print('Виджет dispose во время загрузки склада — выходим');
        return;
      }

      final List<dynamic> data = response;

      final mappedStock = data.map((row) {
        final product = row['products'] as Map<String, dynamic>? ?? {};
        return {
          'product_id': row['product_id'] as int? ?? 0,
          'quantity': row['quantity'] as int? ?? 0,
          'name': product['name'] as String? ?? 'Без названия',
          'price':
              product['price_with_vat'] as num? ??
              product['price'] as num? ??
              0,
          'image_url': product['image_url'] as String?,
          'unit': product['unit_of_measure'] as String? ?? 'шт',
        };
      }).toList();

      print('Загружено товаров: ${mappedStock.length}');

      if (mounted) {
        setState(() {
          myStock = mappedStock;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      print('Ошибка загрузки склада: $e');
      print(stack);

      if (mounted) {
        setState(() {
          errorMessage = 'Ошибка загрузки склада: $e';
          isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _updateDistribution(int productId, int qty) {
    setState(() {
      final maxQty =
          myStock.firstWhere((p) => p['product_id'] == productId)['quantity']
              as int;
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isSending = true);

    try {
      final deliveryRes = await supabase
          .from('deliveries')
          .insert({
            'supplier_id': supabase.auth.currentUser?.id,
            'store_name': selectedStoreName,
            'status': 'pending',
          })
          .select('id')
          .single();

      final deliveryId = deliveryRes['id'] as int;

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
        selectedStoreName = null;
      });

      _showSnack(
        'Доставка создана и ожидает приёмки в магазине $selectedStoreName',
        isSuccess: true,
      );

      await _loadMyStock();
    } catch (e) {
      _showSnack('Ошибка создания доставки: $e', isError: true);
    } finally {
      setState(() => isSending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : (isSuccess ? Colors.green : null),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        title: const Text('Распределение товаров'),
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
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 80,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        errorMessage!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : myStoreName == null
              ? Center(
                  child: Text(
                    'У вас нет привязанного магазина',
                    style: theme.textTheme.titleLarge,
                  ),
                )
              : selectedStoreName == null
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Выберите магазин для доставки',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: availableStores.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_outlined,
                                    size: 80,
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Нет доступных магазинов',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: availableStores.length,
                              itemBuilder: (context, index) {
                                final store = availableStores[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  color: colorScheme.surfaceContainerLowest,
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.store_outlined,
                                      color: colorScheme.primary,
                                    ),
                                    title: Text(
                                      store,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    onTap: () {
                                      setState(() => selectedStoreName = store);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              setState(() {
                                selectedStoreName = null;
                                distributionCart.clear();
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Доставка в: $selectedStoreName',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: myStock.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 80,
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'На вашем складе нет товаров',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator.adaptive(
                              onRefresh: _loadMyStock,
                              color: colorScheme.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                itemCount: myStock.length,
                                itemBuilder: (context, index) {
                                  final p = myStock[index];
                                  final productId = p['product_id'] as int;
                                  final maxQty = p['quantity'] as int;
                                  final sendQty =
                                      distributionCart[productId] ?? 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 1,
                                    shadowColor: colorScheme.shadow.withOpacity(
                                      0.12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    color: colorScheme.surfaceContainerLowest,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          if (p['image_url'] != null &&
                                              p['image_url'].isNotEmpty)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p['name'],
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_getPriceText(p['price'])} / ${p['unit']}',
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'В наличии: $maxQty',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .remove_circle_outline_rounded,
                                                ),
                                                onPressed: sendQty > 0
                                                    ? () => _updateDistribution(
                                                        productId,
                                                        sendQty - 1,
                                                      )
                                                    : null,
                                                color: colorScheme.primary,
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: Text(
                                                  '$sendQty',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .add_circle_outline_rounded,
                                                ),
                                                onPressed: sendQty < maxQty
                                                    ? () => _updateDistribution(
                                                        productId,
                                                        sendQty + 1,
                                                      )
                                                    : null,
                                                color: colorScheme.primary,
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
                    ),

                    if (distributionCart.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          onPressed: isSending ? null : _confirmAndSend,
                          icon: isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.local_shipping_rounded),
                          label: Text(
                            isSending
                                ? 'Отправка...'
                                : 'Создать доставку (${distributionCart.values.fold(0, (a, b) => a + b)} ед.)',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: colorScheme.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
