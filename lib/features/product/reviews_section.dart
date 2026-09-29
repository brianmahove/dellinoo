import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/glass.dart';

/// Customer reviews (Firestore `reviews`, doc id `{productId}_{uid}` so each
/// customer has at most one per product — see firestore.rules). Text and
/// stars only; photos would need Firebase Storage (Blaze plan).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider)?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // No orderBy: it would need a composite index; sorted below instead.
      stream: FirebaseFirestore.instance.collection('reviews').where('productId', isEqualTo: productId).snapshots(),
      builder: (context, snapshot) {
        final reviews = [...?snapshot.data?.docs.map((d) => d.data())]..sort((a, b) => _at(b).compareTo(_at(a)));
        final average = reviews.isEmpty
            ? 0.0
            : reviews.fold<num>(0, (acc, r) => acc + (r['rating'] as num)) / reviews.length;
        final mine = reviews.where((r) => r['userId'] == uid).firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Reviews', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                if (reviews.isNotEmpty) ...[
                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 2),
                  Text(
                    '${average.toStringAsFixed(1)} (${reviews.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => _write(context, ref, mine),
                  child: Text(mine == null ? 'Write a review' : 'Edit yours'),
                ),
              ],
            ),
            if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No reviews yet — be the first.', style: TextStyle(color: AppColors.muted)),
              )
            else
              for (final r in reviews.take(5)) _ReviewTile(r),
          ],
        );
      },
    );
  }

  static DateTime _at(Map<String, dynamic> r) => (r['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

  Future<void> _write(BuildContext context, WidgetRef ref, Map<String, dynamic>? mine) async {
    final user = ref.read(authProvider);
    if (user == null) {
      context.push('/login');
      return;
    }
    final result = await showGlassBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        initialRating: (mine?['rating'] as num?)?.toInt() ?? 0,
        initialText: mine?['text'] as String? ?? '',
      ),
    );
    if (result == null) return;
    try {
      await FirebaseFirestore.instance.collection('reviews').doc('${productId}_${user.uid}').set({
        'productId': productId,
        'userId': user.uid,
        'userName': user.name,
        'rating': result.$1,
        'text': result.$2,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) showGlassToast(context, 'Thanks for your review!');
    } catch (_) {
      if (context.mounted) showGlassToast(context, "Couldn't save your review. Please try again.");
    }
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final at = (data['createdAt'] as Timestamp?)?.toDate();
    final text = data['text'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(data['userName'] as String? ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              for (var i = 1; i <= 5; i++)
                Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: AppColors.gold),
              const Spacer(),
              if (at != null) Text(shortDate(at), style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: AppColors.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.initialRating, required this.initialText});

  final int initialRating;
  final String initialText;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.initialRating;
  late final _text = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = i);
                  },
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _text,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'What did you think? (optional)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _rating == 0 ? null : () => Navigator.of(context).pop((_rating, _text.text.trim())),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
