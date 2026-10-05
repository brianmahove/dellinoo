import 'package:flutter/material.dart';
import '../core/iconly.dart';

enum StockStatus {
  inStock('In stock', 'Delivered in 1–3 days', 3),
  preorder('Arrives in 2–3 weeks', 'Ships from China', 21);

  const StockStatus(this.label, this.detail, this.etaDays);
  final String label;
  final String detail;

  /// Worst-case days until the customer has it (admin-configurable later).
  final int etaDays;

  DateTime arrivalFrom(DateTime orderedAt) => orderedAt.add(Duration(days: etaDays));
}

class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final IconData icon;
}

class VariantGroup {
  const VariantGroup(this.name, this.options);

  final String name;
  final List<String> options;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.price,
    this.oldPrice,
    required this.stockStatus,
    required this.thumbnail,
    required this.images,
    required this.description,
    this.variantGroups = const [],
    this.rating = 0,
    this.soldCount = 0,
    this.isNew = false,
    this.saleEndsAt,
    this.photoBgs = const [],
  });

  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final double price;
  final double? oldPrice;
  final StockStatus stockStatus;
  final String thumbnail;
  final List<String> images;
  final String description;
  final List<VariantGroup> variantGroups;
  final double rating;
  final int soldCount;
  final bool isNew;

  /// When a flash sale ends (set by the admin); null for an open-ended sale.
  final DateTime? saleEndsAt;

  /// What to show behind each photo (parallel to [images]), set by the admin
  /// — usually matching the photo's own background, so a white-background
  /// photo sits on white instead of showing as a white box on the tint. Null
  /// (or missing) means the usual tint; see `productBackdrop` in common.dart.
  final List<PhotoBg?> photoBgs;

  PhotoBg? photoBg(int i) => i < photoBgs.length ? photoBgs[i] : null;

  /// Flash sale still running — drives the countdown.
  bool get flashSaleActive => onSale && saleEndsAt != null && saleEndsAt!.isAfter(DateTime.now());

  bool get onSale => oldPrice != null && oldPrice! > price;
  int get discountPercent => onSale ? ((1 - price / oldPrice!) * 100).round() : 0;
}

class CartItem {
  const CartItem({required this.product, required this.options, required this.quantity});

  final Product product;
  final Map<String, String> options;
  final int quantity;

  String get key => '${product.id}|${options.entries.map((e) => '${e.key}=${e.value}').join(',')}';
  double get total => product.price * quantity;
  String get optionsLabel => options.values.join(' · ');

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, options: options, quantity: quantity ?? this.quantity);
}

class DeliveryArea {
  const DeliveryArea({required this.id, required this.name, required this.fee, required this.eta});

  final String id;
  final String name;
  final double fee;
  final String eta;
}

enum PaymentMethod {
  ecocash('EcoCash', 'Pay with your EcoCash wallet', true, 'assets/payments/ecocash.png'),
  onemoney('OneMoney', 'Pay with your OneMoney wallet', true, 'assets/payments/onemoney.png'),
  innbucks('InnBucks', 'Pay with an InnBucks code', false, 'assets/payments/innbucks.png'),
  card('Card', 'Visa, Mastercard or ZimSwitch', false, 'assets/payments/zimswitch.png'),

  /// The customer sends the money themselves (EcoCash, InnBucks or bank
  /// transfer to the accounts in `meta/paymentDetails`) and types in the
  /// transaction reference; the admin matches it against their statement and
  /// confirms. No gateway involved — see lib/widgets/manual_payment.dart.
  manual('Pay manually', 'Send via EcoCash, InnBucks or bank, then enter the reference', false, null);

  const PaymentMethod(this.label, this._subtitle, this._needsPhone, this.logo);
  final String label;
  final String _subtitle;
  final bool _needsPhone;

  /// Brand logo shown on a white tile (stays white in dark mode so logos read).
  /// Null for [manual], which shows an icon instead.
  final String? logo;

  /// Whether Paynow's integration ID is live. While false (Oct 2026: the
  /// merchant account is live but the integration is still in test mode, so
  /// real wallets can't be charged through it), nothing goes through Paynow:
  /// - EcoCash dials the EcoCash "Send money" USSD code to the client's number
  ///   with the order total, so the customer only enters their PIN;
  /// - InnBucks shows the client's InnBucks number and the amount to send
  ///   (InnBucks has no one-shot USSD code);
  /// - Card is hidden (it can only work through Paynow);
  /// and the customer then enters the SMS reference for the admin to confirm
  /// (lib/widgets/manual_payment.dart). Set to true once Paynow sets the
  /// integration live to go back to Paynow for EcoCash, InnBucks and Card.
  static const paynowLive = false;

