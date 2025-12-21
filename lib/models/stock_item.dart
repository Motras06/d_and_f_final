
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