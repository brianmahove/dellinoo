import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass_dialog.dart';
import 'iconly.dart';
import 'notify.dart';
import 'theme.dart';

/// Push notifications the admin sends by hand: promo broadcasts to every
/// customer with "Deals & offers" on, and an on-demand run of the wishlist
/// price-drop check (which also runs every 6 hours on its own). Order-status
/// pushes aren't here; they go out from the Orders screen automatically.
/// All sending goes through the payments Worker (notify.dart).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: const [
            _BroadcastCard(),
            SizedBox(height: 16),
            _PriceDropCard(),
            SizedBox(height: 24),
            _History(),
          ],
        ),
      ),
    );
  }
}

class _BroadcastCard extends StatefulWidget {
  const _BroadcastCard();

  @override
  State<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends State<_BroadcastCard> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _productId;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Send to all customers?'),
        content: Text(
          'Everyone with "Deals & offers" switched on will get this on their phone:\n\n'
          '${_title.text.trim()}\n${_body.text.trim()}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sendBroadcast(title: _title.text.trim(), body: _body.text.trim(), productId: _productId);
      _title.clear();
      _body.clear();
      setState(() => _productId = null);
      messenger.showSnackBar(const SnackBar(content: Text('Sent')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't send: $e")));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Text('Send a promo', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Goes to every customer who has "Deals & offers" on in the app. Use it sparingly: '
                'too many and people switch it off.',
                style: TextStyle(color: AppColors.muted),
              ),
              TextFormField(
                controller: _title,
                maxLength: 65,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Weekend sale: 20% off sneakers'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _body,
                maxLength: 240,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('products').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  return DropdownButtonFormField<String?>(
                    initialValue: _productId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Opens when tapped'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Home screen')),
                      for (final d in docs)
                        DropdownMenuItem(
                          value: d.id,
                          child: Text('${d.data()['name']}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _productId = v),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(IconlyLight.send),
                  label: const Text('Send to everyone'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceDropCard extends StatefulWidget {
  const _PriceDropCard();

  @override
  State<_PriceDropCard> createState() => _PriceDropCardState();
}

class _PriceDropCardState extends State<_PriceDropCard> {
  bool _running = false;
  String? _result;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final r = await runPriceDropsNow();
      _result = r['productsCut'] == 0
          ? 'No prices were cut since the last check, so nothing to send.'
          : '${r['productsCut']} product(s) got cheaper, saved in ${r['wishlistItems']} wishlist(s). '
                '${r['customersNotified']} customer(s) notified on ${r['devicesReached']} device(s).';
    } catch (e) {
      _result = 'Failed: $e';
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text('Wishlist price drops', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Runs automatically every 6 hours and only looks at products whose price you cut '
              'since the last check. Customers hear about each new low price on something they '
              'saved once. Lower a price on the Products screen, then run it now to tell them '
              'straight away.',
              style: TextStyle(color: AppColors.muted),
            ),
            if (_result != null) Text(_result!),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(IconlyLight.notification),
                label: const Text('Run now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent broadcasts, logged by the Worker after each send.
class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('broadcasts')
          .orderBy('sentAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final docs = snapshot.data?.docs ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text('Sent promos', style: Theme.of(context).textTheme.titleMedium),
            if (snapshot.hasData && docs.isEmpty) Text('Nothing sent yet', style: TextStyle(color: AppColors.muted)),
            for (final doc in docs)
              Card(
                child: ListTile(
                  title: Text('${doc.data()['title']}'),
                  subtitle: Text(
                    '${doc.data()['body']}\n'
                    '${_fmt(doc.data()['sentAt'] as Timestamp?)} · ${doc.data()['sentBy'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }

  static String _fmt(Timestamp? t) => t == null ? '' : DateFormat.yMMMd().add_jm().format(t.toDate());
}
