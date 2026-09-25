import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'size_guide.dart';
import '../../core/iconly.dart';

/// Swatch colours for "Colour" variants; unknown names fall back to grey.
const _swatches = {
  'black': Color(0xFF1E1E22),
  'white': Color(0xFFF4F4F4),
  'blue': Color(0xFF3A6B87),
  'brown': Color(0xFF8B5E3C),
  'cream': Color(0xFFE3C9A8),
  'grey': Color(0xFFB5B5B8),
  'gray': Color(0xFFB5B5B8),
  'red': Color(0xFFC62828),
  'gold': Color(0xFFD4AF37),
};

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.heroTag});

  final String productId;

  /// Tag of the card photo this page was opened from, so the photo can fly in.
  final String? heroTag;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final Map<String, String> _options = {};
  final _pages = PageController();
  int _image = 0;
  int _qty = 1;
  bool _showErrors = false;
  bool _expanded = false;
  final _cartKey = GlobalKey();
  final _imageKey = GlobalKey();

  static const _headerRadius = BorderRadius.vertical(bottom: Radius.circular(36));

  /// Extra photos the user chose to load while data saver is on.
  final Set<int> _loadedPhotos = {};

  @override
  void initState() {
    super.initState();
    // Remember for the "Recently viewed" row on Home. Wait until the open
    // transition has finished: changing Home while the photo is flying
    // reshuffles its cards and breaks the Hero animation.
    final recent = ref.read(recentlyViewedProvider.notifier);
    Future.delayed(const Duration(milliseconds: 900), () => recent.add(widget.productId));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Validates variants; on success returns the options to add, else null.
  Map<String, String>? _selectedOptions(Product p) {
    final missing = p.variantGroups.where((g) => !_options.containsKey(g.name)).firstOrNull;
    if (missing != null) {
      HapticFeedback.heavyImpact();
      setState(() => _showErrors = true);
      showGlassToast(context, 'Please select a ${missing.name.toLowerCase()}');
      return null;
    }
    return {for (final g in p.variantGroups) g.name: _options[g.name]!};
  }

  /// "Add to Cart": the photo flies into the cart button, then the item is
  /// added so the badge bounces as it lands.
  void _addWithAnimation(Product p) {
    final options = _selectedOptions(p);
    if (options == null) return;
    HapticFeedback.mediumImpact();
    final cart = ref.read(cartProvider.notifier);
    final qty = _qty;
    void add() {
      cart.add(p, options, quantity: qty);
      HapticFeedback.lightImpact();
      if (mounted) {
        showGlassToast(context, 'Added to cart', actionLabel: 'View cart', onAction: () => context.go('/cart'));
      }
    }

    final from = _centerOf(_imageKey);
    final to = _centerOf(_cartKey);
    if (from == null || to == null) return add();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyToCart(
        imageUrl: p.thumbnail,
        from: from,
        to: to,
        onDone: () {
          entry.remove();
          add();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _openGallery(Product p) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => _Gallery(product: p, initialIndex: _image, heroTag: widget.heroTag),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));
    if (product == null) {
      return Scaffold(
        appBar: const PageHeader(title: ''),
        body: ref.watch(productsProvider).isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                icon: IconlyLight.bag_2,
                title: 'Product not found',
                message: 'It may have been removed.',
              ),
      );
    }
    final cartCount = ref.watch(cartCountProvider);
    final similar = (ref.watch(productsProvider).value ?? const <Product>[])
        .where((p) => p.categoryId == product.categoryId && p.id != product.id)
        .take(4)
        .toList();
    final colourGroup = product.variantGroups.where((g) => g.name == 'Colour').firstOrNull;
    final otherGroups = product.variantGroups.where((g) => g != colourGroup);
    final top = MediaQuery.paddingOf(context).top;
    final dataSaver = ref.watch(dataSaverProvider);
    // Data saver: first photo uses the small thumbnail; others load on tap.
    bool deferred(int i) => dataSaver && i > 0 && !_loadedPhotos.contains(i);
    String photoUrl(int i) => dataSaver && i == 0 ? product.thumbnail : product.images[i];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: top + 330,
              child: Stack(
                children: [
                  // Tinted header in the product's colour; fades in with the page.
                  Positioned.fill(
                    child: ProductBackdrop(color: AppColors.tintFor(product.id), radius: _headerRadius),
                  ),
                  Positioned.fill(
                    top: top + 60,
                    bottom: 10,
                    child: PageView.builder(
                      key: _imageKey,
                      controller: _pages,
                      itemCount: product.images.length,
                      onPageChanged: (i) => setState(() => _image = i),
                      itemBuilder: (_, i) {
                        if (deferred(i)) {
                          return _TapToLoadPhoto(onTap: () => setState(() => _loadedPhotos.add(i)));
                        }
                        Widget image = NetImage(photoUrl(i), fit: BoxFit.contain, placeholderUrl: product.thumbnail);
                        if (i == 0 && widget.heroTag != null) {
                          image = ProductPhotoHero(tag: widget.heroTag!, child: image);
                        }
                        return GestureDetector(
                          onTap: () => _openGallery(product),
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: image),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: top + 12,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        const BackCircleButton(),
                        const Spacer(),
                        CircleIconButton(
                          key: _cartKey,
                          icon: IconlyLight.buy,
                          badge: cartCount,
                          onTap: () => context.go('/cart'),
                        ),
                        const SizedBox(width: 10),
                        WishlistButton(product.id, size: 46),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (product.images.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: product.images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final selected = i == _image;
                    return Center(
                      child: GestureDetector(
                        onTap: () =>
                            _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 68 : 56,
                          height: selected ? 68 : 56,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? AppColors.primary : AppColors.surface, width: 2.5),
                          ),
                          child: deferred(i)
                              ? Icon(IconlyLight.image, color: AppColors.muted, size: 20)
                              : ClipOval(child: NetImage(photoUrl(i), fit: BoxFit.contain)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, height: 1.2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: QuantityStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.brand,
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('From: ', style: TextStyle(color: AppColors.muted, fontSize: 16)),
                      Expanded(child: PriceText(product, size: 20)),
                      if (colourGroup != null)
                        for (final o in colourGroup.options)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _Swatch(
                              color: _swatches[o.toLowerCase()] ?? AppColors.muted,
                              selected: _options['Colour'] == o,
                              onTap: () => setState(() => _options['Colour'] = o),
                            ),
                          ),
                    ],
                  ),
                  if (colourGroup != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _options['Colour'] ?? (_showErrors ? 'Pick a colour' : 'Colour'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _showErrors && _options['Colour'] == null ? AppColors.danger : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  StockBadge(product.stockStatus),
                  const SizedBox(height: 4),
                  Text(
                    product.stockStatus == StockStatus.inStock
                        ? 'Already in Zimbabwe — order today, delivered in 1–3 days.'
                        : 'Ordered from our supplier in China after you pay.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  for (final g in otherGroups) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        if (_showErrors && _options[g.name] == null)
                          const Text(
                            '  required',
                            style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        const Spacer(),
                        if (g == otherGroups.first) _Rating(product),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in g.options)
                          PillChip(
                            label: o,
                            dense: true,
                            selected: _options[g.name] == o,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _options[g.name] = o);
                            },
                          ),
                      ],
                    ),
                    if (g == otherGroups.first && hasSizeGuide(product.categoryId))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => showSizeGuide(context, product.categoryId),
                          icon: const Icon(Icons.straighten_rounded, size: 18),
                          label: const Text('Size guide'),
                        ),
                      ),
                  ],
                  if (otherGroups.isEmpty) ...[const SizedBox(height: 16), _Rating(product)],
                  const SizedBox(height: 22),
                  const Text('Description', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text.rich(
                      TextSpan(
                        text: _expanded || product.description.length < 90
                            ? '${product.description} '
                            : '${product.description.substring(0, 90)}... ',
                        children: [
                          if (product.description.length >= 90)
                            TextSpan(
                              text: _expanded ? 'Show less' : 'Read more',
                              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                      style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _TrustBadges(product),
                  const SizedBox(height: 8),
                  const _InfoRow(Icons.local_shipping_outlined, 'Delivery across Zimbabwe — fee by area at checkout'),
                  const _InfoRow(IconlyLight.wallet, 'EcoCash, OneMoney, InnBucks or card'),
                ],
              ),
            ),
          ),
          if (similar.isNotEmpty)
            SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: ColoredBox(color: AppColors.surface, child: SectionHeader('You may also like')),
                ),
                DecoratedSliver(
                  decoration: BoxDecoration(color: AppColors.surface),
                  sliver: ProductSliverGrid(similar, heroScope: 'similar'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: WhatsAppButton(
        message: 'Hi Dellinoo, I am interested in "${product.name}" (${money(product.price)}). Is it available?',
      ),
      bottomNavigationBar: Container(
        color: AppColors.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _addWithAnimation(product), child: const Text('Add to Cart')),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final options = _selectedOptions(product);
                      if (options == null) return;
                      HapticFeedback.mediumImpact();
                      ref.read(cartProvider.notifier).add(product, options, quantity: _qty);
                      context.push('/checkout');
                    },
                    child: const Text('Buy Now'),
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

class _Rating extends StatelessWidget {
  const _Rating(this.product);

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(IconlyBold.star, color: AppColors.primary, size: 20),
        const SizedBox(width: 2),
        Text('${product.rating.toStringAsFixed(1)}/5', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(' (${product.soldCount} sold)', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: selected ? 2 : 1),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail that arcs from the product photo into the cart button.
class _FlyToCart extends StatefulWidget {
  const _FlyToCart({required this.imageUrl, required this.from, required this.to, required this.onDone});

  final String imageUrl;
  final Offset from;
  final Offset to;
  final VoidCallback onDone;

  @override
  State<_FlyToCart> createState() => _FlyToCartState();
}

class _FlyToCartState extends State<_FlyToCart> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          // Quadratic curve with the control point above both ends -> a nice arc.
          final control = Offset((widget.from.dx + widget.to.dx) / 2, math.min(widget.from.dy, widget.to.dy) - 120);
          final pos = Offset(
            (1 - t) * (1 - t) * widget.from.dx + 2 * (1 - t) * t * control.dx + t * t * widget.to.dx,
            (1 - t) * (1 - t) * widget.from.dy + 2 * (1 - t) * t * control.dy + t * t * widget.to.dy,
          );
          final size = 150 - 124 * t;
          return Stack(
            children: [
              Positioned(
                left: pos.dx - size / 2,
                top: pos.dy - size / 2,
                width: size,
                height: size,
                child: Opacity(
                  opacity: t > 0.85 ? (1 - t) / 0.15 : 1,
                  child: Container(
                    padding: EdgeInsets.all(size * 0.1),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16)],
                    ),
                    child: ClipOval(child: NetImage(widget.imageUrl, fit: BoxFit.contain)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full-screen photo viewer: swipe between photos, pinch or double-tap to zoom.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.product, required this.initialIndex, this.heroTag});

  final Product product;
  final int initialIndex;
  final String? heroTag;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _zoom = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails d) {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
    } else {
      final p = d.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
    setState(() => _zoomed = !_zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            // Don't swipe pages while zoomed in; pan the photo instead.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: images.length,
            onPageChanged: (i) {
              _zoom.value = Matrix4.identity();
              setState(() {
                _index = i;
                _zoomed = false;
              });
            },
            itemBuilder: (_, i) {
              Widget image = NetImage(images[i], fit: BoxFit.contain, placeholderUrl: widget.product.thumbnail);
              if (i == 0 && widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);
              return GestureDetector(
                onDoubleTapDown: _toggleZoom,
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: i == _index ? _zoom : null,
                  minScale: 1,
                  maxScale: 4,
                  onInteractionEnd: (_) => setState(() => _zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01),
                  child: Center(child: image),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GlassBox(
                    borderRadius: BorderRadius.circular(23),
                    tint: Colors.white.withValues(alpha: 0.2),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  GlassBox(
                    borderRadius: BorderRadius.circular(20),
                    tint: Colors.white.withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      '${_index + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: SafeArea(
              child: Text(
                'Pinch or double-tap to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a photo not downloaded yet because data saver is on.
class _TapToLoadPhoto extends StatelessWidget {
  const _TapToLoadPhoto({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IconlyLight.download, color: AppColors.ink),
              const SizedBox(height: 8),
              const Text('Tap to load photo', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Data saver is on', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reassurance row: genuine, warranty/returns, secure payment.
/// TODO: confirm the warranty and returns policy with the client.
class _TrustBadges extends StatelessWidget {
  const _TrustBadges(this.product);

  final Product product;

  static const _warrantyCategories = {'phones', 'laptops', 'electronics', 'watches'};

  @override
  Widget build(BuildContext context) {
    final warranty = _warrantyCategories.contains(product.categoryId);
    final badges = [
      (IconlyBold.shield_done, 'Genuine', 'product'),
      warranty ? (IconlyBold.tick_square, '6-month', 'warranty') : (IconlyBold.swap, '7-day', 'easy returns'),
      (IconlyBold.lock, 'Secure', 'payment'),
    ];
    return Row(
      children: [
        for (final (i, (icon, title, sub)) in badges.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  Icon(icon, color: AppColors.accent, size: 24),
                  const SizedBox(height: 6),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
