import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog_repository.dart';
import '../data/firestore_catalog_repository.dart';
import '../data/firestore_order_repository.dart';
import '../data/mock_data.dart';
import '../data/mock_products.dart';
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

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => FirestoreCatalogRepository());

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

  /// Phone + OTP sign-in — kept for the (currently unlinked) OTP screen; see
  /// CLAUDE.md roadmap. Real phone auth isn't wired in yet.
  void signIn(String phone) =>
      state = AppUser(uid: mockUser.uid, name: mockUser.name, phone: phone, email: mockUser.email);

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

  /// Deletes the account's own Firestore data (saved addresses) and then the
  /// Firebase Auth account itself. Orders are deliberately *not* deleted
  /// here — they're kept as business records, matching the Data Deletion
  /// page's stated policy (and `firestore.rules`, which never lets a client
  /// delete an order anyway). Throws `requires-recent-login` if the session
  /// is stale — call [reauthenticate] first when that happens.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final addresses = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('addresses').get();
    if (addresses.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in addresses.docs) {
        batch.delete(doc.reference);
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

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void add(Product product, Map<String, String> options, {int quantity = 1}) {
    final item = CartItem(product: product, options: options, quantity: quantity);
    final i = state.indexWhere((e) => e.key == item.key);
    if (i == -1) {
      state = [...state, item];
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
  }

  void remove(String key) => state = state.where((e) => e.key != key).toList();
  void clear() => state = const [];

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
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.quantity));
final cartSubtotalProvider = Provider<double>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.total));

// ---------- Wishlist ----------

/// Saved product id -> the price when it was saved (to spot price drops).
class WishlistNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    double price(String id) => mockProducts.firstWhere((p) => p.id == id).price;
    // Demo: the Prada bag was saved when it cost $50 more.
    return {'p174': price('p174') + 50, 'p133': price('p133')};
  }

  void toggle(String productId, double currentPrice) =>
      state = state.containsKey(productId) ? (Map.of(state)..remove(productId)) : {...state, productId: currentPrice};
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

  Future<void> _load(String uid) async {
    final fetched = await ref.read(orderRepositoryProvider).fetchOrders(uid);
    // Merge rather than overwrite: an order placed (optimistically added to
    // state) while this fetch was still in flight must not be dropped if the
    // fetch resolves after it.
    final existingIds = state.map((o) => o.id).toSet();
    final merged = [
      ...state,
      for (final o in fetched)
        if (!existingIds.contains(o.id)) o,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = merged;
  }

  Future<Order> place({
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
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
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

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

// ---------- Onboarding ----------

bool hasSeenWelcome(SharedPreferences? prefs) => prefs?.getBool('seen_welcome') ?? false;
Future<void> markWelcomeSeen(SharedPreferences? prefs) async => prefs?.setBool('seen_welcome', true);
