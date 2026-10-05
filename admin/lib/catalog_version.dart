import 'package:cloud_firestore/cloud_firestore.dart';

/// Tells customer apps the catalogue changed. The app keeps its product list
/// in Firestore's on-device cache and, on each launch, reads only this one
/// doc (`meta/catalog`): if `version` hasn't moved it shows the cached list
/// instead of re-reading every product, which is what keeps app opens cheap
/// on the Spark plan's 50k reads/day (lib/data/firestore_catalog_repository.dart).
///
/// Call after **every** write to `products`. A change made elsewhere (the
/// Firebase console, a script) won't reach phones until their cache's 24-hour
/// limit runs out, unless this doc is bumped too.
Future<void> bumpCatalogVersion() =>
    FirebaseFirestore.instance.doc('meta/catalog').set({'version': FieldValue.serverTimestamp()});
