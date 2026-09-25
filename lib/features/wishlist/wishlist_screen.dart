import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistProvider);
    return Scaffold(
      appBar: const PageHeader(title: 'Wishlist'),
      body: ProductsBuilder(
        builder: (all) {
          final products = all.where((p) => ids.contains(p.id)).toList();
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
              ProductSliverGrid(products),
            ],
          );
        },
      ),
    );
  }
}
