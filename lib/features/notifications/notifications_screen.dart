import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// In-app notification history (the Home bell). Personal updates — orders,
/// payments, reminders, price drops, quotes, invoices — are recorded by the
/// payments Worker each time it sends a push, so they're here even if the
/// push itself never arrived. Promos are merged in from the public `promos`
/// collection unless "Deals & offers" is off.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the inbox reads everything; rows keep their unread styling
    // until the customer leaves (see promosInboxProvider).
    WidgetsBinding.instance.addPostFrameCallback((_) => markInboxRead(ref));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider) != null;
    final personal = ref.watch(personalInboxProvider);
    final promos = ref.watch(promosInboxProvider);
    final loading = personal.isLoading || promos.isLoading;
    final items = [...?personal.value, ...?promos.value]..sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      appBar: const PageHeader(title: 'Notifications'),
      body: loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(
              icon: IconlyLight.notification,
              title: 'No notifications yet',
              message: signedIn
                  ? "Updates about your orders, quotes and price drops will show up here."
                  : 'Sign in to get updates about your orders here.',
              action: signedIn
                  ? null
                  : FilledButton(onPressed: () => context.push('/login'), child: const Text('Sign in')),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final tile = _InboxTile(item: item);
                if (item.promo) return tile;
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(22)),
                    child: const Icon(IconlyLight.delete, color: AppColors.onPrimary),
                  ),
                  onDismissed: (_) => deleteInboxItem(ref, item.id),
                  child: tile,
                );
              },
            ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item});

  final InboxItem item;

  static IconData _icon(String kind) => switch (kind) {
    'payment' => IconlyLight.wallet,
    'reminder' => IconlyLight.time_circle,
    'price_drop' => IconlyLight.heart,
    'quote' => IconlyLight.discovery,
    'invoice' => IconlyLight.document,
    'promo' => IconlyLight.discount,
    _ => IconlyLight.bag,
  };

  static String _when(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return dayMonth(at);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    return Material(
      color: unread ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.route.isEmpty ? null : () => Push.openRoute(item.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                child: Icon(_icon(item.kind), color: AppColors.accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 14.5,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_when(item.at), style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.body, style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.accentOrange, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
