import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/push.dart';
import '../data/catalog_repository.dart';
import '../data/firestore_catalog_repository.dart';
import '../data/firestore_order_repository.dart';
import '../data/models.dart';
import '../data/order_repository.dart';

/// Analytics is best-effort: a logging hiccup (or, in unit tests, Firebase
/// never having been initialized at all) must never break real functionality
/// like adding to cart or checking out. `FirebaseAnalytics.instance` itself
/// throws synchronously when there's no Firebase app yet, so this needs a
/// try/catch around the call, not just a `.catchError` on its Future.
void _logSafely(Future<void> Function() action) {
  try {
    action().catchError((_) {});
  } catch (_) {
    // Ignored — see above.
  }
}

/// Device storage, loaded in `main()` before the app starts. Null in tests,
/// in which case settings simply aren't persisted.
final prefsProvider = Provider<SharedPreferences?>((ref) => null);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => FirestoreCatalogRepository(prefs: ref.watch(prefsProvider)),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchCategories(),
);

final productsProvider = FutureProvider<List<Product>>((ref) => ref.watch(catalogRepositoryProvider).fetchProducts());

final deliveryAreasProvider = FutureProvider<List<DeliveryArea>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchDeliveryAreas(),
);

final productProvider = Provider.family<Product?, String>((ref, id) {
  final products = ref.watch(productsProvider).value ?? const [];
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
});

// ---------- Connectivity ----------

