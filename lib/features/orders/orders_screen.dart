import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final active = orders.where((o) => o.status != OrderStatus.delivered).toList();
    final done = orders.where((o) => o.status == OrderStatus.delivered).toList();

    Widget list(List<Order> list) => list.isEmpty
        ? const EmptyState(icon: IconlyLight.paper, title: 'No orders here', message: 'Your orders will show up here.')
        : ListView(padding: const EdgeInsets.symmetric(vertical: 10), children: [for (final o in list) OrderCard(o)]);

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
                        Text(money(order.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
