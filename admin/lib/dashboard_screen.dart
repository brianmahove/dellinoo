import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

/// Matches OrderStatus in the main app's lib/data/models.dart — kept in sync
/// by hand, same as the small copy in orders_screen.dart (see the note in
/// shell.dart about the two apps/screens not sharing code yet).
String _statusLabel(String s) => switch (s) {
  'placed' => 'Order placed',
  'paid' => 'Payment confirmed',
  'processing' => 'Processing',
  'boughtInChina' => 'Bought in China',
  'inTransit' => 'Flying to Zimbabwe',
  'arrivedZim' => 'Arrived in Harare',
  'outForDelivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  _ => s,
};

(Color, Color) _statusColors(String s) => switch (s) {
  'delivered' => (AppColors.inStock, AppColors.inStockSoft),
  'outForDelivery' || 'arrivedZim' => (AppColors.accentOrange, AppColors.preorderSoft),
  'boughtInChina' || 'inTransit' || 'processing' => (AppColors.preorder, AppColors.preorderSoft),
  _ => (AppColors.accent, AppColors.primarySoft),
};

/// At-a-glance counts, no Cloud Functions to precompute them (Spark plan —
/// see the note in CLAUDE.md), so this reads the full `orders`/`products`
/// collections client-side and aggregates in Dart. Fine at this scale;
/// revisit if the catalogue/order history grows large enough to matter.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ColoredBox(
          color: AppColors.tint,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, orderSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                builder: (context, productSnap) {
                  if (orderSnap.hasError || productSnap.hasError) {
                    return Center(child: Text('Error: ${orderSnap.error ?? productSnap.error}'));
                  }
                  if (!orderSnap.hasData || !productSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = orderSnap.data!.docs;
                  final products = productSnap.data!.docs;

                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  var ordersToday = 0;
                  var pendingPayment = 0;
                  var revenue = 0.0;
                  for (final doc in orders) {
                    final d = doc.data();
                    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
                    if (createdAt != null && !createdAt.isBefore(todayStart)) ordersToday++;
                    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
                    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
                    if (status == 'placed') {
                      pendingPayment++;
                      continue;
                    }
                    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
                    final subtotal = items.fold<double>(
                      0,
                      (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
                    );
                    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;
                    revenue += subtotal + fee;
                  }
                  final preorderCount = products.where((d) => d.data()['stockStatus'] == 'preorder').length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: AppColors.ink),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _StatTile(
                              icon: Icons.receipt_long_outlined,
                              label: 'Orders today',
                              value: '$ordersToday',
                              accent: AppColors.primary,
                            ),
                            _StatTile(
                              icon: Icons.hourglass_top_outlined,
                              label: 'Pending payment',
                              value: '$pendingPayment',
                              accent: AppColors.preorder,
                            ),
                            _StatTile(
                              icon: Icons.payments_outlined,
                              label: 'Revenue (paid orders)',
                              value: '\$${revenue.toStringAsFixed(2)}',
                              accent: AppColors.inStock,
                            ),
                            _StatTile(
                              icon: Icons.inventory_2_outlined,
                              label: 'Products',
                              value: '${products.length}',
                              hint: '$preorderCount from China',
                              accent: AppColors.accentOrange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _RecentOrdersCard(docs: orders.take(6).toList()),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.accent, this.hint});

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.docs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent orders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No orders yet', style: TextStyle(color: AppColors.muted)),
              )
            else
              for (final doc in docs) _RecentOrderRow(doc),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow(this.doc);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final subtotal = items.fold<double>(
      0,
      (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
    );
    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;
    final address = d['address'] as Map<String, dynamic>?;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final (color, background) = _statusColors(status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d['displayId'] ?? doc.id}  ·  ${d['customerName'] ?? address?['fullName'] ?? 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
                if (createdAt != null)
                  Text(DateFormat.yMMMd().add_jm().format(createdAt), style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${(subtotal + fee).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 10),
          StatusPill(label: _statusLabel(status), color: color, background: background),
        ],
      ),
    );
  }
}
