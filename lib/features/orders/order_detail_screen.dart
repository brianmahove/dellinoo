import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'orders_screen.dart';
import '../../core/iconly.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    final canPop = context.canPop();
    final appBar = AppBar(
      title: Text('Order #$orderId'),
      leading: canPop ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/home')),
    );
    if (order == null) {
      return Scaffold(
        appBar: appBar,
        body: const EmptyState(icon: IconlyLight.paper, title: 'Order not found', message: ''),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Order status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    OrderStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 16),
                _Timeline(order),
              ],
            ),
          ),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                for (final i in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => context.push('/product/${i.product.id}'),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: 60, height: 60, child: NetImage(i.product.thumbnail)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [if (i.options.isNotEmpty) i.optionsLabel, 'Qty ${i.quantity}'].join('  ·  '),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                ),
                                const SizedBox(height: 4),
                                StockBadge(i.product.stockStatus, compact: true),
                              ],
                            ),
                          ),
                          Text(money(i.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery & payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                _Info(IconlyLight.location, order.address.fullName, '${order.address.phone}\n${order.address.oneLine}'),
                _Info(Icons.local_shipping_outlined, order.area.name, order.area.eta),
                _Info(IconlyLight.wallet, 'Paid with ${order.payment.label}', dateTime(order.createdAt)),
                const Divider(height: 24),
                _Row('Subtotal', money(order.subtotal)),
                _Row('Delivery', order.area.fee == 0 ? 'FREE' : money(order.area.fee)),
                _Row('Total', money(order.total), bold: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: OutlinedButton.icon(
              onPressed: () => showGlassToast(context, 'Opens WhatsApp chat with Dellinoo (next build)'),
              icon: const Icon(IconlyLight.chat),
              label: const Text('Need help? Chat on WhatsApp'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    final events = {for (final e in order.history) e.status: e};
    const steps = OrderStatus.values;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: events.containsKey(steps[i]) ? AppColors.primary : AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: events.containsKey(steps[i]) ? AppColors.primary : AppColors.line),
                        ),
                        child: Icon(
                          steps[i].icon,
                          size: 15,
                          color: events.containsKey(steps[i]) ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: events.containsKey(steps[i + 1]) ? AppColors.primary : AppColors.line,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: TextStyle(
                            fontWeight: steps[i] == order.status ? FontWeight.w700 : FontWeight.w500,
                            color: events.containsKey(steps[i]) ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                        if (events[steps[i]] != null)
                          Text(
                            dateTime(events[steps[i]]!.at),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        if (events[steps[i]]?.note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              events[steps[i]]!.note!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: child,
  );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.ink),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      fontSize: bold ? 16 : 13.5,
      color: bold ? AppColors.ink : AppColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