  /// Card is inactive on the merchant account until Paynow activates
  /// Visa/Mastercard — it only shows once [paynowLive] too.
  static const cardEnabled = true;

  /// The manual channel this method pays through when it isn't [viaPaynow].
  ManualChannel? get manualChannel => switch (this) {
    PaymentMethod.ecocash when !paynowLive => ManualChannel.ecocash,
    PaymentMethod.innbucks when !paynowLive => ManualChannel.innbucks,
    PaymentMethod.manual when !paynowLive => ManualChannel.bank,
    _ => null,
  };

  /// EcoCash without Paynow: the app runs the USSD code for the customer.
  bool get dialsUssd => manualChannel == ManualChannel.ecocash;

  String get subtitle => switch (this) {
    PaymentMethod.ecocash when !paynowLive => 'Opens EcoCash. Just enter your PIN to confirm',
    PaymentMethod.innbucks when !paynowLive => 'Send from InnBucks, then enter the reference',
    PaymentMethod.manual when !paynowLive => 'Bank transfer or ZIPIT, then enter the reference',
    _ => _subtitle,
  };

  /// Paynow's Express Checkout needs the wallet number; manual payment doesn't.
  bool get needsPhone => _needsPhone && viaPaynow;

  /// Whether this method goes through Paynow (and so the payments Worker).
  bool get viaPaynow => this != PaymentMethod.manual && paynowLive;

  /// Methods offered in the checkout / retry pickers. OneMoney has no account
  /// configured on the Paynow side.
  bool get selectable => switch (this) {
    PaymentMethod.onemoney => false,
    PaymentMethod.card => cardEnabled && paynowLive,
    _ => true,
  };
  static List<PaymentMethod> get selectableValues => [
    for (final m in values)
      if (m.selectable) m,
  ];
}

enum OrderStatus {
  placed('Order placed', IconlyLight.paper),
  paid('Payment confirmed', IconlyLight.wallet),
  processing('Processing', IconlyLight.bag_2),
  boughtInChina('Bought in China', IconlyLight.bag, chinaLeg: true),
  inTransit('Flying to Zimbabwe', IconlyBold.send, chinaLeg: true),
  arrivedZim('Arrived in Harare', IconlyLight.location, chinaLeg: true),
  outForDelivery('Out for delivery', Icons.local_shipping_outlined),
  delivered('Delivered', IconlyLight.tick_square);

  const OrderStatus(this.label, this.icon, {this.chinaLeg = false});
  final String label;
  final IconData icon;

  /// Steps that only apply when the order has items coming from China.
  final bool chinaLeg;
}

/// Where a manual payment was sent (see [PaymentMethod.manual]).
enum ManualChannel {
  ecocash('EcoCash', 'The reference in your EcoCash SMS, e.g. MP231005.1423.H12345'),
  innbucks('InnBucks', 'The transaction ID from the InnBucks app or SMS'),
  bank('Bank transfer', "The bank's transaction or reference number");

  const ManualChannel(this.label, this.referenceHint);
  final String label;
  final String referenceHint;
}

enum ManualPaymentStatus { submitted, confirmed, rejected }

/// The customer's own report of a manual payment, stored on the order doc as
/// `manualPayment`. The customer writes it as `submitted`; only the admin
/// moves it to `confirmed` (together with a `paid` status event) or
/// `rejected` (with a [note] saying why) — see firestore.rules.
class ManualPayment {
  const ManualPayment({
    required this.channel,
    required this.reference,
    required this.submittedAt,
    this.sender,
    this.status = ManualPaymentStatus.submitted,
    this.note,
  });

  final ManualChannel channel;

  /// Transaction reference the admin matches against their statement.
  final String reference;

  /// Number or account name the money came from, to help the match.
  final String? sender;
  final DateTime submittedAt;
  final ManualPaymentStatus status;

  /// Admin's reason when [status] is rejected.
  final String? note;
}

/// The client's own accounts customers pay into manually (Firestore
/// `meta/paymentDetails`, edited on the admin panel's Payment details
/// screen). Blank fields mean that channel isn't offered.
class PaymentDetails {
  const PaymentDetails({
    this.ecocashNumber = '',
    this.ecocashName = '',
    this.innbucksNumber = '',
    this.innbucksName = '',
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankBranch = '',
    this.instructions = '',
    this.ecocashUssd = '',
  });

