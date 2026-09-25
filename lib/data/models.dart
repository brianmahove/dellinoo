import 'package:flutter/material.dart';
import '../core/iconly.dart';

enum StockStatus {
  inStock('In stock', 'Delivered in 1–3 days'),
  preorder('Arrives in 2–3 weeks', 'Ships from China');

  const StockStatus(this.label, this.detail);
  final String label;
  final String detail;
}

class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final IconData icon;
}

class VariantGroup {
  const VariantGroup(this.name, this.options);

  final String name;
  final List<String> options;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.price,
    this.oldPrice,
    required this.stockStatus,
    required this.thumbnail,
    required this.images,
    required this.description,
    this.variantGroups = const [],
    this.rating = 0,
    this.soldCount = 0,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final double price;
  final double? oldPrice;
  final StockStatus stockStatus;
  final String thumbnail;
  final List<String> images;
  final String description;
  final List<VariantGroup> variantGroups;
  final double rating;
  final int soldCount;
  final bool isNew;

  bool get onSale => oldPrice != null && oldPrice! > price;
  int get discountPercent => onSale ? ((1 - price / oldPrice!) * 100).round() : 0;
}

class CartItem {
  const CartItem({required this.product, required this.options, required this.quantity});

  final Product product;
  final Map<String, String> options;
  final int quantity;

  String get key => '${product.id}|${options.entries.map((e) => '${e.key}=${e.value}').join(',')}';
  double get total => product.price * quantity;
  String get optionsLabel => options.values.join(' · ');

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, options: options, quantity: quantity ?? this.quantity);
}

class DeliveryArea {
  const DeliveryArea({required this.id, required this.name, required this.fee, required this.eta});

  final String id;
  final String name;
  final double fee;
  final String eta;
}

enum PaymentMethod {
  ecocash('EcoCash', 'Pay with your EcoCash wallet', true),
  onemoney('OneMoney', 'Pay with your OneMoney wallet', true),
  innbucks('InnBucks', 'Pay with an InnBucks code', false),
  card('Card', 'Visa, Mastercard or ZimSwitch', false);

  const PaymentMethod(this.label, this.subtitle, this.needsPhone);
  final String label;
  final String subtitle;
  final bool needsPhone;
}

enum OrderStatus {
  placed('Order placed', IconlyLight.paper),
  paid('Payment confirmed', IconlyLight.wallet),
  processing('Processing', IconlyLight.bag_2),
  outForDelivery('Out for delivery', Icons.local_shipping_outlined),
  delivered('Delivered', IconlyLight.tick_square);

  const OrderStatus(this.label, this.icon);
  final String label;
  final IconData icon;
}

class StatusEvent {
  const StatusEvent(this.status, this.at, [this.note]);

  final OrderStatus status;
  final DateTime at;
  final String? note;
}

class Address {
  const Address({required this.fullName, required this.phone, required this.street, required this.city});

  final String fullName;
  final String phone;
  final String street;
  final String city;

  String get oneLine => '$street, $city';
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.address,
    required this.area,
    required this.payment,
    required this.history,
  });

  final String id;
  final List<CartItem> items;
  final Address address;
  final DeliveryArea area;
  final PaymentMethod payment;
  final List<StatusEvent> history;

  OrderStatus get status => history.last.status;
  DateTime get createdAt => history.first.at;
  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  double get total => subtotal + area.fee;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}

class AppUser {
  const AppUser({required this.name, required this.phone});

  final String name;
  final String phone;
}
