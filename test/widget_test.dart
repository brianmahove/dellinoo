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
}