/// Whether the device has *a* network connection (not proof that Dellinoo's
/// servers are reachable). Errors — e.g. the plugin missing in unit tests —
/// count as online so the offline banner never shows spuriously.
final onlineProvider = StreamProvider<bool>((ref) async* {
  bool online(List<ConnectivityResult> r) => !r.every((e) => e == ConnectivityResult.none);
  try {
    final connectivity = Connectivity();
    yield online(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(online);
  } catch (_) {
    yield true;
  }
});

// ---------- Auth ----------

/// Maps a Firebase [User] to the app's own [AppUser].
AppUser? _appUserFrom(User? user) {
  if (user == null) return null;
  final displayName = user.displayName;
  return AppUser(
    uid: user.uid,
    name: (displayName != null && displayName.trim().isNotEmpty) ? displayName : (user.email ?? 'Dellinoo customer'),
    phone: user.phoneNumber ?? '',
    email: user.email,
    photoUrl: user.photoURL,
  );
}

class AuthNotifier extends Notifier<AppUser?> {
  StreamSubscription<User?>? _sub;

  @override
  AppUser? build() {
    final auth = FirebaseAuth.instance;
    ref.onDispose(() => _sub?.cancel());
    // Keeps state in sync with sign-in/out from any source (password, Google,
    // token expiry) and across app restarts (Firebase persists the session).
    _sub = auth.authStateChanges().listen((user) => state = _appUserFrom(user));
    return _appUserFrom(auth.currentUser);
  }

  Future<void> signInWithPassword({required String email, required String password}) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    _logSafely(() => FirebaseAnalytics.instance.logLogin(loginMethod: 'password'));
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    await credential.user?.updateDisplayName(name);
    // updateDisplayName doesn't update the cached currentUser on its own; reload
    // so the authStateChanges listener above picks up the new name.
    await FirebaseAuth.instance.currentUser?.reload();
    state = _appUserFrom(FirebaseAuth.instance.currentUser);
    _logSafely(() => FirebaseAnalytics.instance.logSignUp(signUpMethod: 'password'));
  }

  /// Throws [GoogleSignInException] (code `canceled`) if the user backs out.
  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(code: 'no-id-token', message: "Google didn't return a sign-in token.");
    }
    await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    _logSafely(() => FirebaseAnalytics.instance.logLogin(loginMethod: 'google'));
  }

  /// Throws a [FirebaseAuthException] with code `canceled` if the user backs
  /// out of the Facebook sheet (see [authErrorMessage] in auth_widgets.dart,
  /// which turns that into "no toast" rather than an error message).
  Future<void> signInWithFacebook() async {
    // `enabled` tracking returns a classic access token (needed by Firebase);
    // the default `limited` tracking returns an iOS-only JWT that Firebase can't use.
    final result = await FacebookAuth.instance.login(loginTracking: LoginTracking.enabled);
    if (result.status == LoginStatus.cancelled) {
      throw FirebaseAuthException(code: 'canceled', message: 'Sign in canceled');
    }
    final token = result.accessToken?.tokenString;
    if (result.status != LoginStatus.success || token == null) {
      throw FirebaseAuthException(
        code: 'facebook-login-failed',
        message: result.message ?? "Facebook sign-in didn't complete.",
      );
    }
    await FirebaseAuth.instance.signInWithCredential(FacebookAuthProvider.credential(token));
    _logSafely(() => FirebaseAnalytics.instance.logLogin(loginMethod: 'facebook'));
  }

  /// Lets a signed-in customer change their display name from the account
  /// screen (works regardless of sign-in method — email/password, Google or
  /// Facebook all set this the same way).
  Future<void> updateName(String name) async {
    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
    await refresh();
  }

  /// Re-reads the current user from Firebase and updates [state] — used
  /// after anything that changes the account server-side outside a normal
  /// sign-in (verifying email, linking a provider, etc).
  Future<void> refresh() async {
    await FirebaseAuth.instance.currentUser?.reload();
    state = _appUserFrom(FirebaseAuth.instance.currentUser);
  }

  Future<void> sendEmailVerification() => FirebaseAuth.instance.currentUser!.sendEmailVerification();

  /// Re-proves identity for a sensitive action (change email/password,
  /// delete account) — Firebase requires a *recent* sign-in for these and
  /// throws `requires-recent-login` otherwise. For Google/Facebook this
  /// silently re-runs that provider's sign-in; for email/password, the
  /// caller must supply [password] (prompt for it first).
  Future<void> reauthenticate({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final providerId = user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password';
    final AuthCredential credential;
    switch (providerId) {
      case 'google.com':
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(code: 'no-id-token', message: "Google didn't return a sign-in token.");
        }
        credential = GoogleAuthProvider.credential(idToken: idToken);
      case 'facebook.com':
        final result = await FacebookAuth.instance.login(loginTracking: LoginTracking.enabled);
        final token = result.accessToken?.tokenString;
        if (result.status != LoginStatus.success || token == null) {
          throw FirebaseAuthException(
            code: 'facebook-login-failed',
            message: result.message ?? "Facebook sign-in didn't complete.",
          );
        }
        credential = FacebookAuthProvider.credential(token);
      default:
        if (password == null || password.isEmpty) {
          throw FirebaseAuthException(code: 'password-required', message: 'Enter your password to continue.');
        }
        credential = EmailAuthProvider.credential(email: user.email!, password: password);
    }
    await user.reauthenticateWithCredential(credential);
  }

  /// Deletes the account's own Firestore data (saved addresses, push tokens,
  /// wishlist, notification inbox and prefs) and then the Firebase Auth
  /// account itself. Orders are deliberately *not* deleted here — they're
  /// kept as business records, matching the Data Deletion page's stated policy (and `firestore.rules`, which never lets a client
  /// delete an order anyway). Throws `requires-recent-login` if the session
  /// is stale — call [reauthenticate] first when that happens.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final addresses = await userDoc.collection('addresses').get();
    final pushTokens = await userDoc.collection('fcmTokens').get();
    final wishlist = await userDoc.collection('wishlist').get();
    final inbox = await userDoc.collection('notifications').get();
    final refs = [
      for (final d in [...addresses.docs, ...pushTokens.docs, ...wishlist.docs, ...inbox.docs]) d.reference,
      userDoc,
    ];
    // Firestore caps a batch at 500 writes; an old inbox could pass that.
    for (var i = 0; i < refs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    await user.delete();
  }

  /// Adds Google as an extra sign-in method on the current account.
  Future<void> linkGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(code: 'no-id-token', message: "Google didn't return a sign-in token.");
    }
    await FirebaseAuth.instance.currentUser?.linkWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    await refresh();
  }

  /// Adds Facebook as an extra sign-in method on the current account.
  Future<void> linkFacebook() async {
    final result = await FacebookAuth.instance.login(loginTracking: LoginTracking.enabled);
    final token = result.accessToken?.tokenString;
    if (result.status != LoginStatus.success || token == null) {
      throw FirebaseAuthException(
        code: 'facebook-login-failed',
        message: result.message ?? "Facebook sign-in didn't complete.",
      );
    }
    await FirebaseAuth.instance.currentUser?.linkWithCredential(FacebookAuthProvider.credential(token));
    await refresh();
  }

  /// Adds email/password as an extra sign-in method on a Google/Facebook
  /// account, using its existing email.
  Future<void> linkPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No email on this account to add a password to.');
    }
    await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
    await refresh();
  }

  /// Removes a sign-in method ([providerId] e.g. `google.com`) from the
  /// current account. Refuses to remove the last one — that would lock the
  /// customer out.
  Future<void> unlink(String providerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.providerData.length <= 1) {
      throw FirebaseAuthException(code: 'last-provider', message: "You can't remove your only sign-in method.");
    }
    await user.unlink(providerId);
    await refresh();
  }

  /// Changes the password on an email/password account. [currentPassword]
  /// re-proves identity first (see [reauthenticate]).
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await reauthenticate(password: currentPassword);
    await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
  }

  /// Starts an email change: Firebase sends a confirmation link to
  /// [newEmail], and the change only takes effect once that's clicked (the
  /// modern, non-deprecated replacement for the old immediate `updateEmail`,
  /// which Firebase disabled for new projects over account-hijacking risk).
  /// [currentPassword] re-proves identity first (see [reauthenticate]).
  Future<void> changeEmail({required String currentPassword, required String newEmail}) async {
    await reauthenticate(password: currentPassword);
    await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  Future<void> signOut() async {
    await Push.unregister();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Not signed in via Google, or already disconnected — fine either way.
    }
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {
      // Not signed in via Facebook — fine.
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

// ---------- Cart ----------

/// Lightweight on-disk record: just enough to rebuild a [CartItem] against
/// whatever the catalogue says about that product *now* (price/name can't be
/// trusted from a stale save — same reasoning as "Order again").
class _CartEntry {
  const _CartEntry(this.productId, this.options, this.quantity);

  final String productId;
  final Map<String, String> options;
  final int quantity;

  Map<String, dynamic> toJson() => {'productId': productId, 'options': options, 'quantity': quantity};

  static _CartEntry fromJson(Map<String, dynamic> json) => _CartEntry(
    json['productId'] as String,
    Map<String, String>.from(json['options'] as Map),
    json['quantity'] as int,
  );
}

/// Persisted locally (SharedPreferences), not through Firestore — cart stays
/// per-device/pre-purchase by design (see CLAUDE.md roadmap item 1), it just
/// needs to survive the app being closed and reopened.
class CartNotifier extends Notifier<List<CartItem>> {
  static const _prefsKey = 'cart_v1';

  @override
  List<CartItem> build() {
    // Fire-and-forget rather than `ref.watch(productsProvider)`: watching
    // would re-run build() (dropping whatever's in `state`) every time the
    // catalogue future changes, including well after startup.
    unawaited(_hydrate());
    return const [];
  }

  Future<void> _hydrate() async {
    final raw = ref.read(prefsProvider)?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    List<Product> products;
    try {
      products = await ref.read(productsProvider.future);
    } catch (_) {
      return; // Catalogue unreachable — leave the cart empty rather than crash.
    }
    final items = <CartItem>[];
    for (final json in jsonDecode(raw) as List) {
      final entry = _CartEntry.fromJson(json as Map<String, dynamic>);
      Product? product;
      for (final p in products) {
        if (p.id == entry.productId) {
          product = p;
          break;
        }
      }
      // Silently drops items for products removed from the catalogue since save.
      if (product != null) items.add(CartItem(product: product, options: entry.options, quantity: entry.quantity));
    }
    // Don't clobber items the user already added while this was loading.
    if (state.isEmpty && items.isNotEmpty) state = items;
  }

  void _persist() {
    final prefs = ref.read(prefsProvider);
    if (prefs == null) return;
    final entries = [for (final e in state) _CartEntry(e.product.id, e.options, e.quantity).toJson()];
    prefs.setString(_prefsKey, jsonEncode(entries));
  }

  void add(Product product, Map<String, String> options, {int quantity = 1}) {
    final item = CartItem(product: product, options: options, quantity: quantity);
    final i = state.indexWhere((e) => e.key == item.key);
    if (i == -1) {
      state = [...state, item];
      _persist();
    } else {
      setQuantity(state[i].key, state[i].quantity + quantity);
    }
    _logSafely(
      () => FirebaseAnalytics.instance.logAddToCart(
        currency: 'USD',
        value: product.price * quantity,
        items: [
          AnalyticsEventItem(
            itemId: product.id,
            itemName: product.name,
            itemCategory: product.categoryId,
            price: product.price,
            quantity: quantity,
          ),
        ],
      ),
    );
  }

  void setQuantity(String key, int quantity) {
    if (quantity <= 0) return remove(key);
    state = [for (final e in state) e.key == key ? e.copyWith(quantity: quantity) : e];
    _persist();
  }

  void remove(String key) {
    state = state.where((e) => e.key != key).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  /// Removes an item and returns what's needed to [restore] it (for "Undo").
  (CartItem, int)? removeForUndo(String key) {
    final i = state.indexWhere((e) => e.key == key);
    if (i == -1) return null;
    final item = state[i];
    remove(key);
    return (item, i);
  }

  void restore(CartItem item, int index) {
    if (state.any((e) => e.key == item.key)) return;
    state = [...state]..insert(index.clamp(0, state.length), item);
    _persist();
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.quantity));
final cartSubtotalProvider = Provider<double>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.total));

// ---------- Wishlist ----------

/// Saved product id -> the price when it was saved (to spot price drops).
/// Persisted locally (SharedPreferences), same as [CartNotifier], and synced
/// to `users/{uid}/wishlist/{productId}` while signed in. The synced copy is
/// what the payments Worker's price-drop job reads (payments/src/pricedrops.ts),
/// and what follows the customer to a new phone.
class WishlistNotifier extends Notifier<Map<String, double>> {
  static const _prefsKey = 'wishlist_v1';
  static const _syncedAtKey = 'wishlist_synced_at_';
  String? _uid;

  CollectionReference<Map<String, dynamic>> _remote(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('wishlist');

  @override
  Map<String, double> build() {
    // Deferred a microtask: the listener can fire during build (immediately),
    // before `state` exists.
    ref.listen(
      authProvider.select((u) => u?.uid),
      (previous, uid) => Future.microtask(() => _onAuthChanged(previous, uid)),
      fireImmediately: true,
    );
    final raw = ref.read(prefsProvider)?.getString(_prefsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((id, price) => MapEntry(id, (price as num).toDouble()));
    }
    // Nothing saved yet (fresh install, or prefs unavailable in tests): the
    // wishlist starts empty — the customer fills it themselves.
    return {};
  }

  void toggle(String productId, double currentPrice) {
    final removing = state.containsKey(productId);
    state = removing ? (Map.of(state)..remove(productId)) : {...state, productId: currentPrice};
    _persist();
    final uid = _uid;
    if (uid == null) return;
    final doc = _remote(uid).doc(productId);
    // Fire and forget: Firestore queues writes offline and retries.
    (removing ? doc.delete() : doc.set(_remoteFields(productId, currentPrice))).catchError((Object _) {});
  }

  void _persist() => ref.read(prefsProvider)?.setString(_prefsKey, jsonEncode(state));

  // `productId` duplicates the doc id so the Worker's price-drop job can
  // query all customers' wishlists for just the products that got cheaper.
  static Map<String, dynamic> _remoteFields(String productId, double price) => {
    'productId': productId,
    'savedPrice': price,
    'savedAt': FieldValue.serverTimestamp(),
  };

  Future<void> _onAuthChanged(String? previous, String? uid) async {
    _uid = uid;
    if (uid == null) {
      // Signed out: this wishlist belongs to that account (it's safe in
      // Firestore), so don't leave it on the phone for the next person.
      if (previous != null) {
        state = {};
        _persist();
        ref.read(prefsProvider)?.remove('$_syncedAtKey$previous');
      }
      return;
    }
    // Every toggle while signed in already writes through, so the local list
    // only drifts from the account when another phone changes it. Re-merging
    // on every launch would cost a read per wishlist item each time; once a
    // day is plenty (and a fresh sign-in always merges, since sign-out clears
    // this stamp).
    final prefs = ref.read(prefsProvider);
    final syncedAt = prefs?.getInt('$_syncedAtKey$uid');
    if (syncedAt != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(syncedAt)) < const Duration(hours: 24)) {
      return;
    }
    try {
      // Merge both ways: items saved while signed out get uploaded, items
      // from another phone come down. The account's saved price wins for
      // items in both, since it's the older one.
      final snapshot = await _remote(uid).get();
      if (_uid != uid) return;
      final remote = {
        for (final d in snapshot.docs)
          if (d.data()['savedPrice'] is num) d.id: (d.data()['savedPrice'] as num).toDouble(),
      };
      final localOnly = {
        for (final e in state.entries)
          if (!remote.containsKey(e.key)) e.key: e.value,
      };
      if (localOnly.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        localOnly.forEach((id, price) => batch.set(_remote(uid).doc(id), _remoteFields(id, price)));
        await batch.commit();
      }
      state = {...state, ...remote};
      _persist();
      await prefs?.setInt('$_syncedAtKey$uid', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Offline or similar — the local list keeps working; the next sign-in
      // (or app start) tries again.
    }
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, Map<String, double>>(WishlistNotifier.new);

/// How much cheaper a saved product is now than when it was saved, if at all.
final priceDropProvider = Provider.family<double?, String>((ref, id) {
  final savedAt = ref.watch(wishlistProvider)[id];
  final product = ref.watch(productProvider(id));
  if (savedAt == null || product == null) return null;
  final drop = savedAt - product.price;
  return drop >= 0.01 ? drop : null;
});

// ---------- Recently viewed / recent searches (persisted) ----------

class _RecentList extends Notifier<List<String>> {
  _RecentList(this._key, this._max);

  final String _key;
  final int _max;

  @override
  List<String> build() => ref.read(prefsProvider)?.getStringList(_key) ?? const [];

  void add(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    state = [v, ...state.where((e) => e.toLowerCase() != v.toLowerCase())].take(_max).toList();
    ref.read(prefsProvider)?.setStringList(_key, state);
  }

  void clear() {
    state = const [];
    ref.read(prefsProvider)?.remove(_key);
  }
}

/// Product ids, most recent first.
final recentlyViewedProvider = NotifierProvider<_RecentList, List<String>>(() => _RecentList('recently_viewed', 10));
final recentSearchesProvider = NotifierProvider<_RecentList, List<String>>(() => _RecentList('recent_searches', 8));

// ---------- Orders ----------

final orderRepositoryProvider = Provider<OrderRepository>((ref) => FirestoreOrderRepository());

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() {
    // Reactive: rebuilds (and re-fetches) whenever sign-in state changes.
    final uid = ref.watch(authProvider)?.uid;
    if (uid == null) return const [];
    _load(uid);
    return const [];
  }

  /// Pull-to-refresh: re-fetches from the backend (merging, same as the
  /// first load).
  Future<void> refresh() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid != null) await _load(uid);
  }

  Future<void> _load(String uid) async {
    final fetched = await ref.read(orderRepositoryProvider).fetchOrders(uid);
    // Merge rather than overwrite: an order placed (optimistically added to
    // state) while this fetch was still in flight must not be dropped if the
    // fetch resolves after it. Fetched copies win for orders in both lists,
    // so a refresh (e.g. after a status push, see core/push.dart) actually
    // picks up the admin's new status.
    final fetchedIds = fetched.map((o) => o.id).toSet();
    final merged = [
      ...fetched,
      for (final o in state)
        if (!fetchedIds.contains(o.id)) o,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = merged;
  }

  Future<Order> place({
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
    Coupon? coupon,
  }) async {
    final user = ref.read(authProvider);
    if (user == null) throw StateError('Must be signed in to place an order.');
    final order = await ref
        .read(orderRepositoryProvider)
        .placeOrder(
          uid: user.uid,
          customerName: user.name,
          customerEmail: user.email,
          items: items,
          address: address,
          area: area,
          payment: payment,
          coupon: coupon,
        );
    state = [order, ...state];
    _logSafely(
      () => FirebaseAnalytics.instance.logPurchase(
        currency: 'USD',
        value: order.total,
        shipping: area.fee,
        transactionId: order.id,
        items: [
          for (final i in items)
            AnalyticsEventItem(
              itemId: i.product.id,
              itemName: i.product.name,
              itemCategory: i.product.categoryId,
              price: i.product.price,
              quantity: i.quantity,
            ),
        ],
      ),
    );
    return order;
  }

  /// Reflects a payment the payments Worker already confirmed (see
  /// lib/widgets/payment_dialog.dart's PaymentWaitDialog) into local state —
  /// without this, a screen reading `ordersProvider` keeps showing the order
  /// as unpaid until the next full re-fetch (sign-in/out), even though it's
  /// genuinely paid. [docId] is the order's Firestore document id (see
  /// Order.docId), not its display id.
  void markPaid(String docId) {
    state = [
      for (final o in state)
        if (o.docId == docId && o.status == OrderStatus.placed)
          o.withHistory([...o.history, StatusEvent(OrderStatus.paid, DateTime.now())])
        else
          o,
    ];
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

// ---------- Coupons ----------

/// The promo code currently applied in checkout (cleared once the order is
/// placed, or when the customer removes it).
class AppliedCouponNotifier extends Notifier<Coupon?> {
  @override
  Coupon? build() => null;

  void set(Coupon? coupon) => state = coupon;
}

final appliedCouponProvider = NotifierProvider<AppliedCouponNotifier, Coupon?>(AppliedCouponNotifier.new);

class CouponException implements Exception {
  const CouponException(this.message);
  final String message;
}

/// Looks a code up and checks it applies to this customer/cart; returns the
/// coupon, or throws a [CouponException] whose message is safe to show.
/// (Best-effort UX check — the payments Worker enforces it for real.)
Future<Coupon> lookupCoupon(String rawCode, {required String uid, required double subtotal}) async {
  final code = rawCode.trim().toUpperCase();
  if (code.isEmpty) throw const CouponException('Enter a promo code');
  final db = FirebaseFirestore.instance;
  final snap = await db.collection('coupons').doc(code).get();
  final d = snap.data();
  if (d == null || d['active'] != true) throw const CouponException("That code isn't valid");
  final coupon = Coupon(
    code: code,
    percentOff: (d['percentOff'] as num?)?.toDouble(),
    amountOff: (d['amountOff'] as num?)?.toDouble(),
    minSubtotal: (d['minSubtotal'] as num?)?.toDouble(),
    firstOrderOnly: d['firstOrderOnly'] as bool? ?? false,
    expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
  );
  if (coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now())) {
    throw const CouponException('That code has expired');
  }
  if (coupon.minSubtotal != null && subtotal < coupon.minSubtotal!) {
    throw CouponException('Spend at least \$${coupon.minSubtotal!.toStringAsFixed(0)} to use this code');
  }
  if (coupon.firstOrderOnly) {
    final mine = await db.collection('orders').where('userId', isEqualTo: uid).get();
    if (mine.docs.any((o) => o.data().containsKey('paidAt'))) {
      throw const CouponException('That code is for first orders only');
    }
  }
  return coupon;
}

// ---------- Saved addresses ----------

/// Talks to Firestore directly (no repository interface, unlike the
/// catalogue/orders) — this is a small, single-screen feature, not a
/// backend-swap point worth the extra abstraction.
class AddressBookNotifier extends Notifier<List<SavedAddress>> {
  @override
  List<SavedAddress> build() {
    final uid = ref.watch(authProvider)?.uid;
    if (uid == null) return const [];
    _load(uid);
    return const [];
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses');

  SavedAddress _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return SavedAddress(
      id: doc.id,
      label: d['label'] as String? ?? 'Address',
      address: Address(
        fullName: d['fullName'] as String? ?? '',
        phone: d['phone'] as String? ?? '',
        street: d['street'] as String? ?? '',
        city: d['city'] as String? ?? '',
      ),
      isDefault: d['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toMap(String label, Address address, bool isDefault) => {
    'label': label,
    'fullName': address.fullName,
    'phone': address.phone,
    'street': address.street,
    'city': address.city,
    'isDefault': isDefault,
  };

  Future<void> _load(String uid) async {
    final snap = await _collection(uid).get();
    state = [for (final d in snap.docs) _fromDoc(d)];
  }

  String get _uid {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) throw StateError('Must be signed in to manage addresses.');
    return uid;
  }

  Future<SavedAddress> add({required String label, required Address address, bool isDefault = false}) async {
    final uid = _uid;
    if (isDefault) await _clearOtherDefaults(uid);
    final doc = await _collection(uid).add(_toMap(label, address, isDefault));
    final saved = SavedAddress(id: doc.id, label: label, address: address, isDefault: isDefault);
    state = isDefault ? [for (final a in state) a.copyWith(isDefault: false), saved] : [...state, saved];
    return saved;
  }

  Future<void> update(SavedAddress updated) async {
    final uid = _uid;
    if (updated.isDefault) await _clearOtherDefaults(uid);
    await _collection(uid).doc(updated.id).update(_toMap(updated.label, updated.address, updated.isDefault));
    state = [
      for (final a in state)
        if (a.id == updated.id) updated else updated.isDefault ? a.copyWith(isDefault: false) : a,
    ];
  }

  Future<void> remove(String id) async {
    await _collection(_uid).doc(id).delete();
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> _clearOtherDefaults(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final a in state.where((a) => a.isDefault)) {
      batch.update(_collection(uid).doc(a.id), {'isDefault': false});
    }
    await batch.commit();
  }
}

final addressBookProvider = NotifierProvider<AddressBookNotifier, List<SavedAddress>>(AddressBookNotifier.new);

// ---------- Appearance ----------

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values.asNameMap()[ref.read(prefsProvider)?.getString('theme_mode')] ?? ThemeMode.system;

  void set(ThemeMode mode) {
    state = mode;
    ref.read(prefsProvider)?.setString('theme_mode', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ---------- Data saver ----------

/// Loads smaller photos to save mobile data.
class DataSaverNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider)?.getBool('data_saver') ?? false;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider)?.setBool('data_saver', on);
  }
}

final dataSaverProvider = NotifierProvider<DataSaverNotifier, bool>(DataSaverNotifier.new);

// ---------- Performance toggles ----------

/// Frosted-glass blur. Off swaps every blur for a plain translucent fill
/// (GlassBox.enabled), which low-end phones handle far better. main() mirrors
/// this onto the static and remounts the tree so it takes effect at once.
class GlassEffectsNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider)?.getBool('glass_effects') ?? true;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider)?.setBool('glass_effects', on);
  }
}

