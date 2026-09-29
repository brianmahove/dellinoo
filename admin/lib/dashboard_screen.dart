import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'iconly.dart';

/// Matches OrderStatus in the main app's lib/data/models.dart — kept in sync
/// by hand, same as the small copy in orders_screen.dart (see the note in
/// shell.dart about the two apps/screens not sharing code yet).
const _pipeline = ['paid', 'processing', 'boughtInChina', 'inTransit', 'arrivedZim', 'outForDelivery', 'delivered'];

String _statusLabel(String s) => switch (s) {
  'placed' => 'Awaiting payment',
  'paid' => 'Paid – to process',
  'processing' => 'Processing',
  'boughtInChina' => 'Bought in China',
  'inTransit' => 'Flying to Zimbabwe',
  'arrivedZim' => 'Arrived in Harare',
  'outForDelivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  _ => s,
};

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _moneyShort = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0);

/// One order flattened for aggregation.
class _O {
  _O(Map<String, dynamic> d) {
    final history = List<Map<String, dynamic>>.from(d['history'] as List? ?? const []);
    status = history.isEmpty ? 'placed' : history.last['status'] as String;
    createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    items = List<Map<String, dynamic>>.from(d['items'] as List? ?? const []);
    final subtotal = items.fold<double>(0, (s, i) => s + _num(i['price']) * _num(i['quantity']));
    final discount = _num((d['coupon'] as Map?)?['discount']);
    total = subtotal - discount + _num((d['area'] as Map?)?['fee']);
    area = (d['area'] as Map?)?['name'] as String? ?? 'Unknown';
    userId = d['userId'] as String?;
    // The order's payment time, so "revenue this month" follows when the money
    // arrived rather than when the basket was placed.
    final paidEvent = history.where((h) => h['status'] == 'paid').firstOrNull;
    paidAt = (paidEvent?['at'] as Timestamp?)?.toDate() ?? createdAt;
  }

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  late final String status;
  late final DateTime? createdAt;
  late final DateTime? paidAt;
  late final List<Map<String, dynamic>> items;
  late final double total;
  late final String area;
  late final String? userId;

  bool get isPaid => status != 'placed';
}

