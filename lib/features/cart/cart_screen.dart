import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final count = ref.watch(cartCountProvider);
    final wishCount = ref.watch(wishlistProvider).length;
    final hasPreorder = items.any((i) => i.product.stockStatus == StockStatus.preorder);

    return Scaffold(
      appBar: PageHeader(
        title: 'Cart (${count.toString().padLeft(2, '0')})',
        showBack: false,
        trailing: CircleIconButton(icon: IconlyLight.heart, badge: wishCount, onTap: () => context.push('/wishlist')),
      ),
      body: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: kNavBarSpace),
              child: EmptyState(
                icon: IconlyLight.buy,
                title: 'Your cart is empty',
                message: 'Browse our latest fashion, phones and electronics.',
                action: SizedBox(
                  width: 200,
                  child: FilledButton(onPressed: () => context.go('/home'), child: const Text('Start shopping')),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    children: [
                      if (hasPreorder)
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.preorderSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(IconlyBold.send, color: AppColors.preorder, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Some items ship from China and arrive in 2–3 weeks. In-stock items may arrive first.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.preorder,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final item in items) _CartTile(item),
                    ],
                  ),
                ),
                _Summary(subtotal: subtotal),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    TextStyle label = const TextStyle(color: AppColors.muted, fontSize: 15);
    TextStyle value = const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Sub-total', style: label),
              const Spacer(),
              Text(money(subtotal), style: value),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Delivery Fee', style: label),
              const Spacer(),
              Text('At checkout', style: value.copyWith(color: AppColors.muted, fontSize: 14)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
          Row(
            children: [
              const Text('Total Cost', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(money(subtotal), style: value.copyWith(fontSize: 19, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.push('/checkout'), child: const Text('Checkout')),
          const SizedBox(height: kNavBarSpace - 8),
        ],
      ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile(this.item);

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Dismissible(
          key: ValueKey(item.key),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => cart.remove(item.key),
          background: Container(
            color: AppColors.dangerSoft,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 28),
            child: const Icon(IconlyBold.delete, color: AppColors.danger, size: 28),
          ),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/product/${item.product.id}'),
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tintFor(item.product.id),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: NetImage(item.product.thumbnail, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      for (final e in item.options.entries)
                        Text.rich(
                          TextSpan(
                            text: '${e.key}  : ',
                            style: const TextStyle(color: AppColors.muted),
                            children: [
                              TextSpan(
                                text: e.value,
                                style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (item.options.isEmpty) StockBadge(item.product.stockStatus, compact: true),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          QuantityStepper(
                            value: item.quantity,
                            min: 0,
                            small: true,
                            onChanged: (v) => cart.setQuantity(item.key, v),
                          ),
                          const Spacer(),
                          Text(money(item.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
