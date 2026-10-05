import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'notify.dart';
import 'theme.dart';
import 'iconly.dart';

/// "Request an item" submissions from the customer app (`item_requests`):
/// a link/description the customer wants sourced. The admin replies with a
/// quote (price + note), which the customer sees in the app.
///
/// Field names mirror lib/features/requests/ in the customer app — kept in
/// sync by hand, same as the rest of admin/.
const _statuses = {'new': 'New', 'quoted': 'Quoted', 'closed': 'Closed'};

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('item_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconlyLight.discovery, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No requests yet', style: TextStyle(color: AppColors.muted)),
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
                itemBuilder: (context, i) => _RequestCard(docs[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard(this.doc);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late final _price = TextEditingController(text: (widget.doc.data()['quotePrice'] as num?)?.toString() ?? '');
  late final _note = TextEditingController(text: widget.doc.data()['quoteNote'] as String? ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _sendQuote() async {
    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a price first')));
      return;
    }
    setState(() => _saving = true);
    await widget.doc.reference.update({
      'quotePrice': price,
      'quoteNote': _note.text.trim(),
      'status': 'quoted',
      'quotedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = false);
    final outcome = await notifyOutcome('Quote sent', () => notifyItemRequest(widget.doc.id));
    messenger.showSnackBar(SnackBar(content: Text(outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data();
    final status = d['status'] as String? ?? 'new';
    final created = (d['createdAt'] as Timestamp?)?.toDate();
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
                    '${d['customerName'] ?? 'Customer'}  ·  ${d['customerEmail'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statuses.containsKey(status) ? status : 'new',
                    items: [for (final e in _statuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => widget.doc.reference.update({'status': v}),
                  ),
                ),
              ],
            ),
            if (created != null)
              Text(
                created.toLocal().toString().substring(0, 16),
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            const SizedBox(height: 10),
            SelectableText(
              '${d['link'] ?? ''}',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
            if ((d['note'] as String?)?.isNotEmpty ?? false) ...[const SizedBox(height: 6), Text(d['note'] as String)],
            if ((d['customerPhone'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Text('Phone: ${d['customerPhone']}', style: TextStyle(color: AppColors.muted)),
            ],
            const Divider(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Quote (USD)', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 64).clamp(200.0, 320.0),
                  child: TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note to customer (delivery time, etc.)',
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton(
                  // Theme buttons are full-width; a Wrap needs a finite width.
                  style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                  onPressed: _saving ? null : _sendQuote,
                  child: Text(status == 'quoted' ? 'Update quote' : 'Send quote'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