/// Owner analytics. No Cloud Functions to precompute them (Spark plan — see
/// CLAUDE.md), so this reads the full `orders`/`products` collections
/// client-side and aggregates in Dart. Fine at this scale; revisit if order
/// history grows large enough to matter.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ColoredBox(
          color: AppColors.background,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, orderSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                builder: (context, productSnap) {
                  if (orderSnap.hasError || productSnap.hasError) {
                    return Center(child: Text('Error: ${orderSnap.error ?? productSnap.error}'));
                  }
                  if (!orderSnap.hasData || !productSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orders = orderSnap.data!.docs.map((d) => _O(d.data())).toList();
                  final products = productSnap.data!.docs;
                  return _DashboardBody(orders: orders, productCount: products.length);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.orders, required this.productCount});

  final List<_O> orders;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final paid = orders.where((o) => o.isPaid).toList();

    double revenueIn(DateTime from, DateTime to) => paid
        .where((o) => o.paidAt != null && !o.paidAt!.isBefore(from) && o.paidAt!.isBefore(to))
        .fold(0.0, (s, o) => s + o.total);

    final revenueThisMonth = revenueIn(monthStart, now.add(const Duration(days: 1)));
    final revenueLastMonth = revenueIn(lastMonthStart, monthStart);
    final growth = revenueLastMonth == 0 ? null : (revenueThisMonth - revenueLastMonth) / revenueLastMonth * 100;

    final ordersToday = orders.where((o) => o.createdAt != null && !o.createdAt!.isBefore(today)).length;
    final unpaid = orders.where((o) => !o.isPaid).toList();
    final unpaidValue = unpaid.fold(0.0, (s, o) => s + o.total);
    final toProcess = paid.where((o) => o.status == 'paid').length;
    final aov = paid.isEmpty ? 0.0 : paid.fold(0.0, (s, o) => s + o.total) / paid.length;

    // Repeat customers: of everyone who has paid, how many paid more than once.
    final perCustomer = <String, int>{};
    for (final o in paid) {
      if (o.userId != null) perCustomer.update(o.userId!, (n) => n + 1, ifAbsent: () => 1);
    }
    final repeat = perCustomer.values.where((n) => n > 1).length;
    final repeatRate = perCustomer.isEmpty ? 0.0 : repeat / perCustomer.length * 100;

    // Last 14 days of paid revenue for the chart.
    final days = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
    final byDay = [
      for (final day in days)
        paid
            .where(
              (o) =>
                  o.paidAt != null && !o.paidAt!.isBefore(day) && o.paidAt!.isBefore(day.add(const Duration(days: 1))),
            )
            .fold(0.0, (s, o) => s + o.total),
    ];

    // Best sellers + China vs in-stock split, from paid orders only.
    final sold = <String, ({int qty, double revenue})>{};
    var chinaRevenue = 0.0;
    var stockRevenue = 0.0;
    for (final o in paid) {
      for (final i in o.items) {
        final qty = _O._num(i['quantity']).toInt();
        final line = _O._num(i['price']) * qty;
        final name = i['name'] as String? ?? 'Unknown';
        final prev = sold[name];
        sold[name] = (qty: (prev?.qty ?? 0) + qty, revenue: (prev?.revenue ?? 0) + line);
        if (i['stockStatus'] == 'preorder') {
          chinaRevenue += line;
        } else {
          stockRevenue += line;
        }
      }
    }
    final top = sold.entries.toList()..sort((a, b) => b.value.qty.compareTo(a.value.qty));

    final areaCounts = <String, int>{};
    for (final o in paid) {
      areaCounts.update(o.area, (n) => n + 1, ifAbsent: () => 1);
    }
    final areas = areaCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final stageCounts = {for (final s in _pipeline) s: paid.where((o) => o.status == s).length};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FlowGrid(
            minItemWidth: 200,
            spacing: 16,
            children: [
              _StatTile(
                icon: IconlyLight.wallet,
                label: 'Revenue this month',
                value: _money.format(revenueThisMonth),
                hint: growth == null
                    ? 'Last month: ${_money.format(revenueLastMonth)}'
                    : '${growth >= 0 ? '▲' : '▼'} ${growth.abs().toStringAsFixed(0)}% vs last month',
                hintColor: growth == null ? null : (growth >= 0 ? AppColors.inStock : AppColors.danger),
                accent: AppColors.inStock,
              ),
              _StatTile(
                icon: IconlyLight.location,
                label: 'Paid, waiting for you',
                value: '$toProcess',
                hint: toProcess == 0 ? 'All caught up' : 'Buy these & update status',
                accent: AppColors.primary,
              ),
              _StatTile(
                icon: IconlyLight.time_circle,
                label: 'Unpaid orders',
                value: '${unpaid.length}',
                hint: '${_money.format(unpaidValue)} not yet collected',
                accent: AppColors.preorder,
              ),
              _StatTile(
                icon: IconlyLight.paper,
                label: 'Orders today',
                value: '$ordersToday',
                hint: '${orders.length} all time',
                accent: AppColors.primary,
              ),
              _StatTile(
                icon: IconlyLight.bag_2,
                label: 'Average order',
                value: _money.format(aov),
                hint: '${paid.length} paid orders',
                accent: AppColors.accentOrange,
              ),
              _StatTile(
                icon: IconlyLight.swap,
                label: 'Repeat customers',
                value: '${repeatRate.toStringAsFixed(0)}%',
                hint: '$repeat of ${perCustomer.length} buyers',
                accent: AppColors.inStock,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            title: 'Revenue, last 14 days',
            child: _BarChart(days: days, values: byDay),
          ),
          const SizedBox(height: 20),
          _FlowGrid(
            minItemWidth: 380,
            spacing: 20,
            children: [
              _Card(
                title: 'Orders by stage',
                child: Column(
                  children: [
                    for (final s in _pipeline)
                      _BarRow(
                        label: _statusLabel(s),
                        value: stageCounts[s]!,
                        max: stageCounts.values.fold(1, (a, b) => a > b ? a : b),
                        color: s == 'paid' ? AppColors.primary : AppColors.accentOrange,
                      ),
                  ],
                ),
              ),
              _Card(
                title: 'Best sellers',
                child: top.isEmpty
                    ? const _Empty('No paid orders yet')
                    : Column(
                        children: [
                          for (final e in top.take(6))
                            _BarRow(
                              label: e.key,
                              value: e.value.qty,
                              max: top.first.value.qty,
                              color: AppColors.primary,
                              trailing: '${e.value.qty} sold · ${_moneyShort.format(e.value.revenue)}',
                            ),
                        ],
                      ),
              ),
              _Card(
                title: 'Where orders go',
                child: areas.isEmpty
                    ? const _Empty('No paid orders yet')
                    : Column(
                        children: [
                          for (final e in areas.take(6))
                            _BarRow(
                              label: e.key,
                              value: e.value,
                              max: areas.first.value,
                              color: AppColors.accentOrange,
                            ),
                        ],
                      ),
              ),
              _Card(
                title: 'Sales split',
                child: _SplitBar(
                  aLabel: 'In stock (Zimbabwe)',
                  a: stockRevenue,
                  bLabel: 'From China (pre-order)',
                  b: chinaRevenue,
                  footer: '$productCount products in catalogue',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays children out in equal-width columns that always fill the row: as many
/// columns as fit at [minItemWidth] (never more than there are children), each
/// stretched so there's no leftover space at the end.
class _FlowGrid extends StatelessWidget {
  const _FlowGrid({required this.minItemWidth, required this.spacing, required this.children});

  final double minItemWidth;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fit = ((maxWidth + spacing) / (minItemWidth + spacing)).floor();
        final columns = fit.clamp(1, children.length);
        final itemWidth = (maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [for (final c in children) SizedBox(width: itemWidth, child: c)],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: TextStyle(color: AppColors.muted)),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
    this.hintColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color? hintColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: TextStyle(color: hintColor ?? AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal bar with a label above and an optional right-hand caption.
class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.max, required this.color, this.trailing});

  final String label;
  final int value;
  final int max;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(trailing ?? '$value', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : value / max,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.aLabel, required this.a, required this.bLabel, required this.b, required this.footer});

  final String aLabel;
  final double a;
  final String bLabel;
  final double b;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final total = a + b;
    if (total == 0) return const _Empty('No paid orders yet');
    Widget legend(Color c, String label, double v) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(
            '${_money.format(v)} · ${(v / total * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (a > 0)
                  Expanded(
                    flex: (a * 1000).round(),
                    child: const ColoredBox(color: AppColors.inStock),
                  ),
                if (b > 0)
                  Expanded(
                    flex: (b * 1000).round(),
                    child: const ColoredBox(color: AppColors.accentOrange),
                  ),
              ],
            ),
          ),
        ),
        legend(AppColors.inStock, aLabel, a),
        legend(AppColors.accentOrange, bLabel, b),
        const SizedBox(height: 14),
        Text(footer, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.days, required this.values});

  final List<DateTime> days;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold(0.0, (a, b) => a > b ? a : b);
    if (max == 0) return const _Empty('No payments in the last 14 days');
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Tooltip(
                  message: '${DateFormat.MMMd().format(days[i])}: ${_money.format(values[i])}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        Text(_moneyShort.format(values[i]), style: TextStyle(color: AppColors.muted, fontSize: 10)),
                      const SizedBox(height: 3),
                      Container(
                        height: values[i] == 0 ? 3 : 130 * values[i] / max,
                        decoration: BoxDecoration(
                          color: values[i] == 0 ? AppColors.line : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(DateFormat.d().format(days[i]), style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
