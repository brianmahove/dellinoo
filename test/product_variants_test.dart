import 'package:dellinoo/data/models.dart';
import 'package:dellinoo/features/product/product_detail_screen.dart';
import 'package:dellinoo/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _laptop = Product(
  id: 'lp',
  name: 'Test Laptop',
  brand: 'X',
  categoryId: 'laptops',
  price: 500,
  stockStatus: StockStatus.inStock,
  thumbnail: 'https://example.com/a.png',
  images: ['https://example.com/a.png'],
  description: '',
  variantGroups: [
    VariantGroup('RAM', ['8GB', '16GB'], priceAdds: [0, 60]),
    VariantGroup('Storage', ['256GB', '512GB'], priceAdds: [0, 40]),
  ],
);

class _SignedOut extends AuthNotifier {
  @override
  AppUser? build() => null;
}

void main() {
  testWidgets('product page shows priced options and moves the price as they are picked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    // The reviews section talks to Firestore directly; there's no Firebase in
    // unit tests, so ignore just that and let anything else fail the test.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('No Firebase App')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith((ref) async => [_laptop]),
          authProvider.overrideWith(_SignedOut.new),
        ],
        child: const MaterialApp(home: ProductDetailScreen(productId: 'lp')),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('16GB  +\$60.00'), findsOneWidget);
    expect(find.text('From: '), findsOneWidget);
    expect(find.text('\$500.00'), findsWidgets);

    await tester.tap(find.text('16GB  +\$60.00'));
    await tester.tap(find.text('512GB  +\$40.00'));
    await tester.pump();

    expect(find.text('From: '), findsNothing);
    expect(find.text('\$600.00'), findsWidgets);
  });
}
