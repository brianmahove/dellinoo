import 'category_icons.dart';
import 'models.dart';

/// The categories the app falls back to when the admin hasn't set any up yet
/// (an empty `categories` collection) and the list unit tests run against.
/// The real list lives in Firestore and is edited in the admin panel.
final mockCategories = <Category>[
  for (final e in const [
    ('women', 'Women'),
    ('men', 'Men'),
    ('kids', 'Kids'),
    ('shoes', 'Shoes'),
    ('handbags', 'Handbags'),
    ('wigs', 'Wigs'),
    ('phones', 'Phones'),
    ('watches', 'Watches'),
    ('laptops', 'Laptops'),
    ('games', 'Games'),
    ('electronics', 'Electronics'),
  ])
    Category(id: e.$1, name: e.$2, icon: categoryIcon(e.$1)),
];

/// Managed by the admin once the backend is in place.
const mockDeliveryAreas = <DeliveryArea>[
  DeliveryArea(id: 'pickup', name: 'Pick up at Dellinoo store (Harare CBD)', fee: 0, eta: 'Ready same day'),
  DeliveryArea(id: 'hre-cbd', name: 'Harare CBD', fee: 3, eta: '1–2 days'),
  DeliveryArea(id: 'hre-sub', name: 'Harare suburbs', fee: 5, eta: '1–2 days'),
  DeliveryArea(id: 'chitown', name: 'Chitungwiza / Ruwa / Norton', fee: 7, eta: '2–3 days'),
  DeliveryArea(id: 'byo', name: 'Bulawayo', fee: 10, eta: '2–4 days'),
  DeliveryArea(id: 'other', name: 'Other towns (courier)', fee: 12, eta: '3–5 days'),
];
