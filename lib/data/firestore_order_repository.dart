import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import 'models.dart';
import 'order_repository.dart';

/// Firestore-backed orders (`orders` collection, one doc per order, each
/// with a `userId` field — see `firestore.rules`: a client may only read or
/// create documents where `userId` is their own uid; updates (status
/// changes) are admin/Cloud-Functions-only, not yet built).
///
/// Order line items only ever need `id`/`name`/`thumbnail`/`price`/
/// `stockStatus` on screen (see `orders_screen.dart`/`order_detail_screen.dart`),
/// so that's all that's snapshotted per item — not a live product reference,
/// so the order keeps showing what was actually bought even if the product
/// changes or is removed later. The other `Product` fields are filled with
/// harmless defaults on read so `CartItem`/`Order` stay unchanged.
class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// First auto-generated order number — see `meta/orderCounter` in Firestore.
  static const _firstOrderNumber = 10300;

  @override
  Future<List<Order>> fetchOrders(String uid) async {
    final snapshot = await _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return [for (final doc in snapshot.docs) _orderFromDoc(doc.id, doc.data())];
  }

  @override
  Future<Order> placeOrder({
    required String uid,
    String? customerName,
    String? customerEmail,
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
    Coupon? coupon,
  }) async {
    final now = DateTime.now();
    final orderRef = _db.collection('orders').doc();
    final counterRef = _db.collection('meta').doc('orderCounter');

    final displayId = await _db.runTransaction<String>((tx) async {
      final counterSnap = await tx.get(counterRef);
      final next = (counterSnap.data()?['next'] as int?) ?? _firstOrderNumber;
      final id = 'DL$next';
      // set (not update) with merge: works whether or not the counter doc
      // already exists — firestore.rules still caps this to exactly +1.
      tx.set(counterRef, {'next': next + 1}, SetOptions(merge: true));
      tx.set(
        orderRef,
        _orderToMap(
          displayId: id,
          uid: uid,
          customerName: customerName,
          customerEmail: customerEmail,
          items: items,
          address: address,
          area: area,
          payment: payment,
          coupon: coupon,
          now: now,
        ),
      );
      return id;
    });

    // Unpaid until the payments Worker confirms Paynow's webhook and appends
    // a `paid` StatusEvent itself (see lib/widgets/payment_dialog.dart) —
    // customers can't write order status themselves (firestore.rules).
    return Order(
      id: displayId,
      docId: orderRef.id,
      items: items,
      address: address,
      area: area,
      payment: payment,
      history: [StatusEvent(OrderStatus.placed, now)],
      couponCode: coupon?.code,
      discount: coupon?.discountFor(items.fold(0.0, (acc, i) => acc + i.total)) ?? 0,
    );
  }

  @override
  Future<void> submitManualPayment(String docId, ManualPayment payment) {
    // firestore.rules lets the owner touch only these two fields, only while
    // the order is unpaid, and only as `submitted`.
    return _db.collection('orders').doc(docId).update({
      'payment': PaymentMethod.manual.name,
      'manualPayment': {
        'channel': payment.channel.name,
        'reference': payment.reference,
        if (payment.sender != null && payment.sender!.isNotEmpty) 'sender': payment.sender,
        'status': ManualPaymentStatus.submitted.name,
        'submittedAt': Timestamp.fromDate(payment.submittedAt),
      },
    });
  }

  @override
  Future<PaymentDetails> fetchPaymentDetails() async {
    // Set by the admin on the Payment details screen; nothing is built in.
    final snap = await _db.collection('meta').doc('paymentDetails').get();
    return PaymentDetails.fromMap(snap.data() ?? const {});
  }

  Map<String, dynamic> _orderToMap({
    required String displayId,
    required String uid,
    String? customerName,
    String? customerEmail,
    required List<CartItem> items,
    required Address address,
    required DeliveryArea area,
    required PaymentMethod payment,
    Coupon? coupon,
    required DateTime now,
  }) {
    return {
      'userId': uid,
      'customerName': customerName,
      'customerEmail': customerEmail ?? '',
      'displayId': displayId,
      'createdAt': Timestamp.fromDate(now),
      'items': [
        for (final i in items)
          {
            'productId': i.product.id,
            'name': i.product.name,
            'thumbnail': i.product.thumbnail,
            'price': i.product.price,
            'stockStatus': i.product.stockStatus.name,
            'options': i.options,
            'quantity': i.quantity,
          },
      ],
      'address': {'fullName': address.fullName, 'phone': address.phone, 'street': address.street, 'city': address.city},
      'area': {'id': area.id, 'name': area.name, 'fee': area.fee, 'eta': area.eta},
      'payment': payment.name,
      if (coupon != null)
        'coupon': {'code': coupon.code, 'discount': coupon.discountFor(items.fold(0.0, (acc, i) => acc + i.total))},
      'history': [
        {'status': OrderStatus.placed.name, 'at': Timestamp.fromDate(now)},
      ],
    };
  }

  Order _orderFromDoc(String docId, Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>;
    final area = data['area'] as Map<String, dynamic>;
    final coupon = data['coupon'] as Map<String, dynamic>?;
    return Order(
      id: data['displayId'] as String? ?? 'DL0',
      docId: docId,
      items: [for (final i in (data['items'] as List)) _cartItemFromMap(i as Map<String, dynamic>)],
      address: Address(
        fullName: address['fullName'] as String,
        phone: address['phone'] as String,
        street: address['street'] as String,
        city: address['city'] as String,
      ),
      area: DeliveryArea(
        id: area['id'] as String,
        name: area['name'] as String,
        fee: (area['fee'] as num).toDouble(),
        eta: area['eta'] as String,
      ),
      payment: PaymentMethod.values.byName(data['payment'] as String),
      couponCode: coupon?['code'] as String?,
      discount: (coupon?['discount'] as num?)?.toDouble() ?? 0,
      manualPayment: _manualPaymentFromMap(data['manualPayment'] as Map<String, dynamic>?),
      history: [
        for (final e in (data['history'] as List))
          StatusEvent(
            OrderStatus.values.byName((e as Map<String, dynamic>)['status'] as String),
            (e['at'] as Timestamp).toDate(),
            e['note'] as String?,
          ),
      ],
    );
  }

  ManualPayment? _manualPaymentFromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final channel = ManualChannel.values.asNameMap()[m['channel']];
    final status = ManualPaymentStatus.values.asNameMap()[m['status']];
    if (channel == null || status == null) return null;
    return ManualPayment(
      channel: channel,
      reference: m['reference'] as String? ?? '',
      sender: m['sender'] as String?,
      submittedAt: (m['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: status,
      note: m['note'] as String?,
    );
  }

  CartItem _cartItemFromMap(Map<String, dynamic> m) {
    final product = Product(
      id: m['productId'] as String,
      name: m['name'] as String,
      brand: '',
      categoryId: '',
      price: (m['price'] as num).toDouble(),
      stockStatus: StockStatus.values.byName(m['stockStatus'] as String),
      thumbnail: m['thumbnail'] as String,
      images: [m['thumbnail'] as String],
      description: '',
    );
    return CartItem(
      product: product,
      options: Map<String, String>.from(m['options'] as Map? ?? const {}),
      quantity: (m['quantity'] as num).toInt(),
    );
  }
}
