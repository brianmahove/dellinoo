import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
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
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _addToCart(Product p) {
    final missing = p.variantGroups.where((g) => !_options.containsKey(g.name)).firstOrNull;
    if (missing != null) {
      setState(() => _showErrors = true);
      showGlassToast(context, 'Please select a ${missing.name.toLowerCase()}');
      return false;
    }
    ref.read(cartProvider.notifier).add(p, {
      for (final g in p.variantGroups) g.name: _options[g.name]!,
    }, quantity: _qty);
    return true;
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: top + 330,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: top + 60,
                    bottom: 10,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: product.images.length,
                      onPageChanged: (i) => setState(() => _image = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: NetImage(product.images[i], fit: BoxFit.contain, placeholderUrl: product.thumbnail),
                      ),
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
                        CircleIconButton(icon: IconlyLight.buy, badge: cartCount, onTap: () => context.go('/cart')),
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? AppColors.primary : Colors.white, width: 2.5),
                          ),
                          child: ClipOval(child: NetImage(product.images[i], fit: BoxFit.contain)),
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
              decoration: const BoxDecoration(
                color: Colors.white,
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
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('From: ', style: TextStyle(color: AppColors.muted, fontSize: 16)),
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
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
                            onTap: () => setState(() => _options[g.name] = o),
                          ),
                      ],
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
                              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                      style: const TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _InfoRow(Icons.local_shipping_outlined, 'Delivery across Zimbabwe — fee by area at checkout'),
                  const _InfoRow(IconlyLight.wallet, 'EcoCash, OneMoney, InnBucks or card'),
                ],
              ),
            ),
          ),
          if (similar.isNotEmpty)
            SliverMainAxisGroup(
              slivers: [
                const SliverToBoxAdapter(
                  child: ColoredBox(color: Colors.white, child: SectionHeader('You may also like')),
                ),
                DecoratedSliver(
                  decoration: const BoxDecoration(color: Colors.white),
                  sliver: ProductSliverGrid(similar),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_addToCart(product)) {
                        showGlassToast(
                          context,
                          'Added to cart',
                          actionLabel: 'View cart',
                          onAction: () => context.go('/cart'),
                        );
                      }
                    },
                    child: const Text('Add to Cart'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_addToCart(product)) context.push('/checkout');
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
        Text(' (${product.soldCount} sold)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
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
