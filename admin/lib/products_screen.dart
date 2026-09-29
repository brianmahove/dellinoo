import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'glass_dialog.dart';
import 'theme.dart';
import 'iconly.dart';

/// The same 10 fixed category ids the customer app uses (see mockCategories
/// in the main app's lib/data/mock_data.dart) — categories aren't their own
/// Firestore collection, so this list has to be kept in sync by hand.
const _categoryIds = [
  'women',
  'men',
  'kids',
  'shoes',
  'handbags',
  'phones',
  'watches',
  'laptops',
  'games',
  'electronics',
];
const _categoryLabels = {
  'women': 'Women',
  'men': 'Men',
  'kids': 'Kids',
  'shoes': 'Shoes',
  'handbags': 'Handbags',
  'phones': 'Phones',
  'watches': 'Watches',
  'laptops': 'Laptops',
  'games': 'Games',
  'electronics': 'Electronics',
};
const _stockStatuses = ['inStock', 'preorder'];
const _stockFilters = {'all': 'All', 'inStock': 'In stock', 'preorder': 'Preorder'};

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  String _category = 'all';
  String _stockFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) {
    return showGlassDialog(
      context: context,
      builder: (context) => _ProductForm(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(IconlyLight.plus),
        label: const Text('Add product'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterRow(
                search: _search,
                onSearchChanged: () => setState(() {}),
                category: _category,
                onCategorySelect: (c) => setState(() => _category = c),
                stockFilter: _stockFilter,
                onStockFilterChanged: (s) => setState(() => _stockFilter = s),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('products').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final query = _search.text.trim().toLowerCase();
                    final docs = snapshot.data!.docs.where((doc) {
                      final d = doc.data();
                      if (_category != 'all' && d['categoryId'] != _category) return false;
                      if (_stockFilter != 'all' && d['stockStatus'] != _stockFilter) return false;
                      if (query.isNotEmpty && !('${d['name']}').toLowerCase().contains(query)) return false;
                      return true;
                    }).toList();
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(IconlyLight.bag, size: 40, color: AppColors.muted),
                            const SizedBox(height: 10),
                            Text('No products found', style: TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisExtent: 300,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, i) => _ProductCard(
                        docs[i],
                        accent: i.isEven ? AppColors.accentOrange : AppColors.primary,
                        onEdit: () => _openForm(doc: docs[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.search,
    required this.onSearchChanged,
    required this.category,
    required this.onCategorySelect,
    required this.stockFilter,
    required this.onStockFilterChanged,
  });

  final TextEditingController search;
  final VoidCallback onSearchChanged;
  final String category;
  final ValueChanged<String> onCategorySelect;
  final String stockFilter;
  final ValueChanged<String> onStockFilterChanged;

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  late bool _searching = widget.search.text.isNotEmpty;

  void _toggle() {
    setState(() => _searching = !_searching);
    if (!_searching && widget.search.text.isNotEmpty) {
      widget.search.clear();
      widget.onSearchChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CategoryRow(
      selected: widget.category,
      onSelect: widget.onCategorySelect,
      stockFilter: widget.stockFilter,
      onStockFilterChanged: widget.onStockFilterChanged,
      searching: _searching,
      onToggleSearch: _toggle,
      searchField: SizedBox(
        width: 240,
        height: 38,
        child: TextField(
          controller: widget.search,
          autofocus: true,
          onChanged: (_) => widget.onSearchChanged(),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search products...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selected,
    required this.onSelect,
    required this.stockFilter,
    required this.onStockFilterChanged,
    required this.searching,
    required this.onToggleSearch,
    required this.searchField,
  });

  final bool searching;
  final VoidCallback onToggleSearch;
  final Widget searchField;
  final String selected;
  final ValueChanged<String> onSelect;
  final String stockFilter;
  final ValueChanged<String> onStockFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryPill(label: 'All Products', selected: selected == 'all', onTap: () => onSelect('all')),
                for (final c in _categoryIds) ...[
                  const SizedBox(width: 10),
                  _CategoryPill(label: _categoryLabels[c]!, selected: selected == c, onTap: () => onSelect(c)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (searching) ...[searchField, const SizedBox(width: 8)],
        Tooltip(
          message: searching ? 'Close search' : 'Search products',
          child: InkWell(
            onTap: onToggleSearch,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: searching ? AppColors.primarySoft : null,
                border: searching ? null : Border.all(color: AppColors.line),
              ),
              child: Icon(
                searching ? Icons.close : IconlyLight.search,
                size: 18,
                color: searching ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButton<String>(
              value: stockFilter,
              isDense: true,
              icon: Icon(IconlyLight.arrow_down_2, size: 18, color: AppColors.muted),
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13),
              items: [for (final e in _stockFilters.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => onStockFilterChanged(v!),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? AppColors.onInk : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.doc, {required this.onEdit, required this.accent});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit;
  final Color accent;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${doc.data()['name']}" will be removed from the catalogue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final inStock = d['stockStatus'] == 'inStock';
    final isNew = d['isNew'] as bool? ?? false;
    final price = (d['price'] as num?)?.toDouble() ?? 0;
    final oldPrice = (d['oldPrice'] as num?)?.toDouble();
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.field,
                      child: Image.network(
                        d['thumbnail'] as String? ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(IconlyLight.image, color: AppColors.muted),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _RoundIconButton(
                        icon: isNew ? IconlyBold.heart : IconlyLight.heart,
                        iconColor: isNew ? AppColors.accentOrange : AppColors.ink,
                        tooltip: 'Toggle "New" badge',
                        onTap: () => doc.reference.update({'isNew': !isNew}),
                      ),
                    ),
                    if (!inStock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: StatusPill(
                          label: 'PREORDER',
                          color: AppColors.preorder,
                          background: AppColors.preorderSoft,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['name'] as String? ?? '(no name)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: accent),
                        ),
                        if (oldPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '\$${oldPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        const Spacer(),
                        _RoundIconButton(
                          icon: Icons.north_east,
                          iconColor: AppColors.onPrimary,
                          background: accent,
                          tooltip: 'Edit product',
                          onTap: onEdit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.iconColor, this.background, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background ?? Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 15, color: iconColor ?? AppColors.ink),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _d?['name'] as String? ?? '');
  late final _brand = TextEditingController(text: _d?['brand'] as String? ?? 'Dellinoo Select');
  late final _price = TextEditingController(text: (_d?['price'] as num?)?.toString() ?? '');
  late final _oldPrice = TextEditingController(text: (_d?['oldPrice'] as num?)?.toString() ?? '');
  late final _thumbnail = TextEditingController(text: _d?['thumbnail'] as String? ?? '');
  late final _description = TextEditingController(text: _d?['description'] as String? ?? '');
  late final _sizes = TextEditingController(
    text: (() {
      final groups = _d?['variantGroups'] as List?;
      if (groups == null || groups.isEmpty) return '';
      return List<String>.from((groups.first as Map)['options'] as List? ?? const []).join(', ');
    })(),
  );
  late String _categoryId = _d?['categoryId'] as String? ?? _categoryIds.first;
  late String _stockStatus = _d?['stockStatus'] as String? ?? _stockStatuses.first;
  late bool _isNew = _d?['isNew'] as bool? ?? false;
  late DateTime? _saleEndsAt = (_d?['saleEndsAt'] as Timestamp?)?.toDate();
  bool _saving = false;

  Map<String, dynamic>? get _d => widget.doc?.data();

  @override
  void dispose() {
    for (final c in [_name, _brand, _price, _oldPrice, _thumbnail, _description, _sizes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final sizes = _sizes.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final thumbnail = _thumbnail.text.trim();
    final data = {
      'name': _name.text.trim(),
      'brand': _brand.text.trim(),
      'categoryId': _categoryId,
      'price': double.parse(_price.text.trim()),
      'oldPrice': _oldPrice.text.trim().isEmpty ? null : double.parse(_oldPrice.text.trim()),
      'stockStatus': _stockStatus,
      'thumbnail': thumbnail,
      'images': [thumbnail],
      'description': _description.text.trim(),
      'variantGroups': sizes.isEmpty
          ? <Map<String, dynamic>>[]
          : [
              {'name': 'Size', 'options': sizes},
            ],
      'rating': (_d?['rating'] as num?) ?? 0,
      'soldCount': (_d?['soldCount'] as num?) ?? 0,
      'isNew': _isNew,
      // Only meaningful with an old price; null clears a finished flash sale.
      'saleEndsAt': _oldPrice.text.trim().isEmpty || _saleEndsAt == null ? null : Timestamp.fromDate(_saleEndsAt!),
    };
    final products = FirebaseFirestore.instance.collection('products');
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await products.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: Text(widget.doc == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Gap between fields so labels/helper text don't collide.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Brand'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [for (final c in _categoryIds) DropdownMenuItem(value: c, child: Text(_categoryLabels[c]!))],
                  onChanged: (v) => setState(() => _categoryId = v!),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        decoration: const InputDecoration(labelText: 'Price (USD)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Required number' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _oldPrice,
                        decoration: const InputDecoration(labelText: 'Old price (optional)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) =>
                            v!.trim().isEmpty || double.tryParse(v.trim()) != null ? null : 'Must be a number',
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _stockStatus,
                  decoration: const InputDecoration(labelText: 'Stock status'),
                  items: [
                    for (final s in _stockStatuses)
                      DropdownMenuItem(value: s, child: Text(s == 'inStock' ? 'In stock' : 'From China (preorder)')),
                  ],
                  onChanged: (v) => setState(() => _stockStatus = v!),
                ),
                TextFormField(
                  controller: _thumbnail,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    helperText: 'Paste a hosted image URL — file upload needs Firebase Storage (Blaze plan).',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _sizes,
                  decoration: const InputDecoration(labelText: 'Sizes (comma-separated, leave blank if none)'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _saleEndsAt == null
                              ? 'Flash sale: no end time (needs an old price)'
                              : 'Flash sale ends ${_saleEndsAt!.toLocal().toString().substring(0, 16)}',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _saleEndsAt ?? now.add(const Duration(days: 1)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 23, minute: 59),
                          );
                          if (time == null) return;
                          setState(
                            () => _saleEndsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute),
                          );
                        },
                        child: Text(_saleEndsAt == null ? 'Set end' : 'Change'),
                      ),
                      if (_saleEndsAt != null)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () => setState(() => _saleEndsAt = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  value: _isNew,
                  onChanged: (v) => setState(() => _isNew = v ?? false),
                  title: const Text('Show "New" badge'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