  factory PaymentDetails.fromMap(Map<String, dynamic> m) {
    String s(String key) => (m[key] as String? ?? '').trim();
    return PaymentDetails(
      ecocashNumber: s('ecocashNumber'),
      ecocashName: s('ecocashName'),
      innbucksNumber: s('innbucksNumber'),
      innbucksName: s('innbucksName'),
      bankName: s('bankName'),
      bankAccountName: s('bankAccountName'),
      bankAccountNumber: s('bankAccountNumber'),
      bankBranch: s('bankBranch'),
      instructions: s('instructions'),
      ecocashUssd: s('ecocashUssd'),
    );
  }

  final String ecocashNumber;
  final String ecocashName;
  final String innbucksNumber;
  final String innbucksName;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankBranch;

  /// Extra free text from the admin, shown above the accounts.
  final String instructions;

  /// USSD template the app dials for EcoCash, with {number} and {amount}
  /// placeholders. Blank = [defaultEcocashUssd] (EcoCash USD "Send money").
  final String ecocashUssd;

  static const defaultEcocashUssd = '*153*1*1*{number}*{amount}#';

  /// The full code to dial to send [amount] to the client's EcoCash, e.g.
  /// `*153*1*1*0771234567*25#`. Whole amounts drop the ".00".
  String ecocashUssdFor(double amount) {
    final amountText = amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return (ecocashUssd.isEmpty ? defaultEcocashUssd : ecocashUssd)
        .replaceAll('{number}', ecocashNumber.replaceAll(RegExp(r'[\s-]'), ''))
        .replaceAll('{amount}', amountText);
  }

  List<ManualChannel> get channels => [
    if (ecocashNumber.isNotEmpty) ManualChannel.ecocash,
    if (innbucksNumber.isNotEmpty) ManualChannel.innbucks,
    if (bankAccountNumber.isNotEmpty) ManualChannel.bank,
  ];

  /// (label, value) rows to show for [channel]; empty values are skipped.
  List<(String, String)> linesFor(ManualChannel channel) => [
    for (final (label, value) in switch (channel) {
      ManualChannel.ecocash => [('EcoCash number', ecocashNumber), ('Name', ecocashName)],
      ManualChannel.innbucks => [('InnBucks number', innbucksNumber), ('Name', innbucksName)],
      ManualChannel.bank => [
        ('Bank', bankName),
        ('Account name', bankAccountName),
        ('Account number', bankAccountNumber),
        ('Branch', bankBranch),
      ],
    })
      if (value.isNotEmpty) (label, value),
  ];
}

class StatusEvent {
  const StatusEvent(this.status, this.at, [this.note]);

  final OrderStatus status;
  final DateTime at;
  final String? note;
}

class Address {
  const Address({required this.fullName, required this.phone, required this.street, required this.city});

  final String fullName;
  final String phone;
  final String street;
  final String city;

  String get oneLine => '$street, $city';
}

/// One of a signed-in customer's saved delivery addresses (Firestore
/// `users/{uid}/addresses`). [Address] itself stays a plain value type used
/// everywhere (including inside an [Order], where it's a snapshot, not a
/// reference) — this wrapper only exists where the address book's own
/// identity (which doc to edit/delete, which one is default) matters.
class SavedAddress {
  const SavedAddress({required this.id, required this.label, required this.address, this.isDefault = false});

  final String id;

  /// A short name the customer gave it, e.g. "Home", "Work".
  final String label;
  final Address address;
  final bool isDefault;

  SavedAddress copyWith({String? label, Address? address, bool? isDefault}) => SavedAddress(
    id: id,
    label: label ?? this.label,
    address: address ?? this.address,
    isDefault: isDefault ?? this.isDefault,
  );
}

class Order {
  const Order({
    required this.id,
    required this.docId,
    required this.items,
    required this.address,
    required this.area,
    required this.payment,
    required this.history,
    this.couponCode,
    this.discount = 0,
    this.manualPayment,
  });

  /// Promo code applied at checkout and the amount it took off the
  /// subtotal (delivery is never discounted).
  final String? couponCode;
  final double discount;

  /// The customer's reported manual payment, if they paid that way.
  final ManualPayment? manualPayment;

  /// A manual payment reference is in and the admin hasn't checked it yet.
  bool get awaitingManualCheck =>
      status == OrderStatus.placed && manualPayment?.status == ManualPaymentStatus.submitted;

  Order withHistory(List<StatusEvent> history) => _copy(history: history);

  Order withManualPayment(ManualPayment manualPayment) =>
      _copy(payment: PaymentMethod.manual, manualPayment: manualPayment);

