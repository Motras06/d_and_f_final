// lib/screens/tabs/storage/receive_goods_tab.dart

import 'package:flutter/material.dart';
import 'package:d_and_f_final/models/profile.dart';
import '/services/delivery_service.dart';

class ReceiveGoodsTab extends StatefulWidget {
  final Profile profile;
  const ReceiveGoodsTab({super.key, required this.profile});

  @override
  State<ReceiveGoodsTab> createState() => _ReceiveGoodsTabState();
}

class _ReceiveGoodsTabState extends State<ReceiveGoodsTab>
    with SingleTickerProviderStateMixin {
  String? storeName;
  List<Map<String, dynamic>> pendingDeliveries = [];
  bool isLoading = true;
  String? errorMessage;

  final DeliveryService _deliveryService = DeliveryService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    loadData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _deliveryService.loadPendingDeliveries(widget.profile);

      setState(() {
        storeName = data['storeName'];
        pendingDeliveries = data['deliveries'] as List<Map<String, dynamic>>;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> acceptDelivery(int deliveryId) async {
    try {
      await _deliveryService.acceptDelivery(storeName!, deliveryId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Поставка принята'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при приёме: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> rejectDelivery(int deliveryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отказать в поставке?'),
        content: const Text(
          'Поставка будет удалена и не сможет быть принята позже.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отказать', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _deliveryService.rejectDelivery(deliveryId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Поставка отклонена и удалена'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отклонении: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: loadData,
              color: theme.colorScheme.primary,
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 80,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : pendingDeliveries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 100,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Нет ожидающих поставок',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Все поставки приняты',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Заголовок с магазином
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            color: theme.cardColor,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory_outlined,
                                    size: 32,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Магазин: $storeName',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Список поставок
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: pendingDeliveries.length,
                            itemBuilder: (context, index) {
                              final delivery = pendingDeliveries[index];

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  color: theme.cardColor,
                                  shadowColor: theme.shadowColor.withOpacity(
                                    0.3,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            acceptDelivery(delivery['id']),
                                        splashColor: Colors.green.withOpacity(
                                          0.2,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Row(
                                            children: [
                                              // Иконка поставки
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Icon(
                                                  Icons.local_shipping_outlined,
                                                  size: 40,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(width: 20),

                                              // Информация
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Поставка #${delivery['id']}',
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'От: ${delivery['supplier_email']}',
                                                      style: theme
                                                          .textTheme
                                                          .bodyLarge,
                                                    ),
                                                    Text(
                                                      'Товаров: ${delivery['total_items']}',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Кнопки действий
                                              Column(
                                                children: [
                                                  IconButton(
                                                    onPressed: () =>
                                                        acceptDelivery(
                                                          delivery['id'],
                                                        ),
                                                    icon: const Icon(
                                                      Icons.check_circle,
                                                      size: 48,
                                                      color: Colors.green,
                                                    ),
                                                    tooltip: 'Принять поставку',
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        rejectDelivery(
                                                          delivery['id'],
                                                        ),
                                                    icon: const Icon(
                                                      Icons.cancel,
                                                      size: 48,
                                                      color: Colors.red,
                                                    ),
                                                    tooltip:
                                                        'Отказать в поставке',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
