import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../catalog/product_list_screen.dart';
import '../../core/iconly.dart';

String productsLink({required String title, String? category, ProductCollection? collection}) => Uri(
  path: '/products',
  queryParameters: {'title': title, 'category': ?category, 'collection': ?collection?.name},
).toString();

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ProductFilter _filter = const ProductFilter();

  @override
  Widget build(BuildContext context) {
    final wishCount = ref.watch(wishlistProvider).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider.future),
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
                        icon: IconlyLight.heart,
                        size: 52,
                        badge: wishCount,
                        onTap: () => context.push('/wishlist'),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: _BannerCarousel()),
              SliverToBoxAdapter(child: SectionHeader('Select by Category', onSeeAll: () => context.go('/categories'))),
              const SliverToBoxAdapter(child: _CategoryRow()),
              ProductsBuilder(
                sliver: true,
                builder: (products) {
                  final deals = products.where((p) => p.onSale).toList();
                  final recommended = _filter.apply(products);
                  final byId = {for (final p in products) p.id: p};
                  final recent = [
                    for (final id in ref.watch(recentlyViewedProvider))
                      if (byId[id] != null) byId[id]!,
                  ];
                  return SliverMainAxisGroup(
                    slivers: [
                      if (recent.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          key: const ValueKey('recent-header'),
                          child: SectionHeader(
                            'Recently viewed',
                            trailing: TextButton(
                              onPressed: ref.read(recentlyViewedProvider.notifier).clear,
                              child: const Text('Clear'),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(key: const ValueKey('recent-row'), child: _RecentRow(recent)),
                      ],
                      SliverToBoxAdapter(
                        key: const ValueKey('deals-header'),
                        child: SectionHeader(
                          'Hot Deals',
                          onSeeAll: () =>
                              context.push(productsLink(title: 'Hot Deals', collection: ProductCollection.deals)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 250,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: deals.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 14),
                            itemBuilder: (_, i) => ProductCard(
                              deals[i],
                              key: ValueKey('deals-${deals[i].id}'),
                              width: 170,
                              heroScope: 'deals',
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          'Recommended Styles',
                          onSeeAll: () => context.push(productsLink(title: 'All products')),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: Row(
                            children: [
                              FilterButton(
                                active: _filter.isActive,
                                onTap: () async {
                                  final f = await showFilterSheet(context, _filter);
                                  if (f != null) setState(() => _filter = f);
                                },
                              ),
                              if (_filter.isActive) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    [
                                      if (_filter.stock != StockFilter.all) _filter.stock.label,
                                      if (_filter.sort != SortOption.recommended) _filter.sort.label,
                                    ].join(' · '),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ProductSliverGrid(recommended, animateKey: '${_filter.stock.name}-${_filter.sort.name}'),
                    ],
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner {
  const _Banner(this.title, this.highlight, this.image, this.background, this.foreground, this.link);

  final String title;
  final String highlight;
  final String image;
  final Color background;
  final Color foreground;
  final String link;
}

final _banners = [
  _Banner(
    'Get Your Special\nSale ',
    'Up to 30%',
    "https://cdn.dummyjson.com/product-images/womens-dresses/black-women's-gown/thumbnail.webp",
    AppColors.primary,
    AppColors.black,
    productsLink(title: 'Hot Deals', collection: ProductCollection.deals),
  ),
  _Banner(
    'Latest Phones\nWith ',
    'Warranty',
    'https://cdn.dummyjson.com/product-images/smartphones/iphone-13-pro/thumbnail.webp',
    AppColors.black,
    Colors.white,
    productsLink(title: 'Phones', category: 'phones'),
  ),
  _Banner(
    'Fresh Sneakers\nFrom ',
    '\$89',
    'https://cdn.dummyjson.com/product-images/mens-shoes/nike-air-jordan-1-red-and-black/thumbnail.webp',
    const Color(0xFFE6DDD3),
    AppColors.black,
    productsLink(title: 'Shoes', category: 'shoes'),
  ),
];

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _banners.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = _banners[i];
              final ctaDark = b.foreground == AppColors.black;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: b.background,
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(b.link),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 18, 4, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: b.title,
                                    children: [
                                      TextSpan(
                                        text: b.highlight,
                                        style: const TextStyle(decoration: TextDecoration.underline),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: b.foreground,
                                    fontSize: 20,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    decorationColor: b.foreground,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: ctaDark ? AppColors.black : AppColors.primary,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Text(
                                    'Shop Now',
                                    style: TextStyle(
                                      color: ctaDark ? Colors.white : AppColors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                            child: NetImage(b.image, fit: BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.ink : AppColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    String? imageFor(String categoryId) {
      for (final p in products) {
        if (p.categoryId == categoryId) return p.thumbnail;
      }
      return null;
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = categories[i];
          final image = imageFor(c.id);
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => context.push(productsLink(title: c.name, category: c.id)),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: image == null
                        ? Icon(c.icon, color: AppColors.ink)
                        : ClipOval(child: NetImage(image, fit: BoxFit.contain)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact row of products the user opened recently.
class _RecentRow extends StatelessWidget {
  const _RecentRow(this.products);

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = products[i];
          final tag = 'product-recent-${p.id}';
          return GestureDetector(
            key: ValueKey(tag),
            onTap: () => context.push('/product/${p.id}', extra: tag),
            child: SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.tintFor(p.id), borderRadius: BorderRadius.circular(20)),
                    child: ProductPhotoHero(
                      tag: tag,
                      child: NetImage(p.thumbnail, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
