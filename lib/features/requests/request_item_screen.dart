import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contact.dart';
import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

/// "Request an item": paste a SHEIN/Temu/Alibaba link (or describe what you
/// want) and Dellinoo replies with a quote. Stored in Firestore
/// `item_requests` (see firestore.rules); the admin panel's Requests screen
/// answers them — keep field names in sync with admin/lib/requests_screen.dart.
class RequestItemScreen extends ConsumerStatefulWidget {
  const RequestItemScreen({super.key});

  @override
  ConsumerState<RequestItemScreen> createState() => _RequestItemScreenState();
}

class _RequestItemScreenState extends ConsumerState<RequestItemScreen> {
  final _link = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider);
    final link = _link.text.trim();
    if (user == null) return;
    if (link.isEmpty) {
      showGlassToast(context, 'Paste a link or describe the item');
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('item_requests').add({
        'userId': user.uid,
        'customerName': user.name,
        'customerEmail': user.email ?? '',
        'customerPhone': user.phone,
        'link': link,
        'note': _note.text.trim(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _link.clear();
      _note.clear();
      if (mounted) showGlassToast(context, "Request sent — we'll send you a quote soon");
    } catch (_) {
      if (mounted) showGlassToast(context, "Couldn't send your request. Please try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider)?.uid;
    return Scaffold(
      appBar: const PageHeader(title: 'Request an item'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            "Can't find it in the shop? Send us a link from SHEIN, Temu, Alibaba or anywhere else and we'll quote you a "
            'price delivered to Zimbabwe.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Product link or name', prefixIcon: Icon(Icons.link)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Size, colour, quantity… (optional)'),
                ),
                const SizedBox(height: 16),
                GradientButton(onPressed: _sending ? null : _submit, child: const Text('Send request')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Your requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          if (uid != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // No orderBy: that would need a composite index; sorted below instead.
              stream: FirebaseFirestore.instance
                  .collection('item_requests')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = [...?snapshot.data?.docs]
                  ..sort((a, b) {
                    final at = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final bt = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return bt.compareTo(at);
                  });
                if (docs.isEmpty) {
                  return Text('Nothing requested yet.', style: TextStyle(color: AppColors.muted));
                }
                return Column(children: [for (final d in docs) _RequestTile(d.data())]);
              },
            ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'new';
    final price = (data['quotePrice'] as num?)?.toDouble();
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final quoted = status == 'quoted' && price != null;
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['link'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                switch (status) {
                  'quoted' => 'Quoted',
                  'closed' => 'Closed',
                  _ => 'Waiting',
                },
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: quoted ? AppColors.inStock : AppColors.muted,
                ),
              ),
            ],
          ),
          if (created != null) Text(shortDate(created), style: TextStyle(color: AppColors.muted, fontSize: 12)),
          if (quoted) ...[
            const SizedBox(height: 10),
            Text(
              'Our quote: ${money(price)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),
            ),
            if ((data['quoteNote'] as String?)?.isNotEmpty ?? false)
              Text(data['quoteNote'] as String, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openWhatsApp('Hi Dellinoo, I accept your ${money(price)} quote for: ${data['link']}'),
              icon: const Icon(IconlyLight.chat, size: 18),
              label: const Text('Accept on WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }
}
