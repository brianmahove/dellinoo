import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contact.dart';
import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

/// "Request an invoice" on an order, plus the invoice number once the admin
/// issues one.
///
/// Stored in Firestore `invoice_requests` / `invoices` (see
/// `firestore.rules`) — the admin panel's Invoices screen answers them, so
/// keep field names in sync with `admin/lib/invoices_screen.dart`.
///
/// The PDF itself is built in the admin panel and sent over (WhatsApp/email):
/// there's no Storage bucket on the Spark plan to put a file in, so the app
/// shows the invoice number and details rather than a download.
class InvoiceSection extends ConsumerWidget {
  const InvoiceSection(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider)?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Issued invoices first: once one exists, the request that asked for it
    // (if any) doesn't matter any more.
    return _Stream(
      collection: 'invoices',
      uid: uid,
      orderDocId: order.docId,
      builder: (context, invoice) {
        if (invoice != null) {
          return _Card(
            child: _Issued(order: order, invoice: invoice),
          );
        }
        return _Stream(
          collection: 'invoice_requests',
          uid: uid,
          orderDocId: order.docId,
          builder: (context, request) => _Card(
            child: request == null ? _RequestPrompt(order) : _Pending(request: request, order: order),
          ),
        );
      },
    );
  }
}

/// The customer's own doc for this order in [collection], or null.
///
/// No `orderBy`: two equality filters need no composite index, an ordered
/// query would (same reasoning as the requests list in
/// `request_item_screen.dart`). There is only ever one document that
/// matters here anyway — the newest, picked below.
class _Stream extends StatelessWidget {
  const _Stream({required this.collection, required this.uid, required this.orderDocId, required this.builder});

  final String collection;
  final String uid;
  final String orderDocId;
  final Widget Function(BuildContext, Map<String, dynamic>?) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .where('orderDocId', isEqualTo: orderDocId)
          .snapshots(),
      builder: (context, snapshot) {
        // Nothing until the first snapshot arrives, so the card can't flash
        // "Request an invoice" at someone who already has one.
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] ?? a.data()['issuedAt']) as Timestamp?;
            final bt = (b.data()['createdAt'] ?? b.data()['issuedAt']) as Timestamp?;
            return (bt?.toDate() ?? DateTime(0)).compareTo(at?.toDate() ?? DateTime(0));
          });
        return builder(context, docs.firstOrNull?.data());
      },
    );
  }
}

class _RequestPrompt extends StatelessWidget {
  const _RequestPrompt(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Invoice'),
        const SizedBox(height: 6),
        Text(
          'Need a receipt for your records, your employer or a company purchase? '
          "We'll prepare one for this order.",
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => requestInvoice(context, order),
          icon: const Icon(IconlyLight.document, size: 18),
          label: const Text('Request an invoice'),
        ),
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({required this.request, required this.order});

  final Map<String, dynamic> request;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final at = (request['createdAt'] as Timestamp?)?.toDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const _Title('Invoice'), const Spacer(), _Pill('Requested', AppColors.accentOrange)]),
        const SizedBox(height: 6),
        Text(
          at == null
              ? "We're preparing your invoice."
              : "Requested ${dateTime(at)} — we're preparing it and will send it to you.",
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openWhatsApp('Hi Dellinoo, any news on the invoice for my order #${order.id}?'),
          icon: const Icon(IconlyLight.chat, size: 18),
          label: const Text('Follow up on WhatsApp'),
        ),
      ],
    );
  }
}

class _Issued extends StatelessWidget {
  const _Issued({required this.order, required this.invoice});

  final Order order;
  final Map<String, dynamic> invoice;

  @override
  Widget build(BuildContext context) {
    final number = invoice['number'] as String? ?? '';
    final issued = (invoice['issuedAt'] as Timestamp?)?.toDate();
    final billTo = Map<String, dynamic>.from(invoice['billTo'] as Map? ?? const {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const _Title('Invoice'), const Spacer(), _Pill(number, AppColors.primary)]),
        const SizedBox(height: 10),
        if ((billTo['name'] as String?)?.isNotEmpty ?? false)
          Text('Billed to ${billTo['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (issued != null)
          Text('Issued ${dateTime(issued)}', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        Text(
          'Total ${money((invoice['total'] as num?)?.toDouble() ?? order.total)}',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openWhatsApp('Hi Dellinoo, please send me a copy of invoice $number (order #${order.id}).'),
          icon: const Icon(IconlyLight.download, size: 18),
          label: const Text('Get a copy on WhatsApp'),
        ),
      ],
    );
  }
}

/// Asks for the billing details, then writes the request. Kept public so the
/// order-success screen could offer it too.
Future<void> requestInvoice(BuildContext context, Order order) {
  return showGlassBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RequestSheet(order),
  );
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet(this.order);

  final Order order;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  late final _name = TextEditingController(text: widget.order.address.fullName);
  late final _address = TextEditingController(text: widget.order.address.oneLine);
  final _tax = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _tax.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    if (_name.text.trim().isEmpty) {
      showGlassToast(context, 'Who should the invoice be made out to?');
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('invoice_requests').add({
        'userId': user.uid,
        'orderDocId': widget.order.docId,
        'orderId': widget.order.id,
        'customerName': user.name,
        'customerEmail': user.email ?? '',
        'customerPhone': user.phone,
        'billTo': {'name': _name.text.trim(), 'address': _address.text.trim(), 'taxNumber': _tax.text.trim()},
        'note': _note.text.trim(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showGlassToast(context, "Invoice requested — we'll send it to you shortly");
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showGlassToast(context, "Couldn't send your request. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice for order #${widget.order.id}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us who the invoice is for. Leave the extras blank if this is just for you.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Bill to (your name or company)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tax,
            decoration: const InputDecoration(labelText: 'TIN / BP number (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Anything else? (optional)'),
          ),
          const SizedBox(height: 18),
          GradientButton(
            onPressed: _sending ? null : _submit,
            icon: IconlyLight.document,
            child: Text(_sending ? 'Sending…' : 'Request invoice'),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

/// Same card styling as the order detail screen's own sections.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
    child: child,
  );
}
