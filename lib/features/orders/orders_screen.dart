import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

/// Groups [OrderStatus] into the four buckets shown as shortcuts on the
/// Profile screen — kept here (not duplicated as ad-hoc predicates) so the
/// shortcut counts and the filtered list below always agree.
enum OrderStatusFilter {
  paid('Paid'),
  processing('Processing'),
  onTheWay('On the way'),
  delivered('Delivered');

  const OrderStatusFilter(this.label);
  final String label;

  bool matches(OrderStatus status) => switch (this) {
    OrderStatusFilter.paid => status == OrderStatus.paid || status == OrderStatus.placed,
    OrderStatusFilter.processing => const {
      OrderStatus.processing,
      OrderStatus.boughtInChina,
      OrderStatus.inTransit,
      OrderStatus.arrivedZim,
    }.contains(status),
    OrderStatusFilter.onTheWay => status == OrderStatus.outForDelivery,
    OrderStatusFilter.delivered => status == OrderStatus.delivered,
  };
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.filter});

  /// When set (a Profile-screen shortcut was tapped), shows only orders
  /// matching that status instead of the usual Active/Completed tabs.
  final OrderStatusFilter? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    Widget list(List<Order> list) => list.isEmpty
        ? const EmptyState(icon: IconlyLight.paper, title: 'No orders here', message: 'Your orders will show up here.')
        : RefreshIndicator(
            onRefresh: ref.read(ordersProvider.notifier).refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [for (final o in list) OrderCard(o)],
            ),
          );

    final filter = this.filter;
    if (filter != null) {
      return Scaffold(
        appBar: PageHeader(title: filter.label),
        body: list(orders.where((o) => filter.matches(o.status)).toList()),
      );
    }

    final active = orders.where((o) => o.status != OrderStatus.delivered).toList();
    final done = orders.where((o) => o.status == OrderStatus.delivered).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const PageHeader(
          title: 'My Orders',
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(children: [list(active), list(done)]),
      ),
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final delivered = status == OrderStatus.delivered;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: delivered ? AppColors.inStockSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: delivered ? AppColors.inStock : AppColors.ink,
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push('/orders/${order.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order #${order.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    OrderStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(shortDate(order.createdAt), style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final i in order.items.take(4))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 56, height: 56, child: NetImage(i.product.thumbnail)),
                        ),
                      ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(order.total),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.accent),
                        ),
                        Text(
                          '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
