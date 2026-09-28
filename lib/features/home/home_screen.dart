import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/motion.dart';
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
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () => ref.refresh(productsProvider.future),
              builder: logoRefreshIndicator,
            ),
            // Logo on the left, notifications and cart on the right, search underneath.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    const BrandLogo(width: 168),
                    const Spacer(),
                    CircleIconButton(
                      icon: IconlyLight.notification,
                      color: AppColors.tint,
                      onTap: () => showGlassToast(context, 'Notifications are coming soon'),
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(
                      icon: IconlyLight.buy,
                      color: AppColors.tint,
                      badge: cartCount,
                      onTap: () => context.go('/cart'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SearchPill(fill: AppColors.tint, onTap: () => context.push('/search')),
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
                    ProductSliverGrid(
                      recommended,
                      heroScope: 'home',
                      animateKey: '${_filter.stock.name}-${_filter.sort.name}',
                    ),
                  ],
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
          ],
        ),
      ),
    );
  }
}

/// A hero banner: white headline (second line in [highlightColor]), a short
/// subtitle and an orange "Shop Now" pill over a violet gradient. Text is
/// always white, so the banners look the same in light and dark mode.
class _Banner {
  const _Banner({
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.image,
    required this.gradient,
    required this.link,
    this.stops,
    this.icon,
  });

  final String title;
  final String highlight;
  final String subtitle;
  final String image;
  final List<Color> gradient;
  final List<double>? stops;
  final String link;

  /// Amber second headline line and symbol, readable on every banner gradient.
  Color get highlightColor => AppColors.orangeGradient.first;

  /// Optional symbol before the headline (e.g. the bolt on "Daily Deals").
  final IconData? icon;
}

final _banners = [
  _Banner(
    title: 'Shop Brands.\n',
    highlight: 'Better Prices.',
    subtitle: 'Shop your favourite brands all in one place.',
    image: 'https://cdn.dummyjson.com/product-images/mens-shoes/nike-air-jordan-1-red-and-black/thumbnail.webp',
    gradient: const [Color(0xFF4C1DB8), AppColors.primary, AppColors.accentOrange],
    stops: const [0, 0.55, 1],
    link: productsLink(title: 'All products'),
  ),
  _Banner(
    title: 'Top Picks\n',
    highlight: 'for You',
    subtitle: 'Trending phones, just for you.',
    image: 'https://cdn.dummyjson.com/product-images/smartphones/iphone-13-pro/thumbnail.webp',
    gradient: const [Color(0xFF3B1899), AppColors.primary, AppColors.primaryLight],
    link: productsLink(title: 'Phones', category: 'phones'),
  ),
  _Banner(
    title: 'Daily Deals\n',
    highlight: 'Up to 30% off',
    subtitle: "Don't miss out on amazing offers!",
    image: "https://cdn.dummyjson.com/product-images/womens-dresses/black-women's-gown/thumbnail.webp",
    gradient: const [Color(0xFF2A0F73), AppColors.primary, Color(0xFFB4530A)],
    stops: const [0, 0.6, 1],
    icon: Icons.bolt_rounded,
    link: productsLink(title: 'Hot Deals', collection: ProductCollection.deals),
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
          height: 184,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = _banners[i];
              // How far this banner is from the centre (-1..1) drives the parallax.
              double delta() {
                if (!_controller.hasClients || !_controller.position.haveDimensions) return 0;
                return (i - (_controller.page ?? 0)).clamp(-1.0, 1.0).toDouble();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: b.gradient,
                      stops: b.stops,
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => context.push(b.link),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (_, child) => Transform.translate(offset: Offset(delta() * 30, 0), child: child),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 0, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          if (b.icon != null)
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.middle,
                                              child: Icon(b.icon, color: b.highlightColor, size: 24),
                                            ),
                                          TextSpan(text: b.title),
                                          TextSpan(
                                            text: b.highlight,
                                            style: TextStyle(color: b.highlightColor),
                                          ),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      b.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: AppColors.orangeGradient),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Shop Now',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(IconlyLight.arrow_right, size: 14, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                              child: AnimatedBuilder(
                                animation: _controller,
                                // Photo drifts further than the text: depth.
                                builder: (_, child) => Transform.translate(
                                  offset: Offset(delta() * 90, 0),
                                  child: Transform.scale(scale: 1 - delta().abs() * 0.12, child: child),
                                ),
                                child: NetImage(b.image, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ],
                      ),
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
          return PressScale(
            scale: 0.9,
            child: InkWell(
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
                      decoration: BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
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
          return PressScale(
            key: ValueKey(tag),
            child: GestureDetector(
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
                      decoration: BoxDecoration(
                        color: AppColors.tintFor(p.id),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ProductPhotoHero(
                        tag: tag,
                        child: NetImage(p.thumbnail, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      money(p.price),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accent),
                    ),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
