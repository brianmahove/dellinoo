/// One area of the panel an admin can be given (or not).
class AccessArea {
  const AccessArea(this.key, this.label, this.hint, {this.hasLevels = true});

  /// Whether "View only" makes sense. Dashboard and Customers have nothing to
  /// change, so they are just on or off.
  final bool hasLevels;

  /// Stored in `admins/{email}.access`: `key` alone means can edit (add,
  /// change, delete, process); `key:view` means read only. Mirrored in firestore.rules and the
  /// payments Worker (`hasAccess`) — change a key in all three places.
  final String key;
  final String label;
  final String hint;
}

/// Every area that can be granted. "Admins" is deliberately not in here: only
/// a full admin can manage other admins, so it can't be handed out.
const accessAreas = [
  AccessArea('dashboard', 'Dashboard', 'Sales figures and totals', hasLevels: false),
  AccessArea('products', 'Products', 'Add, edit and remove products and photos'),
  AccessArea('orders', 'Orders', 'See orders, update their status, confirm payments'),
  AccessArea('categories', 'Categories', 'Shop categories'),
  AccessArea('customers', 'Customers', 'Customer list and their orders', hasLevels: false),
  AccessArea('delivery', 'Delivery areas', 'Where you deliver and the fees'),
  AccessArea('coupons', 'Coupons', 'Discount codes'),
  AccessArea('requests', 'Requests', 'Items customers asked you to source'),
  AccessArea('invoices', 'Invoices', 'Issue and download invoices'),
  AccessArea('notifications', 'Notifications', 'Send promo pushes'),
  AccessArea('payments', 'Payment details', 'Accounts shown for manual payments'),
];

/// What the signed-in admin may use, set by the shell once their
/// `admins/{email}` doc loads. The real enforcement is firestore.rules and the
/// Worker; this only decides what the panel shows.
class AdminAccess {
  AdminAccess._();

  /// `null` = full admin (no `access` list on their doc).
  static Set<String>? areas;

  static bool get isFull => areas == null;

  /// May open the screen — view only or edit. [area] `null` is a screen only a
  /// full admin sees (the Admins page).
  static bool allows(String? area) =>
      isFull || (area != null && (areas!.contains(area) || areas!.contains('$area:view')));

  /// May add, change, delete and process things in [area]; false = look only.
  static bool canEdit(String area) => isFull || areas!.contains(area);

  static void load(Map<String, dynamic>? doc) {
    final list = doc?['access'];
    areas = list is List ? list.whereType<String>().toSet() : null;
  }

  /// "Full access", or the names of the areas, for the Admins list.
  static String summary(Map<String, dynamic>? doc) {
    final list = doc?['access'];
    if (list is! List) return 'Full access';
    final names = [
      for (final a in accessAreas)
        if (list.contains(a.key)) a.label else if (list.contains('${a.key}:view')) '${a.label} (view)',
    ];
    if (names.isEmpty) return 'No access yet';
    return names.length <= 3 ? names.join(', ') : '${names.take(3).join(', ')} +${names.length - 3} more';
  }
}
