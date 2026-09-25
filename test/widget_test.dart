import 'package:dellinoo/data/models.dart';
import 'package:dellinoo/data/mock_products.dart';
import 'package:dellinoo/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cart merges identical items and totals correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    final shoe = mockProducts.firstWhere((p) => p.categoryId == 'shoes');

    cart.add(shoe, {'Size (EU)': '42'});
    cart.add(shoe, {'Size (EU)': '42'});
    cart.add(shoe, {'Size (EU)': '43'});

    expect(container.read(cartProvider), hasLength(2));
    expect(container.read(cartCountProvider), 3);
    expect(container.read(cartSubtotalProvider), closeTo(shoe.price * 3, 0.001));
  });

  test('placing an order adds it first with paid status', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final orders = container.read(ordersProvider.notifier);
    final before = container.read(ordersProvider).length;
    final order = orders.place(
      items: [CartItem(product: mockProducts.first, options: const {}, quantity: 2)],
      address: const Address(fullName: 'A', phone: '1', street: 's', city: 'Harare'),
      area: const DeliveryArea(id: 'x', name: 'X', fee: 5, eta: '1 day'),
      payment: PaymentMethod.ecocash,
    );

    expect(container.read(ordersProvider), hasLength(before + 1));
    expect(container.read(ordersProvider).first.id, order.id);
    expect(order.status, OrderStatus.paid);
    expect(order.total, closeTo(mockProducts.first.price * 2 + 5, 0.001));
  });

  test('removing from cart can be undone at the same position', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    final a = mockProducts[0], b = mockProducts[1], c = mockProducts[2];
    for (final p in [a, b, c]) {
      cart.add(p, const {});
    }
    final key = container.read(cartProvider)[1].key;

    final (item, index) = cart.removeForUndo(key)!;
    expect(container.read(cartProvider).map((e) => e.product.id), [a.id, c.id]);

    cart.restore(item, index);
    expect(container.read(cartProvider).map((e) => e.product.id), [a.id, b.id, c.id]);
  });

  test('wishlist reports a price drop only when the price fell', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(productsProvider.future);
    // p174 is seeded as saved when it cost $50 more; p133 at today's price.
    expect(container.read(priceDropProvider('p174')), closeTo(50, 0.001));
    expect(container.read(priceDropProvider('p133')), isNull);
  });

  test('China legs only appear for orders with China items', () {
    final china = mockProducts.firstWhere((p) => p.stockStatus == StockStatus.preorder);
    final local = mockProducts.firstWhere((p) => p.stockStatus == StockStatus.inStock);
    Order order(Product p) => Order(
      id: 'x',
      items: [CartItem(product: p, options: const {}, quantity: 1)],
      address: const Address(fullName: 'A', phone: '1', street: 's', city: 'Harare'),
      area: const DeliveryArea(id: 'x', name: 'X', fee: 0, eta: ''),
      payment: PaymentMethod.ecocash,
      history: [StatusEvent(OrderStatus.placed, DateTime(2026))],
    );
    expect(order(china).journey, contains(OrderStatus.inTransit));
    expect(order(local).journey.any((s) => s.chinaLeg), isFalse);
  });
}
