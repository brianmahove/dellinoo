import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/contact.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'glass.dart';
import '../core/iconly.dart';

/// Space the floating nav bar covers at the bottom of tab screens.
const kNavBarSpace = 104.0;

class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.background = Colors.transparent,
    this.placeholderUrl,
  });

  final String url;
  final BoxFit fit;
  final Color background;
  final String? placeholderUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) =>
            placeholderUrl == null ? const SizedBox.shrink() : CachedNetworkImage(imageUrl: placeholderUrl!, fit: fit),
        errorWidget: (_, _, _) => Center(child: Icon(IconlyLight.image, color: AppColors.muted)),
      ),
    );
  }
}

/// White circular icon button used in headers (back, wishlist, cart...).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badge = 0,
    this.size = 46,
    this.color,
    this.iconColor,
    this.glass = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final double size;
  final Color? color;
  final Color? iconColor;

  /// Frosted instead of solid — for buttons that float over photos.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: glass ? Colors.transparent : (color ?? AppColors.surface),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: BounceOnChange(
              value: badge,
              child: Badge(
                isLabelVisible: badge > 0,
                backgroundColor: AppColors.danger,
                label: Text('$badge'),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.elasticOut,
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Icon(icon, key: ValueKey(icon), size: size * 0.46, color: iconColor ?? AppColors.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!glass) return button;
    return GlassBox(borderRadius: BorderRadius.circular(size / 2), tint: AppColors.glass(0.55), child: button);
  }
}

class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, this.onTap});

  /// Overrides the default "pop or go home" behaviour.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: IconlyLight.arrow_left_2,
    onTap: onTap ?? () => context.canPop() ? context.pop() : context.go('/home'),
  );
}

/// Standard page header: back button, title, optional trailing widget.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({super.key, required this.title, this.trailing, this.showBack = true, this.bottom, this.onBack});

  final String title;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(72 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: [
          if (showBack) ...[BackCircleButton(onTap: onBack), const SizedBox(width: 14)],
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
      bottom: bottom,
    );
  }
}

/// White search pill with the yellow circular search button.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, this.onTap, this.controller, this.onChanged, this.onSubmitted, this.autofocus = false});

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final editable = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 20, right: 5),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            Expanded(
              child: editable
                  ? TextField(
                      controller: controller,
                      autofocus: autofocus,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search here...',
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    )
                  : Text('Search here...', style: TextStyle(color: AppColors.muted, fontSize: 15)),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(IconlyLight.search, color: AppColors.black, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key, this.compact = false, this.orderedAt});

  final StockStatus status;
  final bool compact;

  /// Arrival is counted from this date (defaults to now).
  final DateTime? orderedAt;

  @override
  Widget build(BuildContext context) {
    final inStock = status == StockStatus.inStock;
    final fg = inStock ? AppColors.inStock : AppColors.preorder;
    final bg = inStock ? AppColors.inStockSoft : AppColors.preorderSoft;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(inStock ? IconlyBold.tick_square : IconlyBold.send, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              compact ? arrivalShort(status, orderedAt) : arrivalLong(status, orderedAt),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 12 : 13, color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceText extends StatelessWidget {
  const PriceText(this.product, {super.key, this.size = 16, this.color});

  final Product product;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.ink;
    final onDark = this.color != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          money(product.price),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color),
        ),
        if (product.onSale)
          Text(
            money(product.oldPrice!),
            style: TextStyle(
              fontSize: size * 0.72,
              color: onDark ? color.withValues(alpha: 0.75) : AppColors.muted,
              decoration: TextDecoration.lineThrough,
              decorationColor: onDark ? color : AppColors.muted,
            ),
          ),
      ],
    );
  }
}

class WishlistButton extends ConsumerWidget {
  const WishlistButton(this.productId, {super.key, this.size = 30, this.glass = false});

  final String productId;
  final double size;
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(wishlistProvider.select((s) => s.containsKey(productId)));
    return CircleIconButton(
      icon: saved ? IconlyBold.heart : IconlyLight.heart,
      iconColor: saved ? AppColors.danger : AppColors.ink,
      size: size,
      glass: glass,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(wishlistProvider.notifier).toggle(productId, ref.read(productProvider(productId))?.price ?? 0);
      },
    );
  }
}

class RatingPill extends StatelessWidget {
  const RatingPill(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: BorderRadius.circular(13),
      tint: AppColors.glass(0.55),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(IconlyBold.star, size: 16, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Product tile from the design: tinted photo card, rating + heart on top,
/// translucent label strip with name, price and delivery time at the bottom.
class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key, this.width, this.heroScope = 'grid', this.showPriceDrop = false});

