// lib/screens/tabs/storage/stock_availability_tab.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_and_f_final/models/profile.dart';

class StockItem {
  final int productId;
  final String name;
  final String country;
  final num price;
  final String? imageUrl;
  final String? about;
  final int quantity;

  StockItem({
    required this.productId,
    required this.name,
    required this.country,
    required this.price,
    this.imageUrl,
    this.about,
    required this.quantity,
  });
}

class StockAvailabilityTab extends StatefulWidget {
  final Profile profile;
  const StockAvailabilityTab({super.key, required this.profile});

  @override
  State<StockAvailabilityTab> createState() => _StockAvailabilityTabState();
}

class _StockAvailabilityTabState extends State<StockAvailabilityTab> {
  String? storeName;
  List<StockItem> stockItems = [];
  bool isLoading = true;
  String? errorMessage;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadStock();
  }

  Future<void> loadStock() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Получаем магазин кладовщика
      final assignment = await supabase
          .from('store_assignments')
          .select('store_name')
          .eq('user_id', widget.profile.id)
          .maybeSingle();

      if (assignment == null || assignment['store_name'] == null) {
        setState(() {
          errorMessage = 'Магазин не закреплён';
          isLoading = false;
        });
        return;
      }

      final currentStore = assignment['store_name'] as String;
      setState(() => storeName = currentStore);

      // 2. Получаем остатки
      final stockResponse = await supabase
          .from('store_stock')
          .select('product_id, quantity, product:product_id(name, country, price, image_url, about)')
          .eq('store_name', currentStore)
          .order('quantity', ascending: false);

      final List<StockItem> items = [];

      for (final row in stockResponse) {
        final productJson = row['product'] as Map<String, dynamic>?;
        if (productJson == null) continue;

        items.add(StockItem(
          productId: row['product_id'] as int,
          name: productJson['name'] as String,
          country: productJson['country'] as String,
          price: productJson['price'] as num,
          imageUrl: productJson['image_url'] as String?,
          about: productJson['about'] as String?,
          quantity: (row['quantity'] as num).toInt(),
        ));
      }

      setState(() {
        stockItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  Future<void> updateQuantity(int productId, int newQuantity) async {
    if (newQuantity < 0) newQuantity = 0;

    try {
      await supabase.from('store_stock').update({
        'quantity': newQuantity,
      }).eq('store_name', storeName!).eq('product_id', productId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Количество обновлено'), backgroundColor: Colors.green),
      );

      loadStock(); // обновляем список
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void showProductDetails(StockItem item) {
    final controller = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.imageUrl != null)
                Center(
                  child: Image.network(
                    item.imageUrl!,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 100),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Страна: ${item.country}'),
              Text('Цена: ${item.price} ₽'),
              if (item.about != null && item.about!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Описание: ${item.about}'),
                ),
              const SizedBox(height: 16),
              const Text('Текущее количество:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Введите новое количество',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(controller.text) ?? item.quantity;
              Navigator.pop(context);
              updateQuantity(item.productId, newQty);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (stockItems.isEmpty) {
      return const Center(
        child: Text('На складе пусто', style: TextStyle(fontSize: 18)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Склад: $storeName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: stockItems.length,
            itemBuilder: (context, index) {
              final item = stockItems[index];

              return ListTile(
                leading: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory),
                      )
                    : const Icon(Icons.inventory),
                title: Text(item.name),
                subtitle: Text('Страна: ${item.country} • Цена: ${item.price} ₽'),
                trailing: Text(
                  'Остаток: ${item.quantity}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: () => showProductDetails(item),
              );
            },
          ),
        ),
      ],
    );
  }
}