import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_repository.dart';
import 'mock_data.dart' show mockCategories;
import 'models.dart';

/// Firestore-backed catalogue.
///
/// Products and delivery areas are admin-managed Firestore collections
/// (`products`, `delivery_areas`) — see `firestore.rules` (public read, no
/// client writes; the admin panel/Cloud Functions write instead, roadmap
/// item 4). Categories stay a fixed, code-defined taxonomy (`mockCategories`
/// in `mock_data.dart`): Firestore can't store a Flutter `IconData`, and the
/// business doesn't need the 10 categories to be admin-editable.
class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<Category>> fetchCategories() async => mockCategories;

  @override
  Future<List<Product>> fetchProducts() async {
    final snapshot = await _db.collection('products').get();
    return [for (final doc in snapshot.docs) _productFromDoc(doc.id, doc.data())];
  }

  @override
  Future<List<DeliveryArea>> fetchDeliveryAreas() async {
    final snapshot = await _db.collection('delivery_areas').orderBy('sortOrder').get();
    return [for (final doc in snapshot.docs) _areaFromDoc(doc.id, doc.data())];
  }

  Product _productFromDoc(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] as String,
      brand: data['brand'] as String,
      categoryId: data['categoryId'] as String,
      price: (data['price'] as num).toDouble(),
      oldPrice: (data['oldPrice'] as num?)?.toDouble(),
      stockStatus: StockStatus.values.byName(data['stockStatus'] as String),
      thumbnail: data['thumbnail'] as String,
      images: List<String>.from(data['images'] as List? ?? const []),
      description: data['description'] as String? ?? '',
      variantGroups: [
        for (final g in (data['variantGroups'] as List? ?? const []))
          VariantGroup((g as Map)['name'] as String, List<String>.from(g['options'] as List? ?? const [])),
      ],
      rating: ((data['rating'] as num?) ?? 0).toDouble(),
      soldCount: (data['soldCount'] as num?)?.toInt() ?? 0,
      isNew: data['isNew'] as bool? ?? false,
      saleEndsAt: (data['saleEndsAt'] as Timestamp?)?.toDate(),
    );
  }

  DeliveryArea _areaFromDoc(String id, Map<String, dynamic> data) {
    return DeliveryArea(
      id: id,
      name: data['name'] as String,
      fee: (data['fee'] as num).toDouble(),
      eta: data['eta'] as String,
    );
  }
}
