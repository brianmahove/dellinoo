import 'mock_data.dart';
import 'mock_products.dart';
import 'models.dart';

/// The UI only talks to this interface, so the mock can be swapped for the
/// real backend without touching screens.
abstract class CatalogRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Product>> fetchProducts();
  Future<List<DeliveryArea>> fetchDeliveryAreas();
}

class MockCatalogRepository implements CatalogRepository {
  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<Category>> fetchCategories() async => mockCategories;

  @override
  Future<List<Product>> fetchProducts() => Future.delayed(_latency, () => mockProducts);

  @override
  Future<List<DeliveryArea>> fetchDeliveryAreas() async => mockDeliveryAreas;
}