final glassEffectsProvider = NotifierProvider<GlassEffectsNotifier, bool>(GlassEffectsNotifier.new);

/// An in-app "reduce motion", on top of the phone's own setting: decorative
/// animations (confetti, shimmer, heart burst) stop either way.
class ReduceMotionNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider)?.getBool('reduce_motion') ?? false;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider)?.setBool('reduce_motion', on);
  }
}

final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);

// ---------- Notification preferences ----------

/// Wishlist price-drop pushes. The Worker's price-drop job reads this from
/// `users/{uid}.priceDropAlerts` (missing = on), so it's an account setting:
/// only shown while signed in, cached locally for the switch's first frame.
class PriceDropAlertsNotifier extends Notifier<bool> {
  static const _prefsKey = 'price_drop_alerts';

  @override
  bool build() {
    final uid = ref.watch(authProvider)?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        final value = doc.data()?['priceDropAlerts'];
        if (value is bool && value != state) _cache(value);
      }, onError: (Object _) {});
    }
    return ref.read(prefsProvider)?.getBool(_prefsKey) ?? true;
  }

  void _cache(bool on) {
    state = on;
    ref.read(prefsProvider)?.setBool(_prefsKey, on);
  }

  void set(bool on) {
    _cache(on);
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'priceDropAlerts': on}, SetOptions(merge: true))
        .catchError((Object _) {});
  }
}

