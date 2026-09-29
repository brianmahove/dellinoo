import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'iconly.dart';

class _Customer {
  _Customer(this.userId);

  final String userId;
  String name = 'Unknown';
  String email = '';
  String phone = '';
  int orders = 0;
  int paidOrders = 0;
  double spent = 0;
  DateTime? firstOrder;
  DateTime? lastOrder;
}

/// There's no client-readable `users` collection (Firebase Auth accounts live
/// outside Firestore), so customers are derived from `orders`, grouped by
/// `userId`: anyone who has placed at least one order. Field names mirror
/// lib/data/firestore_order_repository.dart in the customer app.
List<_Customer> _customersFrom(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final byUser = <String, _Customer>{};
  // Newest first, so the first non-empty value we see per field is the latest.
  for (final doc in docs) {
    final d = doc.data();
    final uid = d['userId'] as String?;
    if (uid == null) continue;
    final c = byUser.putIfAbsent(uid, () => _Customer(uid));
    final address = d['address'] as Map<String, dynamic>?;
    final name = (d['customerName'] as String?)?.trim();
    final fullName = (address?['fullName'] as String?)?.trim();
    if (c.orders == 0) {
      c.name = (name != null && name.isNotEmpty) ? name : (fullName ?? c.name);
      c.email = d['customerEmail'] as String? ?? '';
    }
    if (c.phone.isEmpty) c.phone = address?['phone'] as String? ?? '';

    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final paid = history.any((h) => h['status'] != 'placed');
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final subtotal = items.fold<double>(
      0,
      (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
    );
    final discount = ((d['coupon'] as Map?)?['discount'] as num?)?.toDouble() ?? 0;
    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;

    c.orders++;
    if (paid) {
      c.paidOrders++;
      c.spent += subtotal - discount + fee;
    }
    final at = (d['createdAt'] as Timestamp?)?.toDate();
    if (at != null) {
      if (c.lastOrder == null || at.isAfter(c.lastOrder!)) c.lastOrder = at;
      if (c.firstOrder == null || at.isBefore(c.firstOrder!)) c.firstOrder = at;
    }
  }
  return byUser.values.toList();
}

enum _Sort { spent, orders, recent }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';
  _Sort _sort = _Sort.spent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final all = _customersFrom(snapshot.data!.docs);
          final q = _query.trim().toLowerCase();
          final customers =
              all.where((c) {
                if (q.isEmpty) return true;
                return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q) || c.phone.contains(q);
              }).toList()..sort(
                (a, b) => switch (_sort) {
                  _Sort.spent => b.spent.compareTo(a.spent),
                  _Sort.orders => b.orders.compareTo(a.orders),
                  _Sort.recent => (b.lastOrder ?? DateTime(0)).compareTo(a.lastOrder ?? DateTime(0)),
                },
              );

          final now = DateTime.now();
          final newThisMonth = all
              .where((c) => c.firstOrder != null && c.firstOrder!.year == now.year && c.firstOrder!.month == now.month)
              .length;
          final repeat = all.where((c) => c.paidOrders > 1).length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Chip(IconlyLight.user_1, '${all.length} customers'),
                      _Chip(IconlyLight.add_user, '$newThisMonth new this month'),
                      _Chip(IconlyLight.swap, '$repeat repeat buyers'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Search name, email or phone',
                            prefixIcon: Icon(IconlyLight.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<_Sort>(
                        showSelectedIcon: false,
                        selected: {_sort},
                        onSelectionChanged: (s) => setState(() => _sort = s.first),
                        segments: const [
                          ButtonSegment(value: _Sort.spent, label: Text('Top spend')),
                          ButtonSegment(value: _Sort.orders, label: Text('Orders')),
                          ButtonSegment(value: _Sort.recent, label: Text('Recent')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (customers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          all.isEmpty ? 'No customers yet' : 'No matches',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    for (final c in customers) ...[_CustomerCard(c), const SizedBox(height: 10)],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard(this.c);

  final _Customer c;

  @override
  Widget build(BuildContext context) {
    final initial = c.name.isEmpty ? '?' : c.name.substring(0, 1).toUpperCase();
    final contact = [c.email, c.phone].where((s) => s.isNotEmpty).join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              initial,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ),
                    if (c.paidOrders > 1) ...[
                      const SizedBox(width: 8),
                      StatusPill(label: 'Repeat', color: AppColors.inStock, background: AppColors.inStockSoft),
                    ],
                  ],
                ),
                if (contact.isNotEmpty)
                  SelectableText(contact, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                if (c.lastOrder != null)
                  Text(
                    'Last order ${DateFormat.yMMMd().format(c.lastOrder!)}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: '\$').format(c.spent),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                '${c.orders} order${c.orders == 1 ? '' : 's'}',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
