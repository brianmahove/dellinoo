import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'product_list_screen.dart';
import '../../core/iconly.dart';

/// "Shop" tab: search + filter, category pills, product grid.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _categoryId;
  ProductFilter _filter = const ProductFilter(sort: SortOption.popular);

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: SearchPill(onTap: () => context.push('/search'))),
                    const SizedBox(width: 12),
                    CircleIconButton(
                      icon: IconlyLight.filter,
                      size: 52,
                      color: _filter.isActive ? AppColors.ink : AppColors.primary,
                      iconColor: _filter.isActive ? AppColors.primary : AppColors.black,
                      onTap: () async {
                        final f = await showFilterSheet(context, _filter);
                        if (f != null) setState(() => _filter = f);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Select by Category')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    PillChip(
                      label: 'All',
                      selected: _categoryId == null,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: PillChip(
                          label: c.name,
                          selected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(_filter.sort == SortOption.popular ? 'Most Popular' : _filter.sort.label),
            ),
            ProductsBuilder(
              sliver: true,
              builder: (all) {
                final products = _filter.apply(
                  all.where((p) => _categoryId == null || p.categoryId == _categoryId).toList(),
                );
                if (products.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: IconlyLight.search,
                      title: 'Nothing here yet',
                      message: 'Try another filter.',
                    ),
                  );
                }
                return ProductSliverGrid(products);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
          ],
        ),
      ),
    );
  }
}
