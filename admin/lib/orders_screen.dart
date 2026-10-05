import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass_dialog.dart';
import 'invoice_pdf.dart';
import 'invoices_screen.dart';
import 'notify.dart';
import 'theme.dart';
import 'iconly.dart';

/// Below this width the split list/detail layout doesn't have room, so
/// Orders falls back to the single-column expandable list (matches the
/// shell's own wide/narrow breakpoint reasoning).
const _splitBreakpoint = 760.0;

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

String _fmtTimestamp(Timestamp? t) => t == null ? '' : DateFormat.yMMMd().add_jm().format(t.toDate());

Future<void> _advanceStatus(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, String current) {
  return showFormPage(
    context: context,
    builder: (context) => _StatusDialog(doc: doc, current: current),
  );
}

int _itemCount(List<Map<String, dynamic>> items) =>
    items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));

double _subtotal(List<Map<String, dynamic>> items) => items.fold<double>(
  0,
  (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Icon(IconlyLight.paper, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No orders yet', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _splitBreakpoint) {
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
              }

              var selected = docs.first;
              for (final d in docs) {
                if (d.id == _selectedId) {
                  selected = d;
                  break;
                }
              }

              return ColoredBox(
                color: AppColors.tint,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _OrderListCard(
                        docs: docs,
                        selectedId: selected.id,
                        onSelect: (id) => setState(() => _selectedId = id),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _OrderDetailCard(doc: selected)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Left panel of the wide layout: a scrollable list of compact, tappable
/// order rows in their own card, separated from the detail card on the right.
class _OrderListCard extends StatelessWidget {
  const _OrderListCard({required this.docs, required this.selectedId, required this.onSelect});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final doc = docs[i];
          return _OrderRow(doc: doc, selected: doc.id == selectedId, onTap: () => onSelect(doc.id));
        },
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.doc, required this.selected, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final itemCount = _itemCount(items);
    final subtotal = _subtotal(items);
    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;
    final address = d['address'] as Map<String, dynamic>?;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final (color, background) = _statusColors(status);

    return Material(
      color: selected ? AppColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d['displayId'] ?? doc.id}  ·  ${d['customerName'] ?? address?['fullName'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (createdAt != null) DateFormat.yMMMd().add_jm().format(createdAt),
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        '\$${(subtotal + fee).toStringAsFixed(2)}',
                      ].join('  ·  '),
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: _statusLabel(status), color: color, background: background),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right panel of the wide layout: full detail for whichever order is
/// selected in the list, in its own separated card.
class _OrderDetailCard extends StatelessWidget {
  const _OrderDetailCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final subtotal = _subtotal(items);
    final fee = ((d['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;
    final address = d['address'] as Map<String, dynamic>?;
    final (color, background) = _statusColors(status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: ValueKey(doc.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d['displayId'] ?? doc.id}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                StatusPill(label: _statusLabel(status), color: color, background: background),
              ],
            ),
            const SizedBox(height: 4),
            Text('${d['customerName'] ?? address?['fullName'] ?? 'Unknown'}', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${i['quantity']}× ${i['name']}  (\$${i['price']})'),
              ),
            Divider(color: AppColors.line, height: 28),
            Text(
              'Deliver to: ${address?['fullName']} · ${address?['street']}, ${address?['city']} · ${address?['phone']}',
            ),
            const SizedBox(height: 4),
            Text('Payment: ${d['payment']}'),
            const SizedBox(height: 4),
            Text('Total: \$${(subtotal + fee).toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            Text(
              'History',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            for (final h in history)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• ${_statusLabel(h['status'] as String)}  —  ${_fmtTimestamp(h['at'] as Timestamp?)}'),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _InvoiceButton(orderDocId: doc.id),
                FilledButton.icon(
                  onPressed: () => _advanceStatus(context, doc, status),
                  icon: const Icon(IconlyLight.arrow_right, size: 18),
                  label: const Text('Update status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrow-layout row: the old expand-in-place tile, kept for mobile web
/// where there isn't room for a side-by-side list and detail panel.
class _OrderTile extends StatelessWidget {
  const _OrderTile(this.doc);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    final status = history.isEmpty ? 'placed' : history.last['status'] as String;
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final itemCount = _itemCount(items);
    final subtotal = _subtotal(items);
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
                // Account name (who's actually signed in and ordering), not the
                // delivery address's recipient name — see "Deliver to" below,
                // which can be someone else (ordering as a gift, etc.).
                '${d['displayId'] ?? doc.id}  ·  ${d['customerName'] ?? address?['fullName'] ?? 'Unknown'}',
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
                Text(
                  'Deliver to: ${address?['fullName']} · ${address?['street']}, ${address?['city']} · ${address?['phone']}',
                ),
                Text('Payment: ${d['payment']}'),
                const SizedBox(height: 12),
                Text(
                  'History',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 12.5),
                ),
                for (final h in history)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• ${_statusLabel(h['status'] as String)}  —  ${_fmtTimestamp(h['at'] as Timestamp?)}'),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _InvoiceButton(orderDocId: doc.id),
                    FilledButton.icon(
                      onPressed: () => _advanceStatus(context, doc, status),
                      icon: const Icon(IconlyLight.arrow_right, size: 18),
                      label: const Text('Update status'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    // The status is saved either way; this only reports whether the
    // customer's phone was pinged.
    try {
      final sent = await notifyOrderStatus(widget.doc.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sent > 0
                ? 'Status saved · customer notified'
                : 'Status saved · customer has no notifications set up on the app',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Status saved, but the customer couldn't be notified: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: const Text('Update order status'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'New status'),
              items: [for (final s in _statuses) DropdownMenuItem(value: s, child: Text(_statusLabel(s)))],
              onChanged: (v) => setState(() => _status = v!),
            ),
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

/// Invoice action for one order: downloads the PDF if the order has already
/// been invoiced, otherwise issues one (see invoices_screen.dart). Lets the
/// admin invoice an order the customer never asked about — a customer's own
/// request shows up on the Invoices screen instead.
class _InvoiceButton extends StatelessWidget {
  const _InvoiceButton({required this.orderDocId});

  final String orderDocId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .where('orderDocId', isEqualTo: orderDocId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final invoice = snapshot.data?.docs.firstOrNull?.data();
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(150, 48)),
          onPressed: invoice == null
              ? () => issueInvoice(context: context, orderDocId: orderDocId)
              : () => runPdfAction(context, () => downloadInvoice(invoice)),
          icon: Icon(invoice == null ? IconlyLight.document : IconlyLight.download, size: 18),
          label: Text(invoice == null ? 'Create invoice' : '${invoice['number']}'),
        );
      },
    );
  }
}
