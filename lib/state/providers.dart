import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog_repository.dart';
import '../data/mock_data.dart';
import '../data/mock_products.dart';
import '../data/models.dart';

/// Device storage, loaded in `main()` before the app starts. Null in tests,
/// in which case settings simply aren't persisted.
final prefsProvider = Provider<SharedPreferences?>((ref) => null);

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => MockCatalogRepository());

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

class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void signIn(String phone) => state = AppUser(name: mockUser.name, phone: phone);
  void signOut() => state = null;
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

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => buildMockOrders();

  Order place({
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
  }) {
    final now = DateTime.now();
    final order = Order(
      id: 'DL${10232 + state.length}',
      items: items,
      address: address,
      area: area,
      payment: payment,
      history: [StatusEvent(OrderStatus.placed, now), StatusEvent(OrderStatus.paid, now)],
    );
    state = [order, ...state];
    return order;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

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
