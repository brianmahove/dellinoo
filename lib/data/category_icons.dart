import 'package:flutter/material.dart';

import '../core/iconly.dart';

/// Category icons, by key.
///
/// Firestore can't hold a Flutter `IconData`, so a category doc stores one of
/// these keys (`icon: 'wigs'`) and the app looks the icon up here. The admin
/// panel has the same map in `admin/lib/category_icons.dart` and shows it as a
/// picker — **add new icons to both files**, or the admin will offer a key the
/// app can't draw (it falls back to a generic tag, so nothing breaks).
const categoryIcons = <String, IconData>{
  'women': Icons.woman_outlined,
  'men': Icons.man_outlined,
  'kids': Icons.child_care_outlined,
  'baby': Icons.stroller_outlined,
  'shoes': Icons.ice_skating_outlined,
  'handbags': IconlyLight.bag,
  'wigs': Icons.face_retouching_natural_outlined,
  'beauty': Icons.brush_outlined,
  'jewellery': Icons.diamond_outlined,
  'phones': Icons.smartphone_outlined,
  'watches': Icons.watch_outlined,
  'laptops': Icons.laptop_outlined,
  'games': IconlyLight.game,
  'electronics': Icons.headphones_outlined,
  'tv': Icons.tv_outlined,
  'camera': Icons.photo_camera_outlined,
  'home': Icons.chair_outlined,
  'kitchen': Icons.blender_outlined,
  'tools': Icons.handyman_outlined,
  'sports': Icons.sports_soccer_outlined,
  'toys': Icons.toys_outlined,
  'books': IconlyLight.paper,
  'food': Icons.restaurant_outlined,
  'gifts': Icons.card_giftcard_outlined,
  'other': Icons.sell_outlined,
};

/// The icon for a category, or a generic tag for a key this build doesn't know.
IconData categoryIcon(String? key) => categoryIcons[key] ?? Icons.sell_outlined;