final priceDropAlertsProvider = NotifierProvider<PriceDropAlertsNotifier, bool>(PriceDropAlertsNotifier.new);

/// Promo broadcasts from the admin panel: the FCM `promos` topic, so it's a
/// per-phone setting that works signed in or not. [Push.init] applies the
/// saved value at startup.
class DealsAlertsNotifier extends Notifier<bool> {
  static const prefsKey = 'deals_alerts';

  @override
  bool build() => ref.read(prefsProvider)?.getBool(prefsKey) ?? true;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider)?.setBool(prefsKey, on);
    Push.setPromos(on);
  }
}

final dealsAlertsProvider = NotifierProvider<DealsAlertsNotifier, bool>(DealsAlertsNotifier.new);

// ---------- Notification inbox ----------

/// One row in the in-app inbox (lib/features/notifications/). Personal ones
/// come from `users/{uid}/notifications`, written by the payments Worker for
/// every push it sends this customer; promos from the public `promos`
/// collection (one doc per broadcast, so no per-customer copies).
class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.kind,
    required this.at,
    required this.read,
    this.promo = false,
  });

  final String id;
  final String title;
  final String body;

  /// go_router location to open on tap; empty for none.
  final String route;

  /// order, payment, reminder, price_drop, quote, invoice or promo.
  final String kind;
  final DateTime at;
  final bool read;
  final bool promo;

  factory InboxItem.personal(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return InboxItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      route: d['route'] as String? ?? '',
      kind: d['kind'] as String? ?? 'order',
      at: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }

  factory InboxItem.promoFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc, DateTime seenAt) {
    final d = doc.data();
    final at = (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return InboxItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      route: d['route'] as String? ?? '',
      kind: 'promo',
      at: at,
      read: !at.isAfter(seenAt),
      promo: true,
    );
  }
}

CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

/// When the customer last opened the inbox, for promo "unread" state
/// (promos are shared docs, so read state lives on the phone). A fresh
/// install starts at "now" so old promos don't all show as new.
class PromosSeenNotifier extends Notifier<DateTime> {
  static const _prefsKey = 'promos_seen_at';

  @override
  DateTime build() {
    final prefs = ref.read(prefsProvider);
    final millis = prefs?.getInt(_prefsKey);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    prefs?.setInt(_prefsKey, now.millisecondsSinceEpoch);
    return now;
  }

  void markSeen() {
    state = DateTime.now();
    ref.read(prefsProvider)?.setInt(_prefsKey, state.millisecondsSinceEpoch);
  }
}

final promosSeenProvider = NotifierProvider<PromosSeenNotifier, DateTime>(PromosSeenNotifier.new);

/// Badge count for the Home bell. Deliberately two small queries for
/// *unread* items only (usually none, so ~1 read each) rather than the full
/// list — Home is open a lot and this counts against Spark's read quota.
final _personalUnreadProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authProvider)?.uid;
  if (uid == null) return Stream.value(0);
  return _inbox(uid).where('read', isEqualTo: false).limit(20).snapshots().map((s) => s.docs.length);
});

final _promosUnreadProvider = StreamProvider<int>((ref) {
  if (!ref.watch(dealsAlertsProvider)) return Stream.value(0);
  final seenAt = ref.watch(promosSeenProvider);
  return FirebaseFirestore.instance
      .collection('promos')
      .where('sentAt', isGreaterThan: Timestamp.fromDate(seenAt))
      .limit(10)
      .snapshots()
      .map((s) => s.docs.length);
});

