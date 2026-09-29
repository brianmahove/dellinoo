import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

/// Matches OrderStatus in the main app's lib/data/models.dart — kept in sync
/// by hand (see the note in shell.dart about not sharing code yet).
const _statuses = [
  'placed',
  'paid',
  'processing',
  'boughtInChina',
  'inTransit',
  'arrivedZim',
  'outForDelivery',
  'delivered',
];

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

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders'), automaticallyImplyLeading: false),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No orders yet', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OrderTile(docs[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile(this.doc);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final itemCount = items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));
    final subtotal = items.fold<double>(
      0,
      (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
    );
    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;
    final address = d['address'] as Map<String, dynamic>?;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();

    final (color, background) = _statusColors(status);
    return Card(
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${d['displayId'] ?? doc.id}  ·  ${address?['fullName'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            StatusPill(label: _statusLabel(status), color: color, background: background),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (createdAt != null) DateFormat.yMMMd().add_jm().format(createdAt),
              '$itemCount item${itemCount == 1 ? '' : 's'}',
              '\$${(subtotal + fee).toStringAsFixed(2)}',
            ].join('  ·  '),
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${i['quantity']}× ${i['name']}  (\$${i['price']})'),
                  ),
                Divider(color: AppColors.line),
                Text('Deliver to: ${address?['street']}, ${address?['city']} · ${address?['phone']}'),
                Text('Payment: ${d['payment']}'),
                const SizedBox(height: 12),
                Text(
                  'History',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 12.5),
                ),
                for (final h in history)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• ${_statusLabel(h['status'] as String)}  —  ${_fmt(h['at'] as Timestamp?)}'),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _advanceStatus(context, doc, status),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Update status'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Timestamp? t) => t == null ? '' : DateFormat.yMMMd().add_jm().format(t.toDate());

  Future<void> _advanceStatus(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, String current) {
    return showDialog(
      context: context,
      builder: (context) => _StatusDialog(doc: doc, current: current),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.doc, required this.current});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String current;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late String _status = widget.current;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final event = <String, dynamic>{'status': _status, 'at': Timestamp.now()};
    if (_note.text.trim().isNotEmpty) event['note'] = _note.text.trim();
    await widget.doc.reference.update({
      'history': FieldValue.arrayUnion([event]),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update order status'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'New status'),
              items: [for (final s in _statuses) DropdownMenuItem(value: s, child: Text(_statusLabel(s)))],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Driver: Farai · 077…'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }
}