  Order _copy({List<StatusEvent>? history, PaymentMethod? payment, ManualPayment? manualPayment}) => Order(
    id: id,
    docId: docId,
    items: items,
    address: address,
    area: area,
    payment: payment ?? this.payment,
    history: history ?? this.history,
    couponCode: couponCode,
    discount: discount,
    manualPayment: manualPayment ?? this.manualPayment,
  );

  /// Human-friendly "DL#####" id, shown in the UI and used in routes.
  final String id;

  /// The underlying Firestore document id (a different, opaque string) —
  /// needed anywhere we talk to Firestore or the payments Worker directly
  /// by document path (see lib/widgets/payment_dialog.dart), since Firestore
  /// doesn't know about [id]. For mock orders (never backed by real
  /// Firestore) this is just a copy of [id].
  final String docId;

  final List<CartItem> items;
  final Address address;
  final DeliveryArea area;
  final PaymentMethod payment;
  final List<StatusEvent> history;

  OrderStatus get status => history.last.status;
  DateTime get createdAt => history.first.at;
  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  double get total => subtotal - discount + area.fee;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  bool get hasChinaItems => items.any((i) => i.product.stockStatus == StockStatus.preorder);

  /// The steps this order goes through (China legs only if needed).
  List<OrderStatus> get journey => [
    for (final s in OrderStatus.values)
      if (!s.chinaLeg || hasChinaItems) s,
  ];
}

/// A promo code (Firestore `coupons/{CODE}`, managed in the admin panel).
/// The payments Worker re-validates and recomputes the discount itself —
/// this class only drives what checkout *shows*.
class Coupon {
  const Coupon({
    required this.code,
    this.percentOff,
    this.amountOff,
    this.minSubtotal,
    this.firstOrderOnly = false,
    this.expiresAt,
  });

  final String code;
  final double? percentOff;
  final double? amountOff;
  final double? minSubtotal;
  final bool firstOrderOnly;
  final DateTime? expiresAt;

  String get label =>
      percentOff != null ? '${percentOff!.toStringAsFixed(0)}% off' : '\$${(amountOff ?? 0).toStringAsFixed(2)} off';

  double discountFor(double subtotal) {
    final raw = percentOff != null ? subtotal * percentOff! / 100 : (amountOff ?? 0);
    return raw.clamp(0, subtotal).toDouble();
  }
}

class AppUser {
  const AppUser({required this.uid, required this.name, required this.phone, this.email, this.photoUrl});

  /// Firebase Auth uid — scopes Firestore data (e.g. orders) to this user.
  final String uid;
  final String name;
  final String phone;
  final String? email;

  /// Profile photo from the sign-in provider (Google/Facebook) — null for
  /// email/password accounts, or any provider that didn't supply one.
  final String? photoUrl;
}

/// A photo's background, one entry of a product's `photoBgs` — stored as a
/// string by the admin panel (admin/lib/photos.dart `PhotoBg`, kept in sync
/// by hand): `#rrggbb` (flat); `linear:#from,#to` (top-to-bottom fade) or
/// `linear@right|down-right|down-left:#from,#to`; or `radial:#centre,#edge`
/// (vignette: lighter middle, darker corners).
class PhotoBg {
  const PhotoBg({this.color, this.gradient});

  final Color? color;
  final Gradient? gradient;

  static Color _hex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  /// Null for anything unrecognised, so the app falls back to the tint.
  static PhotoBg? parse(Object? value) {
    if (value is! String) return null;
    final v = value.trim().toLowerCase();
    if (RegExp(r'^#[0-9a-f]{6}$').hasMatch(v)) return PhotoBg(color: _hex(v));
    final m = RegExp(r'^(linear(?:@([a-z-]+))?|radial):(#[0-9a-f]{6}),(#[0-9a-f]{6})$').firstMatch(v);
    if (m == null) return null;
    final colors = [_hex(m[3]!), _hex(m[4]!)];
    if (m[1] == 'radial') return PhotoBg(gradient: RadialGradient(radius: 0.9, colors: colors));
    final (begin, end) = switch (m[2]) {
      null || 'down' => (Alignment.topCenter, Alignment.bottomCenter),
      'right' => (Alignment.centerLeft, Alignment.centerRight),
      'down-right' => (Alignment.topLeft, Alignment.bottomRight),
      'down-left' => (Alignment.topRight, Alignment.bottomLeft),
      _ => (null, null),
    };
    if (begin == null || end == null) return null;
    return PhotoBg(
      gradient: LinearGradient(begin: begin, end: end, colors: colors),
    );
  }
}
