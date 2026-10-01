import 'package:flutter/material.dart';

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
