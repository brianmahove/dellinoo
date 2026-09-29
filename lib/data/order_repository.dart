import 'mock_data.dart';
import 'models.dart';

/// The UI only talks to this interface (via `orderRepositoryProvider`), so
/// the mock can be swapped for the real backend without touching screens —
/// same pattern as `CatalogRepository`.
abstract class OrderRepository {
  /// Orders belonging to [uid], most recent first.
  Future<List<Order>> fetchOrders(String uid);

  /// Places an order for [uid] and returns it (with its generated id).
  /// [customerName] is the signed-in account's own name (from [AppUser.name],
  /// not the delivery recipient's name in [address], which can be someone
  /// else) — stored on the order doc for the admin panel to show who
  /// actually placed it; the customer app itself never needs it back.
  /// [customerEmail] is stored on the order doc too, so the payments
  /// Cloudflare Worker can use it as Paynow's `authemail` without a separate
  /// profile lookup — the mock ignores it.
  Future<Order> placeOrder({
    required String uid,
    String? customerName,
    String? customerEmail,
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
  });
}

class MockOrderRepository implements OrderRepository {
  int _placedCount = 0;

  @override
  Future<List<Order>> fetchOrders(String uid) async => buildMockOrders();

  @override
  Future<Order> placeOrder({
    required String uid,
    String? customerName,
    String? customerEmail,
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
  }) async {
    final now = DateTime.now();
    final order = Order(
      id: 'DL${10232 + buildMockOrders().length + _placedCount}',
      items: items,
      address: address,
      area: area,
      payment: payment,
      history: [StatusEvent(OrderStatus.placed, now), StatusEvent(OrderStatus.paid, now)],
    );
    _placedCount++;
    return order;
  }
}
