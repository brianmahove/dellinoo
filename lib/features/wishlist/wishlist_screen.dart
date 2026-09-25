import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistProvider).keys.toSet();
    return Scaffold(
      appBar: const PageHeader(title: 'Wishlist'),
      body: ProductsBuilder(
        builder: (all) {
          final products = all.where((p) => ids.contains(p.id)).toList();
          final drops = products.where((p) => ref.watch(priceDropProvider(p.id)) != null).length;
          if (products.isEmpty) {
            return EmptyState(
              icon: IconlyLight.heart,
              title: 'No saved items',
              message: 'Tap the heart on any product to save it for later.',
              action: SizedBox(
                width: 200,
                child: FilledButton(onPressed: () => context.go('/home'), child: const Text('Discover items')),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (drops > 0)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.inStockSoft, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        Icon(IconlyBold.discount, color: AppColors.inStock),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            drops == 1
                                ? '1 saved item is cheaper than when you saved it!'
                                : '$drops saved items are cheaper than when you saved them!',
                            style: TextStyle(color: AppColors.inStock, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ProductSliverGrid(products, heroScope: 'wishlist', showPriceDrop: true),
            ],
          );
        },
      ),
    );
  }
}
