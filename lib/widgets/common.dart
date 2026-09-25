import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        errorWidget: (_, _, _) => const Center(child: Icon(IconlyLight.image, color: AppColors.muted)),
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
    this.color = Colors.white,
    this.iconColor = AppColors.ink,
    this.glass = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final double size;
  final Color color;
  final Color iconColor;

  /// Frosted instead of solid — for buttons that float over photos.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: glass ? Colors.transparent : color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              backgroundColor: AppColors.danger,
              label: Text('$badge'),
              child: Icon(icon, size: size * 0.46, color: iconColor),
            ),
          ),
        ),
      ),
    );
    if (!glass) return button;
    return GlassBox(
      borderRadius: BorderRadius.circular(size / 2),
      tint: Colors.white.withValues(alpha: 0.55),
      child: button,
    );
  }
}

class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key});

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: IconlyLight.arrow_left_2,
    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
  );
}

/// Standard page header: back button, title, optional trailing widget.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({super.key, required this.title, this.trailing, this.showBack = true, this.bottom});

  final String title;
  final Widget? trailing;
  final bool showBack;
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
          if (showBack) ...[const BackCircleButton(), const SizedBox(width: 14)],
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
  const SearchPill({super.key, this.onTap, this.controller, this.onChanged, this.autofocus = false});

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final editable = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 20, right: 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            Expanded(
              child: editable
                  ? TextField(
                      controller: controller,
                      autofocus: autofocus,
                      onChanged: onChanged,
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
                  : const Text('Search here...', style: TextStyle(color: AppColors.muted, fontSize: 15)),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(IconlyLight.search, color: AppColors.ink, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key, this.compact = false});

  final StockStatus status;
  final bool compact;

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
              compact && !inStock ? '2–3 weeks' : status.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 11 : 12, color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceText extends StatelessWidget {
  const PriceText(this.product, {super.key, this.size = 16, this.color = AppColors.ink});

  final Product product;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onDark = color != AppColors.ink;
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
    final saved = ref.watch(wishlistProvider.select((s) => s.contains(productId)));
    return CircleIconButton(
      icon: saved ? IconlyBold.heart : IconlyLight.heart,
      iconColor: saved ? AppColors.danger : AppColors.ink,
      size: size,
      glass: glass,
      onTap: () => ref.read(wishlistProvider.notifier).toggle(productId),
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
      tint: Colors.white.withValues(alpha: 0.55),
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
  const ProductCard(this.product, {super.key, this.width});

  final Product product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tintFor(product.id);
    final inStock = product.stockStatus == StockStatus.inStock;
    final stockColor = inStock ? AppColors.inStock : AppColors.preorder;
    return SizedBox(
      width: width,
      // Card-local blur group: its glass only ever sits over this card's photo.
      child: GlassGroup(
        child: Material(
          color: tint,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/product/${product.id}'),
            child: Stack(
              children: [
                Positioned.fill(
                  // Photo runs under the glass strip so the blur has something to frost.
                  bottom: 24,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 34, 12, 0),
                    child: NetImage(product.thumbnail, fit: BoxFit.contain),
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
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '-${product.discountPercent}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: GlassBox(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                    borderRadius: BorderRadius.circular(16),
                    tint: Colors.white.withValues(alpha: 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 1),
                        PriceText(product, size: 17),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(inStock ? IconlyBold.tick_square : IconlyBold.send, size: 12, color: stockColor),
                            const SizedBox(width: 3),
                            Text(
                              inStock ? 'In stock' : 'Arrives in 2–3 weeks',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stockColor),
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
  const ProductSliverGrid(this.products, {super.key});

  final List<Product> products;

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
        itemBuilder: (_, i) => ProductCard(products[i]),
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
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 22, vertical: dense ? 9 : 11),
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
              const Text(
                'Filter',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: active ? AppColors.primary : Colors.white, shape: BoxShape.circle),
                child: const Icon(IconlyLight.filter, size: 18, color: AppColors.ink),
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
        child: Icon(icon, size: d * 0.6, color: onTap == null ? AppColors.line : AppColors.ink),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.ink),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
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
      loading: () => wrap(
        const Center(
          child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
        ),
      ),
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