final inboxUnreadCountProvider = Provider<int>(
  (ref) => (ref.watch(_personalUnreadProvider).value ?? 0) + (ref.watch(_promosUnreadProvider).value ?? 0),
);

/// The full inbox, only while the inbox screen is open (autoDispose).
final personalInboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(authProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return _inbox(uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) InboxItem.personal(d)]);
});

final promosInboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  // Hidden along with the pushes when "Deals & offers" is off.
  if (!ref.watch(dealsAlertsProvider)) return Stream.value(const []);
  // Read, not watched: opening the inbox marks promos seen, and the list
  // shouldn't flip them all to "read" while the customer is looking at it.
  final seenAt = ref.read(promosSeenProvider);
  return FirebaseFirestore.instance
      .collection('promos')
      .orderBy('sentAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => [for (final d in s.docs) InboxItem.promoFrom(d, seenAt)]);
});

/// Marks everything read: personal docs in Firestore (only the `read` field,
/// per firestore.rules) and promos via [PromosSeenNotifier].
Future<void> markInboxRead(WidgetRef ref) async {
  ref.read(promosSeenProvider.notifier).markSeen();
  final uid = ref.read(authProvider)?.uid;
  if (uid == null) return;
  try {
    final unread = await _inbox(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  } catch (_) {
    // Offline — the badge just clears next time.
  }
}

Future<void> deleteInboxItem(WidgetRef ref, String id) async {
  final uid = ref.read(authProvider)?.uid;
  if (uid != null) await _inbox(uid).doc(id).delete();
}

// ---------- Onboarding ----------

bool hasSeenWelcome(SharedPreferences? prefs) => prefs?.getBool('seen_welcome') ?? false;
Future<void> markWelcomeSeen(SharedPreferences? prefs) async => prefs?.setBool('seen_welcome', true);
