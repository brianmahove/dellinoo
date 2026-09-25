import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    final hasPreorder = order?.items.any((i) => i.product.stockStatus == StockStatus.preorder) ?? false;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.inStockSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 64, color: AppColors.inStock),
              ),
              const SizedBox(height: 24),
              const Text('Order placed!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Order #$orderId${order != null ? ' · ${money(order.total)}' : ''}',
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Text(
                hasPreorder
                    ? 'Thanks for shopping with Dellinoo. In-stock items will be delivered in 1–3 days. Items from China arrive in 2–3 weeks, and we will update you along the way.'
                    : 'Thanks for shopping with Dellinoo. We are preparing your order and will notify you when it is out for delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/orders/$orderId'), child: const Text('Track my order')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.go('/home'), child: const Text('Continue shopping')),
            ],
          ),
        ),
      ),
    );
  }
}
