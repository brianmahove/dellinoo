import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/contact.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
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
          if (order.hasChinaItems) _ChinaJourney(order),
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
                                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                                ),
                                const SizedBox(height: 4),
                                StockBadge(i.product.stockStatus, compact: true, orderedAt: order.createdAt),
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
              onPressed: () => openWhatsApp('Hi Dellinoo, I need help with my order #${order.id}.'),
              icon: const FaIcon(FontAwesomeIcons.whatsapp),
              label: const Text('Need help? Chat on WhatsApp'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Order steps. On open, the progress line draws down step by step and each
/// completed step's dot pops in.
class _Timeline extends StatefulWidget {
  const _Timeline(this.order);

  final Order order;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final events = {for (final e in order.history) e.status: e};
    final steps = order.journey;
    final n = steps.length;
    // Portion of the animation belonging to step i (dot) and its connector (line).
    double phase(int i, double offset) => ((_c.value * n) - i - offset).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Column(
        children: [
          for (var i = 0; i < n; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        () {
                          final done = events.containsKey(steps[i]);
                          final pop = done ? Curves.easeOutBack.transform(phase(i, 0)) : 1.0;
                          return Transform.scale(
                            scale: 0.4 + 0.6 * pop,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: done ? AppColors.primary : AppColors.background,
                                shape: BoxShape.circle,
                                border: Border.all(color: done ? AppColors.primary : AppColors.line),
                              ),
                              child: Icon(steps[i].icon, size: 15, color: done ? AppColors.black : AppColors.muted),
                            ),
                          );
                        }(),
                        if (i < n - 1)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: CustomPaint(
                                size: const Size(2, 0),
                                painter: _ConnectorPainter(
                                  events.containsKey(steps[i + 1]) ? Curves.easeInOut.transform(phase(i, 0.5)) : 0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: 0.35 + 0.65 * phase(i, 0),
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
                                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                              ),
                            if (events[steps[i]]?.note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  events[steps[i]]!.note!,
                                  style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
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
              Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
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

/// China -> Zimbabwe route card: a plane moves along the route as the order
/// progresses. Stays dark in both themes so it stands out.
class _ChinaJourney extends StatelessWidget {
  const _ChinaJourney(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final idx = OrderStatus.values.indexOf(status);
    int at(OrderStatus s) => OrderStatus.values.indexOf(s);
    final progress = idx >= at(OrderStatus.arrivedZim)
        ? 1.0
        : idx == at(OrderStatus.inTransit)
        ? 0.55
        : idx == at(OrderStatus.boughtInChina)
        ? 0.12
        : 0.0;
    final (headline, sub) = switch (status) {
      OrderStatus.inTransit => ('Flying to Zimbabwe', 'Your items are in the air'),
      OrderStatus.boughtInChina => ('Bought in China', 'Packing at our Guangzhou warehouse'),
      OrderStatus.arrivedZim ||
      OrderStatus.outForDelivery ||
      OrderStatus.delivered => ('Landed in Harare', 'Your China items are in Zimbabwe'),
      _ => ('Ordering from our supplier', 'We buy your items in China after payment'),
    };
    final eta = StockStatus.preorder.arrivalFrom(order.createdAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13.5)),
          const SizedBox(height: 22),
          SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (_, c) {
                const pin = 34.0;
                final track = c.maxWidth - pin * 2;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: pin,
                      right: pin,
                      top: pin / 2 - 1,
                      child: CustomPaint(size: Size(track, 2), painter: _RoutePainter(progress)),
                    ),
                    const Positioned(left: 0, child: _Pin(label: 'CN')),
                    const Positioned(right: 0, child: _Pin(label: 'ZW')),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      left: pin + track * progress - 13,
                      top: 4,
                      child: Transform.rotate(
                        angle: 0.8,
                        child: const Icon(IconlyBold.send, color: AppColors.primary, size: 26),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Guangzhou', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
              const Spacer(),
              Text('Harare', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
            ],
          ),
          if (progress < 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Expected in Zimbabwe by ${weekdayDayMonth(eta)}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }
}

/// Dashed route line, solid yellow for the part already travelled.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final done = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final todo = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final split = size.width * progress;
    canvas.drawLine(Offset.zero, Offset(split, 0), done);
    for (var x = split + 4; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset((x + 5).clamp(0, size.width), 0), todo);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.progress != progress;
}

/// Vertical timeline connector: grey track, yellow fill drawn [progress] of the way down.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final track = Paint()
      ..color = AppColors.line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), track);
    if (progress > 0) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height * progress),
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.progress != progress;
}
