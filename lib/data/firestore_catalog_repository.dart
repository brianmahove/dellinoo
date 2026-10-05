import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  FirestoreCatalogRepository({FirebaseFirestore? firestore, this._prefs})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final SharedPreferences? _prefs;

  static const _versionKey = 'catalog_version';
  static const _syncedAtKey = 'catalog_synced_at';
  static const _countKey = 'catalog_count';

  /// Even with no version bump, re-read from the server at least this often —
  /// a safety net for edits made outside the admin panel (Firebase console,
  /// scripts) that don't bump `meta/catalog`.
  static const _maxCacheAge = Duration(hours: 24);

  @override
  Future<List<Category>> fetchCategories() async => mockCategories;

  /// Cheap on the Spark read quota: a plain `.get()` re-reads every product
  /// from the server (one read each) on every app open and pull-to-refresh.
  /// Instead this reads one doc, `meta/catalog`, which the admin panel bumps
  /// on every product write (admin/lib/catalog_version.dart). If it hasn't
  /// moved, the list comes from Firestore's on-device cache for free.
  @override
  Future<List<Product>> fetchProducts() async {
    final products = _db.collection('products');
    final prefs = _prefs;
    if (prefs == null) return _parse(await products.get());

    int? version;
    try {
      final meta = await _db.doc('meta/catalog').get(const GetOptions(source: Source.server));
      version = (meta.data()?['version'] as Timestamp?)?.millisecondsSinceEpoch;
    } catch (_) {
      // Offline: Firestore's default get() falls back to the cache by itself.
      return _parse(await products.get());
    }

    final syncedAt = prefs.getInt(_syncedAtKey);
    final fresh =
        syncedAt != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(syncedAt)) < _maxCacheAge;
    if (version != null && version == prefs.getInt(_versionKey) && fresh) {
      try {
        final cached = await products.get(const GetOptions(source: Source.cache));
        // Count check: if the cache was partly cleared, don't show a list
        // with products silently missing.
        if (cached.docs.isNotEmpty && cached.docs.length == prefs.getInt(_countKey)) return _parse(cached);
      } catch (_) {
        // Nothing cached — fall through to the server.
      }
    }

    final snapshot = await products.get(const GetOptions(source: Source.server));
    // `version` is the one read *before* this fetch: if the admin bumped it
    // in between, the next launch simply sees a newer version and refetches.
    if (version != null) {
      await prefs.setInt(_versionKey, version);
    } else {
      await prefs.remove(_versionKey);
    }
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_countKey, snapshot.docs.length);
    return _parse(snapshot);
  }

  List<Product> _parse(QuerySnapshot<Map<String, dynamic>> snapshot) => [
    for (final doc in snapshot.docs) _productFromDoc(doc.id, doc.data()),
  ];

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
      photoBgs: [for (final v in (data['photoBgs'] as List? ?? const [])) PhotoBg.parse(v)],
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
