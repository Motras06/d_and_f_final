// Профиль пользователя
class Profile {
  final String id;  // UUID как строка
  final String mail;
  final String? username;
  final String role;  // 'admin', 'supplier', 'storekeeper'
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.mail,
    this.username,
    required this.role,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      mail: map['mail'] as String,
      username: map['username'] as String?,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mail': mail,
      'username': username,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Магазин
class Store {
  final int id;
  final String name;

  Store({
    required this.id,
    required this.name,
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}

// Привязка кладовщика к магазину
class StoreAssignment {
  final String storeName;
  final String userId;  // UUID как строка

  StoreAssignment({
    required this.storeName,
    required this.userId,
  });

  factory StoreAssignment.fromMap(Map<String, dynamic> map) {
    return StoreAssignment(
      storeName: map['store_name'] as String,
      userId: map['user_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_name': storeName,
      'user_id': userId,
    };
  }
}

// Товар
class Product {
  final int id;
  final String name;
  final String country;
  final String? about;
  final double price;
  final String? imageUrl;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.country,
    this.about,
    required this.price,
    this.imageUrl,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      country: map['country'] as String,
      about: map['about'] as String?,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'about': about,
      'price': price,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Остатки на складе
class StoreStock {
  final String storeName;
  final int productId;
  final int quantity;

  StoreStock({
    required this.storeName,
    required this.productId,
    required this.quantity,
  });

  factory StoreStock.fromMap(Map<String, dynamic> map) {
    return StoreStock(
      storeName: map['store_name'] as String,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_name': storeName,
      'product_id': productId,
      'quantity': quantity,
    };
  }
}

// Поставка
class Delivery {
  final int id;
  final String supplierId;  // UUID как строка
  final String storeName;
  final String status;  // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  Delivery({
    required this.id,
    required this.supplierId,
    required this.storeName,
    required this.status,
    required this.createdAt,
  });

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      id: map['id'] as int,
      supplierId: map['supplier_id'] as String,
      storeName: map['store_name'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'store_name': storeName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Элемент поставки
class DeliveryItem {
  final int id;
  final int deliveryId;
  final int productId;
  final int quantity;

  DeliveryItem({
    required this.id,
    required this.deliveryId,
    required this.productId,
    required this.quantity,
  });

  factory DeliveryItem.fromMap(Map<String, dynamic> map) {
    return DeliveryItem(
      id: map['id'] as int,
      deliveryId: map['delivery_id'] as int,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'product_id': productId,
      'quantity': quantity,
    };
  }
}