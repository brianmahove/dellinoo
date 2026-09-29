import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/payment_dialog.dart';

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    final hasPreorder = order?.items.any((i) => i.product.stockStatus == StockStatus.preorder) ?? false;
    // Only known-unpaid (status still `placed`) gets the different treatment
    // below — an order we haven't loaded yet defaults to the celebratory
    // copy rather than flashing a scary state during a brief load.
    final unpaid = order?.status == OrderStatus.placed;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  unpaid ? Icon(IconlyBold.time_circle, size: 64, color: AppColors.accentOrange) : const DrawnCheck(),
                  const SizedBox(height: 24),
                  Text(
                    unpaid ? 'Order saved' : 'Order placed!',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order #$orderId${order != null ? ' · ${money(order.total)}' : ''}',
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    order == null
                        ? 'Thanks for shopping with Dellinoo.'
                        : unpaid
                        ? "We couldn't confirm your payment. Your order is saved and nothing's lost — "
                              'you can complete payment any time from below.'
                        : hasPreorder
                        ? 'Thanks for shopping with Dellinoo. In-stock items arrive by '
                              '${weekdayDayMonth(StockStatus.inStock.arrivalFrom(order.createdAt))}; items from China by '
                              '${weekdayDayMonth(StockStatus.preorder.arrivalFrom(order.createdAt))}. '
                              'We will update you along the way.'
                        : 'Thanks for shopping with Dellinoo. Your order arrives by '
                              '${weekdayDayMonth(StockStatus.inStock.arrivalFrom(order.createdAt))}. '
                              'We will notify you when it is out for delivery.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.5),
                  ),
                  const Spacer(),
                  if (unpaid && order != null) ...[
                    GradientButton(
                      onPressed: () => retryPayment(
                        context,
                        orderId: order.docId,
                        initialMethod: order.payment,
                        initialPhone: order.address.phone,
                      ),
                      child: const Text('Complete payment'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GradientButton(
                    onPressed: () => context.go('/orders/$orderId'),
                    colors: unpaid ? AppColors.orangeGradient : AppColors.buttonGradient,
                    child: const Text('Track my order'),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    onPressed: () => context.go('/home'),
                    colors: AppColors.orangeGradient,
                    child: const Text('Continue shopping'),
                  ),
                ],
              ),
            ),
          ),
          if (!unpaid) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}
