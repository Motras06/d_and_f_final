// lib/models/product.dart

class Product {
  final int id;
  final String name;
  final String country;
  final String? about;
  final num price;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? createdBy; // uuid поставщика

  Product({
    required this.id,
    required this.name,
    required this.country,
    this.about,
    required this.price,
    this.imageUrl,
    this.createdAt,
    this.createdBy,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      country: json['country'] as String,
      about: json['about'] as String?,
      price: json['price'] as num,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      createdBy: json['created_by'] as String?,
    );
  }
}