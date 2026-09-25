import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../core/iconly.dart';

enum ProductCollection { all, deals, inStock, newIn }

enum StockFilter {
  all('All'),
  inStock('In stock'),
  preorder('Arrives 2–3 weeks');

  const StockFilter(this.label);
  final String label;

  bool matches(Product p) => switch (this) {
    all => true,
    inStock => p.stockStatus == StockStatus.inStock,
    preorder => p.stockStatus == StockStatus.preorder,
  };
}

enum SortOption {
  recommended('Recommended'),
  popular('Most popular'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low');

  const SortOption(this.label);
  final String label;

  List<Product> apply(List<Product> list) {
    final l = [...list];
    switch (this) {
      case recommended:
        break;
      case priceLow:
        l.sort((a, b) => a.price.compareTo(b.price));
      case priceHigh:
        l.sort((a, b) => b.price.compareTo(a.price));
      case popular:
        l.sort((a, b) => b.soldCount.compareTo(a.soldCount));
    }
    return l;
  }
}

class ProductFilter {
  const ProductFilter({this.stock = StockFilter.all, this.sort = SortOption.recommended});

  final StockFilter stock;
  final SortOption sort;

  bool get isActive => stock != StockFilter.all || sort != SortOption.recommended;
  List<Product> apply(List<Product> list) => sort.apply(list.where(stock.matches).toList());
}

Future<ProductFilter?> showFilterSheet(BuildContext context, ProductFilter current) {
  return showGlassBottomSheet<ProductFilter>(context: context, builder: (_) => _FilterSheet(current));
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.initial);

  final ProductFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late StockFilter _stock = widget.initial.stock;
  late SortOption _sort = widget.initial.sort;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Filter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _stock = StockFilter.all;
                    _sort = SortOption.recommended;
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in StockFilter.values)
                  PillChip(label: f.label, selected: _stock == f, dense: true, onTap: () => setState(() => _stock = f)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in SortOption.values)
                  PillChip(label: s.label, selected: _sort == s, dense: true, onTap: () => setState(() => _sort = s)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ProductFilter(stock: _stock, sort: _sort)),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.title, this.categoryId, this.collection = ProductCollection.all});

  final String title;
  final String? categoryId;
  final ProductCollection collection;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  ProductFilter _filter = const ProductFilter();

  bool _inCollection(Product p) => switch (widget.collection) {
    ProductCollection.all => true,
    ProductCollection.deals => p.onSale,
    ProductCollection.inStock => p.stockStatus == StockStatus.inStock,
    ProductCollection.newIn => p.isNew,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageHeader(title: widget.title),
      body: ProductsBuilder(
        builder: (all) {
          final base = all
              .where((p) => widget.categoryId == null || p.categoryId == widget.categoryId)
              .where(_inCollection)
              .toList();
          final products = _filter.apply(base);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${products.length} items',
                          style: TextStyle(color: AppColors.muted, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilterButton(
                        active: _filter.isActive,
                        onTap: () async {
                          final f = await showFilterSheet(context, _filter);
                          if (f != null) setState(() => _filter = f);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: IconlyLight.search,
                    title: 'Nothing here yet',
                    message: 'Try a different filter.',
                  ),
                )
              else
                ProductSliverGrid(products, animateKey: '${_filter.stock.name}-${_filter.sort.name}'),
            ],
          );
        },
      ),
    );
  }
}
