import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../data/mock_data.dart';
import '../data/models.dart';

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
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.quantity));
final cartSubtotalProvider = Provider<double>((ref) => ref.watch(cartProvider).fold(0, (s, e) => s + e.total));

// ---------- Wishlist ----------

class WishlistNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'p174', 'p133'};

  void toggle(String productId) =>
      state = state.contains(productId) ? ({...state}..remove(productId)) : {...state, productId};
}

final wishlistProvider = NotifierProvider<WishlistNotifier, Set<String>>(WishlistNotifier.new);

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
