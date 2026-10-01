import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass_dialog.dart';
import 'invoice_pdf.dart';
import 'theme.dart';
import 'iconly.dart';

/// Invoices: the requests customers send from the app (`invoice_requests`,
/// written by lib/features/orders/invoice.dart) and the invoices issued
/// against them (`invoices`).
///
/// An invoice is a *snapshot*: issuing one copies the order's lines and
/// totals onto the invoice doc, so editing a product's price later can
/// never change a document the customer already has. The PDF itself is
/// built in the browser on demand (invoice_pdf.dart) — nothing is stored,
/// since there's no Storage bucket on the Spark plan.
///
/// Field names mirror the customer app by hand, same as the rest of admin/.
const _statuses = {'new': 'New', 'issued': 'Issued', 'closed': 'Closed'};

/// First invoice number, if `meta/invoiceCounter` doesn't exist yet.
const _firstInvoiceNumber = 1;

final _dateTime = DateFormat.yMMMd().add_jm();

String _invoiceNumber(int n) => 'INV-${n.toString().padLeft(5, '0')}';

/// The single place that allocates a number and writes an invoice, used both
/// from a customer's request and from the Orders screen (where the admin can
/// invoice an order nobody asked about).
///
/// The counter bump and the invoice write share one transaction so two
/// admins issuing at the same moment can't land on the same number.
Future<String?> issueInvoice({required BuildContext context, required String orderDocId, String? requestId}) async {
  final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderDocId);
  final orderSnap = await orderRef.get();
  final order = orderSnap.data();
  if (!context.mounted) return null;
  if (order == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That order no longer exists')));
    return null;
  }

  // An order already invoiced is the common accident (two admins, or a
  // customer asking twice) — issuing a second number for the same money is
  // exactly what accounting doesn't want, so make it a deliberate choice.
  final existing = await FirebaseFirestore.instance
      .collection('invoices')
      .where('orderDocId', isEqualTo: orderDocId)
      .limit(1)
      .get();
  if (!context.mounted) return null;

  return showFormPage<String>(
    context: context,
    builder: (context) =>
        _IssueDialog(orderDocId: orderDocId, order: order, requestId: requestId, existing: existing.docs.firstOrNull),
  );
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _showIssued = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Requests'),
                      icon: Icon(IconlyLight.paper_download, size: 18),
                    ),
                    ButtonSegment(value: true, label: Text('Issued'), icon: Icon(IconlyLight.document, size: 18)),
                  ],
                  selected: {_showIssued},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _showIssued = s.first),
                ),
              ),
              Expanded(child: _showIssued ? const _IssuedList() : const _RequestList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.message);

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('invoice_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const _Empty(IconlyLight.paper_download, 'No invoice requests yet');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _RequestCard(docs[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.doc);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final status = d['status'] as String? ?? 'new';
    final created = (d['createdAt'] as Timestamp?)?.toDate();
    final billTo = Map<String, dynamic>.from(d['billTo'] as Map? ?? const {});
    final number = d['invoiceNumber'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d['orderId'] ?? ''}  ·  ${d['customerName'] ?? 'Customer'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statuses.containsKey(status) ? status : 'new',
                    items: [for (final e in _statuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => doc.reference.update({'status': v}),
                  ),
                ),
              ],
            ),
            if (created != null)
              Text(
                'Requested ${_dateTime.format(created.toLocal())}',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            const SizedBox(height: 10),
            Text('Bill to: ${billTo['name'] ?? d['customerName'] ?? ''}'),
            if ((billTo['address'] as String?)?.isNotEmpty ?? false) Text('${billTo['address']}'),
            if ((billTo['taxNumber'] as String?)?.isNotEmpty ?? false) Text('TIN / BP: ${billTo['taxNumber']}'),
            if ((d['note'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text('"${d['note']}"', style: TextStyle(color: AppColors.muted)),
            ],
            const Divider(height: 28),
            Row(
              children: [
                if (number != null)
                  Expanded(
                    child: Text(
                      'Issued as $number',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  )
                else
                  const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                  onPressed: () =>
                      issueInvoice(context: context, orderDocId: d['orderDocId'] as String? ?? '', requestId: doc.id),
                  icon: const Icon(IconlyLight.document, size: 18),
                  label: Text(number == null ? 'Issue invoice' : 'Issue again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssuedList extends StatelessWidget {
  const _IssuedList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('invoices').orderBy('issuedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const _Empty(IconlyLight.document, 'No invoices issued yet');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => InvoiceCard(docs[i].data()),
        );
      },
    );
  }
}

/// One issued invoice, with the print/download actions. Also used on the
/// Orders screen once an order has been invoiced.
class InvoiceCard extends StatelessWidget {
  const InvoiceCard(this.invoice, {super.key});

  final Map<String, dynamic> invoice;

  @override
  Widget build(BuildContext context) {
    final issued = (invoice['issuedAt'] as Timestamp?)?.toDate();
    final paid = invoice['paid'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${invoice['number']}  ·  ${invoice['orderId'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(
                  label: paid ? 'Paid' : 'Unpaid',
                  color: paid ? AppColors.inStock : AppColors.preorder,
                  background: paid ? AppColors.inStockSoft : AppColors.preorderSoft,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${(invoice['billTo'] as Map?)?['name'] ?? invoice['customerName'] ?? ''}',
                money(invoice['total'] as num?),
                if (issued != null) _dateTime.format(issued.toLocal()),
              ].join('  ·  '),
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
                  onPressed: () => printInvoice(invoice),
                  icon: const Icon(IconlyLight.paper, size: 18),
                  label: const Text('Print'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                  onPressed: () => downloadInvoice(invoice),
                  icon: const Icon(IconlyLight.download, size: 18),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog({required this.orderDocId, required this.order, this.requestId, this.existing});

  final String orderDocId;
  final Map<String, dynamic> order;
  final String? requestId;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  late final Map<String, dynamic>? _address = widget.order['address'] as Map<String, dynamic>?;
  late final _name = TextEditingController(text: '${widget.order['customerName'] ?? _address?['fullName'] ?? ''}');
  late final _address2 = TextEditingController(
    text: _address == null ? '' : '${_address['street']}, ${_address['city']}',
  );
  late final _tax = TextEditingController();
  late final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Whatever the customer typed when they asked wins over the defaults
    // above — that's the whole point of the request form.
    final requestId = widget.requestId;
    if (requestId != null) {
      FirebaseFirestore.instance.collection('invoice_requests').doc(requestId).get().then((snap) {
        final billTo = Map<String, dynamic>.from(snap.data()?['billTo'] as Map? ?? const {});
        if (!mounted) return;
        setState(() {
          if ((billTo['name'] as String?)?.isNotEmpty ?? false) _name.text = billTo['name'] as String;
          if ((billTo['address'] as String?)?.isNotEmpty ?? false) _address2.text = billTo['address'] as String;
          if ((billTo['taxNumber'] as String?)?.isNotEmpty ?? false) _tax.text = billTo['taxNumber'] as String;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address2.dispose();
    _tax.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Grabbed before the dialog pops — afterwards this State's context is
    // gone and can't look up the messenger any more.
    final messenger = ScaffoldMessenger.of(context);
    final db = FirebaseFirestore.instance;
    final order = widget.order;
    final items = List<Map<String, dynamic>>.from(order['items'] as List? ?? const []);
    final history = List<Map<String, dynamic>>.from(order['history'] as List? ?? const []);
    final subtotal = items.fold<double>(
      0,
      (s, i) => s + ((i['price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toInt() ?? 0),
    );
    final coupon = order['coupon'] as Map<String, dynamic>?;
    final discount = (coupon?['discount'] as num?)?.toDouble() ?? 0;
    final fee = ((order['area'] as Map?)?['fee'] as num?)?.toDouble() ?? 0;

    final invoiceRef = db.collection('invoices').doc();
    final counterRef = db.collection('meta').doc('invoiceCounter');

    try {
      final number = await db.runTransaction<String>((tx) async {
        final counter = await tx.get(counterRef);
        final next = (counter.data()?['next'] as int?) ?? _firstInvoiceNumber;
        final number = _invoiceNumber(next);
        // set-with-merge, not update: works whether or not the doc exists yet.
        tx.set(counterRef, {'next': next + 1}, SetOptions(merge: true));
        tx.set(invoiceRef, {
          'number': number,
          'orderDocId': widget.orderDocId,
          'orderId': order['displayId'] ?? widget.orderDocId,
          'userId': order['userId'],
          'customerName': order['customerName'] ?? _address?['fullName'] ?? '',
          'customerEmail': order['customerEmail'] ?? '',
          'customerPhone': _address?['phone'] ?? '',
          'billTo': {'name': _name.text.trim(), 'address': _address2.text.trim(), 'taxNumber': _tax.text.trim()},
          'items': [
            for (final i in items)
              {
                'name': i['name'],
                'options': i['options'] ?? <String, dynamic>{},
                'price': i['price'],
                'quantity': i['quantity'],
              },
          ],
          'subtotal': subtotal,
          'discount': discount,
          if (coupon?['code'] != null) 'couponCode': coupon!['code'],
          'deliveryFee': fee,
          'deliveryArea': (order['area'] as Map?)?['name'] ?? '',
          'total': subtotal - discount + fee,
          'currency': 'USD',
          'payment': order['payment'] ?? '',
          'paid': history.any((h) => h['status'] == 'paid'),
          'orderedAt': order['createdAt'],
          'issuedAt': Timestamp.now(),
          'issuedBy': FirebaseAuth.instance.currentUser?.email ?? '',
          if (widget.requestId != null) 'requestId': widget.requestId,
          'notes': _notes.text.trim(),
        });
        final requestId = widget.requestId;
        if (requestId != null) {
          tx.update(db.collection('invoice_requests').doc(requestId), {
            'status': 'issued',
            'invoiceNumber': number,
            'invoiceId': invoiceRef.id,
            'issuedAt': Timestamp.now(),
          });
        }
        return number;
      });
      if (!mounted) return;
      Navigator.pop(context, number);
      messenger.showSnackBar(SnackBar(content: Text('$number issued')));
      // Straight to the document — issuing it is only useful if you can hand
      // it over, and the panel can't email it (no server).
      final saved = await invoiceRef.get();
      final data = saved.data();
      if (data != null) await downloadInvoice(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't issue invoice: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing?.data();
    return GlassAlertDialog(
      title: Text('Invoice for ${widget.order['displayId'] ?? ''}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              if (existing != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.preorderSoft, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'This order was already invoiced as ${existing['number']}. '
                    'Issuing again creates a second, separately numbered invoice.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.preorder),
                  ),
                ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Bill to (name or company)'),
              ),
              TextField(
                controller: _address2,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: _tax,
                decoration: const InputDecoration(labelText: 'TIN / BP number (optional)'),
              ),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes on the invoice (optional)',
                  hintText: 'e.g. Payment terms, PO number',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Issue & download'),
        ),
      ],
    );
  }
}
