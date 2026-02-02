import 'package:d_and_f_final/models/product.dart';

class DeliveryProduct {
  final Product product;
  int quantity;

  DeliveryProduct({required this.product, this.quantity = 0});
}