  final Product product;
  final double? width;

  /// Makes the Hero tag unique when the same product shows twice on a screen
  /// (e.g. in "Hot Deals" and the grid below it).
  final String heroScope;

  /// Wishlist: flag products that got cheaper since they were saved.
  final bool showPriceDrop;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tintFor(product.id);
    final heroTag = 'product-$heroScope-${product.id}';
    final inStock = product.stockStatus == StockStatus.inStock;
    final stockColor = inStock ? AppColors.inStock : AppColors.preorder;
    return SizedBox(
      width: width,
      // Card-local blur group: its glass only ever sits over this card's photo.
      child: GlassGroup(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/product/${product.id}', extra: heroTag),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProductBackdrop(color: tint, radius: BorderRadius.circular(22)),
                ),
                Positioned.fill(
                  // Photo runs under the glass strip so the blur has something to frost.
                  bottom: 24,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 34, 12, 0),
                    child: ProductPhotoHero(
                      tag: heroTag,
                      child: NetImage(product.thumbnail, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(left: 10, top: 10, child: RatingPill(product.rating)),
                Positioned(right: 10, top: 10, child: WishlistButton(product.id, glass: true)),
                if (product.onSale)
                  Positioned(
                    left: 10,
                    top: 42,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '-${product.discountPercent}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                if (showPriceDrop)
                  Positioned(
                    left: 10,
                    top: product.onSale ? 68 : 42,
                    child: Consumer(
                      builder: (_, ref, _) {
                        final drop = ref.watch(priceDropProvider(product.id));
                        if (drop == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.inStock, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '↓ ${money(drop)} cheaper',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: GlassBox(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                    borderRadius: BorderRadius.circular(16),
                    tint: AppColors.glass(0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 1),
                        PriceText(product, size: 17),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(inStock ? IconlyBold.tick_square : IconlyBold.send, size: 12, color: stockColor),
                            const SizedBox(width: 3),
                            Text(
                              arrivalShort(product.stockStatus),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: stockColor),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// Two-column product grid as a sliver.
class ProductSliverGrid extends StatelessWidget {
  const ProductSliverGrid(
    this.products, {
    super.key,
    this.heroScope = 'grid',
    this.showPriceDrop = false,
    this.animateKey = '',
  });

  final List<Product> products;
  final String heroScope;
  final bool showPriceDrop;

  /// Change this (e.g. to the selected category) to replay the entrance animation.
  final String animateKey;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 250,
        ),
        itemBuilder: (_, i) {
          final card = ProductCard(
            products[i],
            // Keyed by product: when the list changes, Flutter must not reuse
            // this card (and its Hero) for a different product.
            key: ValueKey('$heroScope-${products[i].id}'),
            heroScope: heroScope,
            showPriceDrop: showPriceDrop,
          );
          // Only the first screenful animates; cards scrolled into view later
          // just appear, so scrolling never feels sluggish.
          if (i >= 6) return card;
          return FadeInUp(
            key: ValueKey('$animateKey-${products[i].id}'),
            delay: Duration(milliseconds: 45 * i),
            child: card,
          );
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll, this.trailing});

  final String title;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ?trailing,
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

/// Rounded pill used for categories and sizes; yellow when selected.
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, required this.onTap, this.dense = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: ShapeDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.line)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 22, vertical: dense ? 9 : 11),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.black : AppColors.ink,
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

/// Black "Filter" pill with a white round icon, from the design.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.onTap, this.active = false});

  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter',
                style: TextStyle(color: AppColors.onInk, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.onInk, shape: BoxShape.circle),
                child: const Icon(IconlyLight.filter, size: 18, color: AppColors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// − 01 + stepper: outlined minus, yellow plus.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.small = false});

  final int value;
  final int min;
  final bool small;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = small ? 26.0 : 32.0;
    Widget btn(IconData icon, bool filled, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.primary : Colors.transparent,
          border: filled ? null : Border.all(color: onTap == null ? AppColors.line : AppColors.ink, width: 1.4),
        ),
        child: Icon(
          icon,
          size: d * 0.6,
          color: onTap == null ? AppColors.line : (filled ? AppColors.black : AppColors.ink),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, false, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: small ? 32 : 40,
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: small ? 14 : 16),
          ),
        ),
        btn(Icons.add, true, value < 20 ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

/// White rounded card used to group content on the beige background.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? const EdgeInsets.fromLTRB(20, 0, 20, 12),
    padding: padding,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyIllustration(icon),
            const SizedBox(height: 22),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Renders loading / error states around the product list.
class ProductsBuilder extends ConsumerWidget {
  const ProductsBuilder({super.key, required this.builder, this.sliver = false});

  final Widget Function(List<Product> products) builder;
  final bool sliver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsProvider);
    Widget wrap(Widget w) => sliver ? SliverFillRemaining(hasScrollBody: false, child: w) : w;
    return async.when(
      data: builder,
      // Grey card outlines instead of a spinner: feels faster on slow networks
      // and the layout doesn't jump when products arrive.
      loading: () => sliver ? const SkeletonProductGrid() : const CustomScrollView(slivers: [SkeletonProductGrid()]),
      error: (e, _) => wrap(
        EmptyState(
          icon: IconlyLight.danger,
          title: 'Could not load products',
          message: 'Check your connection and try again.',
          action: SizedBox(
            width: 160,
            child: FilledButton(onPressed: () => ref.invalidate(productsProvider), child: const Text('Retry')),
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder grid shown while products load.
class SkeletonProductGrid extends StatefulWidget {
  const SkeletonProductGrid({super.key, this.count = 6});

  final int count;

  @override
  State<SkeletonProductGrid> createState() => _SkeletonProductGridState();
}

class _SkeletonProductGridState extends State<SkeletonProductGrid> with SingleTickerProviderStateMixin {
  // One controller drives the whole grid, not one per card.
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      sliver: SliverGrid.builder(
        itemCount: widget.count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 250,
        ),
        itemBuilder: (_, _) => FadeTransition(opacity: opacity, child: const _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(height / 2)),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [bar(44, 24), const Spacer(), bar(30, 30)]),
          Expanded(
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.line, shape: BoxShape.circle),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(110, 12), const SizedBox(height: 8), bar(60, 14), const SizedBox(height: 8), bar(80, 10)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small scale "pop" whenever [value] goes up (e.g. a cart badge count).
class BounceOnChange extends StatefulWidget {
  const BounceOnChange({super.key, required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<BounceOnChange> createState() => _BounceOnChangeState();
}

class _BounceOnChangeState extends State<BounceOnChange> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
  ]).animate(_controller);

  @override
  void didUpdateWidget(BounceOnChange old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

/// Round green "chat on WhatsApp" button.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({super.key, required this.message});

  /// Pre-filled chat text.
  final String message;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: null,
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      tooltip: 'Chat on WhatsApp',
      onPressed: () async {
        final ok = await openWhatsApp(message);
        if (!ok && context.mounted) showGlassToast(context, 'Could not open WhatsApp');
      },
      child: const FaIcon(FontAwesomeIcons.whatsapp, size: 28),
    );
  }
}

/// Soft layered illustration for empty screens: a big yellow blob, a floating
/// card with the icon, and a few decorative dots.
class _EmptyIllustration extends StatefulWidget {
  const _EmptyIllustration(this.icon);

  final IconData icon;

  @override
  State<_EmptyIllustration> createState() => _EmptyIllustrationState();
}

class _EmptyIllustrationState extends State<_EmptyIllustration> with SingleTickerProviderStateMixin {
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot(double size, Color color, {bool ring = false}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? null : color,
        border: ring ? Border.all(color: color, width: 2) : null,
      ),
    );

    return SizedBox(
      width: 190,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
          ),
          Positioned(top: 14, left: 18, child: dot(14, AppColors.primary)),
          Positioned(bottom: 22, right: 16, child: dot(18, AppColors.primary, ring: true)),
          Positioned(top: 30, right: 26, child: dot(8, AppColors.muted.withValues(alpha: 0.5))),
          Positioned(bottom: 14, left: 34, child: dot(6, AppColors.muted.withValues(alpha: 0.5))),
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -6 + 12 * Curves.easeInOut.transform(_float.value)),
              child: Transform.rotate(angle: -0.08, child: child),
            ),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Icon(widget.icon, size: 42, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Straight-line hero movement: the photo glides directly to its new spot.
RectTween growRectTween(Rect? begin, Rect? end) => RectTween(begin: begin, end: end);

/// Product photo that flies from a card into the product page.
class ProductPhotoHero extends StatelessWidget {
  const ProductPhotoHero({super.key, required this.tag, required this.child});

  final String tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => Hero(tag: tag, createRectTween: growRectTween, child: child);
}

/// Rounded tinted background behind a product photo.
class ProductBackdrop extends StatelessWidget {
  const ProductBackdrop({super.key, required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: radius),
  );
}

/// Fades a widget in while it rises a little. Plays once when first built.
class FadeInUp extends StatefulWidget {
  const FadeInUp({super.key, required this.child, this.delay = Duration.zero, this.offset = 24});

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}
