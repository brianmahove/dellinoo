import 'package:flutter/material.dart';

import 'mock_products.dart';
import 'models.dart';
import '../core/iconly.dart';

const mockCategories = <Category>[
  Category(id: 'women', name: 'Women', icon: Icons.woman_outlined),
  Category(id: 'men', name: 'Men', icon: Icons.man_outlined),
  Category(id: 'kids', name: 'Kids', icon: Icons.child_care_outlined),
  Category(id: 'shoes', name: 'Shoes', icon: Icons.ice_skating_outlined),
  Category(id: 'handbags', name: 'Handbags', icon: IconlyLight.bag),
  Category(id: 'phones', name: 'Phones', icon: Icons.smartphone_outlined),
  Category(id: 'watches', name: 'Watches', icon: Icons.watch_outlined),
  Category(id: 'laptops', name: 'Laptops', icon: Icons.laptop_outlined),
  Category(id: 'games', name: 'Games', icon: IconlyLight.game),
  Category(id: 'electronics', name: 'Electronics', icon: Icons.headphones_outlined),
];

/// Managed by the admin once the backend is in place.
const mockDeliveryAreas = <DeliveryArea>[
  DeliveryArea(id: 'pickup', name: 'Pick up at Dellinoo store (Harare CBD)', fee: 0, eta: 'Ready same day'),
  DeliveryArea(id: 'hre-cbd', name: 'Harare CBD', fee: 3, eta: '1–2 days'),
  DeliveryArea(id: 'hre-sub', name: 'Harare suburbs', fee: 5, eta: '1–2 days'),
  DeliveryArea(id: 'chitown', name: 'Chitungwiza / Ruwa / Norton', fee: 7, eta: '2–3 days'),
  DeliveryArea(id: 'byo', name: 'Bulawayo', fee: 10, eta: '2–4 days'),
  DeliveryArea(id: 'other', name: 'Other towns (courier)', fee: 12, eta: '3–5 days'),
];

const mockUser = AppUser(name: 'Tatenda Moyo', phone: '+263 77 123 4567');

const mockAddress = Address(
  fullName: 'Tatenda Moyo',
  phone: '+263 77 123 4567',
  street: '12 Samora Machel Ave',
  city: 'Harare',
);

List<Order> buildMockOrders() {
  Product p(String id) => mockProducts.firstWhere((x) => x.id == id);
  final now = DateTime.now();
  final fromChina = mockProducts.where((p) => p.stockStatus == StockStatus.preorder).toList();
  return [
    Order(
      id: 'DL10227',
      items: [CartItem(product: fromChina[1], options: const {}, quantity: 1)],
      address: mockAddress,
      area: mockDeliveryAreas[2],
      payment: PaymentMethod.innbucks,
      history: [
        StatusEvent(OrderStatus.placed, now.subtract(const Duration(days: 9))),
        StatusEvent(OrderStatus.paid, now.subtract(const Duration(days: 9))),
        StatusEvent(OrderStatus.processing, now.subtract(const Duration(days: 8))),
        StatusEvent(
          OrderStatus.boughtInChina,
          now.subtract(const Duration(days: 6)),
          'Packed at our Guangzhou warehouse',
        ),
        StatusEvent(OrderStatus.inTransit, now.subtract(const Duration(days: 1)), 'Air cargo · Guangzhou → Harare'),
      ],
    ),
    Order(
      id: 'DL10231',
      items: [
        CartItem(product: p('p88'), options: const {'Size (EU)': '42'}, quantity: 1),
        CartItem(product: p('p100'), options: const {}, quantity: 1),
      ],
      address: mockAddress,
      area: mockDeliveryAreas[2],
      payment: PaymentMethod.ecocash,
      history: [
        StatusEvent(OrderStatus.placed, now.subtract(const Duration(days: 2, hours: 3))),
        StatusEvent(OrderStatus.paid, now.subtract(const Duration(days: 2, hours: 3))),
        StatusEvent(OrderStatus.processing, now.subtract(const Duration(days: 1))),
        StatusEvent(OrderStatus.outForDelivery, now.subtract(const Duration(hours: 2)), 'Driver: Farai · 0772 000 111'),
      ],
    ),
    Order(
      id: 'DL10198',
      items: [CartItem(product: fromChina[0], options: const {}, quantity: 1)],
      address: mockAddress,
      area: mockDeliveryAreas[0],
      payment: PaymentMethod.onemoney,
      history: [
        StatusEvent(OrderStatus.placed, now.subtract(const Duration(days: 20))),
        StatusEvent(OrderStatus.paid, now.subtract(const Duration(days: 20))),
        StatusEvent(OrderStatus.processing, now.subtract(const Duration(days: 19)), 'Ordered from supplier in China'),
        StatusEvent(OrderStatus.boughtInChina, now.subtract(const Duration(days: 16))),
        StatusEvent(OrderStatus.inTransit, now.subtract(const Duration(days: 10))),
        StatusEvent(OrderStatus.arrivedZim, now.subtract(const Duration(days: 5))),
        StatusEvent(OrderStatus.outForDelivery, now.subtract(const Duration(days: 4)), 'Ready for pickup'),
        StatusEvent(OrderStatus.delivered, now.subtract(const Duration(days: 3))),
      ],
    ),
  ];
}
