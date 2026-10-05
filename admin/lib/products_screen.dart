import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'glass_dialog.dart';
import 'photo_cropper.dart';
import 'photos.dart';
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
    return showFormPage(
      context: context,
      builder: (context) => _ProductForm(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      floatingActionButton: compact
          ? FloatingActionButton.small(
              tooltip: 'Add product',
              onPressed: () => _openForm(),
              child: const Icon(IconlyLight.plus),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(IconlyLight.plus),
              label: const Text('Add product'),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 14 : 24, 12, compact ? 14 : 24, 0),
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
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisExtent: compact ? 250 : 300,
                        crossAxisSpacing: compact ? 10 : 18,
                        mainAxisSpacing: compact ? 10 : 18,
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
        height: 38,
        child: TextField(
          controller: widget.search,
          // Focus on open only where the field appears on demand (desktop); on a phone it's always
          // there, and grabbing focus would pop the keyboard whenever you open the page.
          autofocus: MediaQuery.sizeOf(context).width >= 720,
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
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final pills = SingleChildScrollView(
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
    );
    final controls = _controls(toggle: !narrow);
    if (!narrow) {
      // Desktop: pills and controls share one row.
      return Row(
        children: [
          Expanded(child: pills),
          const SizedBox(width: 12),
          if (searching) SizedBox(width: 240, child: searchField),
          ...controls,
        ],
      );
    }
    // Phone: pills get their own scrolling row; below it the search field is always
    // shown and takes all the free width next to the stock filter (no toggle icon).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pills,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            ...controls,
          ],
        ),
      ],
    );
  }

  /// The search toggle and stock-status filter.
  List<Widget> _controls({required bool toggle}) {
    return [
      if (toggle) ...[
        if (searching) const SizedBox(width: 8),
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
      ],
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
    ];
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 18, vertical: compact ? 7 : 9),
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
    if (ok != true) return;
    await doc.reference.delete();
    await deletePhotos(photosOf(doc.data()));
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
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 5 : 7),
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

  // The first photo is the cover (the product's thumbnail). Photos uploaded
  // while the form is open are deleted again if it's closed without saving;
  // saved photos the admin removed are deleted only once the save succeeds.
  late final _original = photosOf(_d);
  late final List<ProductPhoto> _photos = List.of(_original);
  final _uploadedHere = <ProductPhoto>[];
  int _uploading = 0;
  String? _photoError;
  bool _saved = false;
  static const _maxPhotos = 6;
  // Per photo URL: true = already see-through, false = has a background,
  // missing = not checked yet / couldn't tell.
  final _transparent = <String, bool>{};
  final _removingBg = <String>{};
  // Cut-out photo URL -> the photo it replaced, so a bad cut-out can be undone.
  final _bgOriginal = <String, ProductPhoto>{};
  // Per photo URL: the background detected from the photo (a `photoBgs`
  // value, see PhotoBg), if it has a flat or fading one.
  final _suggestedBg = <String, String>{};
  String? _photoNote;

  Map<String, dynamic>? get _d => widget.doc?.data();

  bool get _busy => _uploading > 0 || _removingBg.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Products saved before photo colours existed get them suggested too;
    // once a product has `photoBgs`, the saved choices are left alone.
    final autoBg = _d?['photoBgs'] is! List;
    for (final p in _photos) {
      _checkPhoto(p, autoBg: autoBg);
    }
  }

  /// Checks whether [p] is see-through and what its background is. With
  /// [autoBg], a photo on a flat or fading background gets the same behind it
  /// in the app (so a white-background photo sits on white, not the tint).
  void _checkPhoto(ProductPhoto p, {bool autoBg = true}) {
    analyzePhoto(p.thumb).then((a) {
      if (a == null || !mounted) return;
      setState(() {
        _transparent[p.url] = a.transparent;
        final bg = a.suggestedBg;
        if (bg == null) return;
        _suggestedBg[p.url] = bg;
        final i = _photos.indexWhere((x) => x.url == p.url);
        if (autoBg && i >= 0 && _photos[i].bg == null) _photos[i] = _photos[i].withBg(bg);
      });
    });
  }

  Future<void> _pickBg(ProductPhoto p) async {
    final choice = await _showBgPicker(context, p, _suggestedBg[p.url]);
    if (choice == null || !mounted) return;
    final i = _photos.indexWhere((x) => x.url == p.url);
    if (i < 0) return;
    setState(() => _photos[i] = _photos[i].withBg(choice.value));
    if (choice.crop) await _cropPhoto(_photos[i]);
  }

  /// Crops [p] and uploads the result as a new photo in its place (same
  /// background setting). UNDO puts the original back, like REMOVE BG.
  Future<void> _cropPhoto(ProductPhoto p) async {
    final area = await showPhotoCropper(context, p);
    if (area == null || !mounted) return;
    setState(() {
      _removingBg.add(p.url);
      _photoError = null;
      _photoNote = 'Cropping…';
    });
    try {
      final uploaded = await uploadProductPhoto(await cropPhoto(p.url, area));
      final photo = uploaded.withBg(p.bg);
      _uploadedHere.add(uploaded);
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((x) => x.url == p.url);
        if (i >= 0) _photos[i] = photo;
        _bgOriginal[photo.url] = _bgOriginal[p.url] ?? p;
      });
      _checkPhoto(photo, autoBg: p.bg == null);
    } catch (e) {
      final reason = e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _photoError = "Couldn't crop the photo: $reason");
    } finally {
      if (mounted) {
        setState(() {
          _removingBg.remove(p.url);
          if (_removingBg.isEmpty) _photoNote = null;
        });
      }
    }
  }

  /// Replaces [p] with a background-free copy, uploaded as a new photo. The
  /// old one is cleaned up like any removed photo (on save / on cancel).
  Future<void> _removeBackground(ProductPhoto p) async {
    setState(() {
      _removingBg.add(p.url);
      _photoError = null;
      _photoNote = 'Removing the background… the first time takes longer (downloads a 44 MB tool, once).';
    });
    try {
      final photo = await uploadProductPhoto(await removeBackgroundFrom(p.url));
      _uploadedHere.add(photo);
      if (!mounted) return;
      setState(() {
        final i = _photos.indexWhere((x) => x.url == p.url);
        if (i >= 0) _photos[i] = photo;
        _transparent[photo.url] = true;
        _bgOriginal[photo.url] = p;
      });
    } catch (e) {
      final reason = e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _photoError = "Couldn't remove the background: $reason");
    } finally {
      if (mounted) {
        setState(() {
          _removingBg.remove(p.url);
          if (_removingBg.isEmpty) _photoNote = null;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _price, _oldPrice, _description, _sizes]) {
      c.dispose();
    }
    if (!_saved) deletePhotos(_uploadedHere);
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final files = await pickImageFiles();
    if (files.isEmpty || !mounted) return;
    final room = _maxPhotos - _photos.length - _uploading;
    setState(() {
      _photoError = files.length > room ? 'Only $_maxPhotos photos per product' : null;
      _uploading += math.min(files.length, room);
    });
    await Future.wait([
      for (final file in files.take(room))
        uploadProductPhoto(file)
            .then((photo) {
              _uploadedHere.add(photo);
              if (mounted) setState(() => _photos.add(photo));
              _checkPhoto(photo);
            })
            .catchError((Object e) {
              final reason = e.toString().replaceFirst('Exception: ', '');
              if (mounted) setState(() => _photoError = '${file.name}: $reason');
            })
            .whenComplete(() {
              if (mounted) setState(() => _uploading--);
            }),
    ]);
  }

  /// For photos already hosted elsewhere (e.g. the demo catalogue's links).
  Future<void> _addPhotoLink() async {
    final link = TextEditingController();
    final url = await showGlassDialog<String>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Add photo by link'),
        content: TextField(
          controller: link,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Image URL (https://...)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, link.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    link.dispose();
    if (url == null || url.isEmpty || !mounted) return;
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'https' && scheme != 'http') {
      setState(() => _photoError = "That doesn't look like a web link");
      return;
    }
    // Share/search links (share.google, google.com/imgres, Pinterest pins…)
    // open a web page, not an image; saved as-is, every phone downloads that
    // page and shows a broken photo — including in orders, which keep the
    // photo link forever. So only accept links the browser can draw.
    if (!await _loadsAsImage(url)) {
      if (mounted) {
        setState(
          () => _photoError =
              "That link opens a web page, not a photo. Open it, right-click (or long-press) the photo and "
              'choose "Copy image address", then paste that instead. Or save the photo and upload it.',
        );
      }
      return;
    }
    if (!mounted) return;
    final photo = ProductPhoto(url, url);
    setState(() {
      _photoError = null;
      _photos.add(photo);
    });
    _checkPhoto(photo);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    if (_photos.isEmpty) {
      setState(() => _photoError = 'Add at least one photo');
      return;
    }
    setState(() => _saving = true);
    final sizes = _sizes.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final data = {
      'name': _name.text.trim(),
      'brand': _brand.text.trim(),
      'categoryId': _categoryId,
      'price': double.parse(_price.text.trim()),
      'oldPrice': _oldPrice.text.trim().isEmpty ? null : double.parse(_oldPrice.text.trim()),
      'stockStatus': _stockStatus,
      'thumbnail': _photos.first.thumb,
      'images': [for (final p in _photos) p.url],
      // Grid-sized copy of each photo, parallel to `images` (admin-only, the
      // customer app reads `thumbnail`) so any photo can become the cover.
      'thumbs': [for (final p in _photos) p.thumb],
      // Colour behind each photo in the customer app (null = usual tint).
      'photoBgs': [for (final p in _photos) p.bg],
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
    // A price cut is the only change that can trigger a wishlist price-drop
    // push, and the Worker's job (payments/src/pricedrops.ts) only looks at
    // products stamped since its last run — so idle runs cost ~1 read.
    final oldPrice = (_d?['price'] as num?)?.toDouble();
    if (oldPrice != null && (data['price'] as double) < oldPrice) {
      data['priceChangedAt'] = FieldValue.serverTimestamp();
    }
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await products.add(data);
    }
    _saved = true;
    final kept = {for (final p in _photos) p.url};
    deletePhotos([..._original, ..._uploadedHere].where((p) => !kept.contains(p.url)));
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
                _PhotoStrip(
                  photos: _photos,
                  uploading: _uploading,
                  canAdd: _photos.length + _uploading < _maxPhotos,
                  error: _photoError,
                  note: _photoNote,
                  transparent: _transparent,
                  removingBg: _removingBg,
                  onRemoveBackground: _removeBackground,
                  canUndoBg: _bgOriginal.containsKey,
                  onPickBg: _pickBg,
                  onUndoBg: (p) => setState(() {
                    final i = _photos.indexOf(p);
                    if (i >= 0) _photos[i] = _bgOriginal.remove(p.url)!;
                  }),
                  onAdd: _addPhotos,
                  onAddLink: _addPhotoLink,
                  onRemove: (p) => setState(() => _photos.remove(p)),
                  onMakeCover: (p) => setState(
                    () => _photos
                      ..remove(p)
                      ..insert(0, p),
                  ),
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
          onPressed: _saving || _busy ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// The product form's photos: thumbnails with "make cover" / remove, whether
/// each one already has a see-through background (with a one-tap "remove
/// background" when it doesn't), a tile per upload in progress, and buttons
/// to upload files, paste a link, or get tips on finding good photos.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.uploading,
    required this.canAdd,
    required this.error,
    required this.note,
    required this.transparent,
    required this.removingBg,
    required this.onAdd,
    required this.onAddLink,
    required this.onRemove,
    required this.onMakeCover,
    required this.onRemoveBackground,
    required this.canUndoBg,
    required this.onUndoBg,
    required this.onPickBg,
  });

  final List<ProductPhoto> photos;
  final int uploading;
  final bool canAdd;
  final String? error;
  final String? note;
  final Map<String, bool> transparent;
  final Set<String> removingBg;
  final VoidCallback onAdd;
  final VoidCallback onAddLink;
  final ValueChanged<ProductPhoto> onRemove;
  final ValueChanged<ProductPhoto> onMakeCover;
  final ValueChanged<ProductPhoto> onRemoveBackground;
  final bool Function(String url) canUndoBg;
  final ValueChanged<ProductPhoto> onUndoBg;
  final ValueChanged<ProductPhoto> onPickBg;

  static const _size = 104.0;

  Widget _tile({required Widget child}) => Container(
    width: _size,
    height: _size,
    decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _bgBadge(ProductPhoto p) {
    final isTransparent = transparent[p.url];
    if (removingBg.contains(p.url) || isTransparent == null) return const SizedBox.shrink();
    if (canUndoBg(p.url)) {
      return Tooltip(
        message: 'Edited — tap to put the original photo back',
        child: Material(
          color: AppColors.ink,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onUndoBg(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.undo, size: 11, color: AppColors.onInk),
                  const SizedBox(width: 3),
                  Text(
                    'UNDO',
                    style: TextStyle(color: AppColors.onInk, fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (isTransparent) {
      return const Tooltip(
        message: 'Transparent background',
        child: StatusPill(label: 'NO BG', color: AppColors.onPrimary, background: Color(0xFF16A34A)),
      );
    }
    return Tooltip(
      message: 'This photo has a background — tap to remove it',
      child: Material(
        color: AppColors.accentOrange,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onRemoveBackground(p),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high, size: 11, color: AppColors.onPrimary),
                SizedBox(width: 3),
                Text(
                  'REMOVE BG',
                  style: TextStyle(color: AppColors.onPrimary, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Photos — the first is the cover',
                style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showPhotoTips(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('Where to find photos'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, p) in photos.indexed)
              _tile(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      p.thumb,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(IconlyLight.image, color: AppColors.muted),
                    ),
                    if (removingBg.contains(p.url))
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.7),
                        child: const Center(
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                        ),
                      ),
                    Positioned(top: 6, left: 6, child: _bgBadge(p)),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message: 'Background in the app: ${p.bg ?? 'tint'} — tap to change',
                        child: InkWell(
                          onTap: () => onPickBg(p),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: _bgDecoration(p.bg, shape: BoxShape.circle).copyWith(
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                            ),
                            child: Icon(Icons.palette_outlined, size: 11, color: AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                    if (i == 0)
                      const Positioned(
                        left: 6,
                        bottom: 6,
                        child: StatusPill(label: 'COVER', color: AppColors.onPrimary, background: AppColors.primary),
                      )
                    else
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: _RoundIconButton(
                          icon: IconlyLight.star,
                          tooltip: 'Make cover',
                          onTap: () => onMakeCover(p),
                        ),
                      ),
                    if (!removingBg.contains(p.url))
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: _RoundIconButton(icon: Icons.close, tooltip: 'Remove photo', onTap: () => onRemove(p)),
                      ),
                  ],
                ),
              ),
            for (var i = 0; i < uploading; i++)
              _tile(
                child: const Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
              ),
            if (canAdd)
              _tile(
                child: InkWell(
                  onTap: onAdd,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconlyLight.image, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        'Upload',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (canAdd)
          TextButton.icon(
            onPressed: onAddLink,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Or paste a photo link'),
          ),
        if (note != null) Text(note!, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
      ],
    );
  }
}

void _openLink(String url) => web.window.open(url, '_blank', 'noopener');

/// Whether [url] is something an `<img>` can actually show. A plain image
/// element (not fetch/XHR) works across origins without CORS, so this checks
/// the link itself rather than whether the host allows scripts to read it.
Future<bool> _loadsAsImage(String url) {
  final done = Completer<bool>();
  final img = web.HTMLImageElement();
  img.onLoad.first.then((_) {
    if (!done.isCompleted) done.complete(img.naturalWidth > 0);
  });
  img.onError.first.then((_) {
    if (!done.isCompleted) done.complete(false);
  });
  img.src = url;
  return done.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
}

/// Practical advice rather than a "free PNG" site: most such sites are
/// non-commercial-only or full of brand photos uploaded without permission.
void _showPhotoTips(BuildContext context) {
  Widget link(String label, String url) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => _openLink(url),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
    ),
  );
  Widget para(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(height: 1.4)),
  );
  showGlassDialog<void>(
    context: context,
    builder: (context) => GlassAlertDialog(
      title: const Text('Finding good product photos'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            para(
              "1. Best: the supplier's own photos. The 1688 / Alibaba listing you buy from almost always has "
              'clean photos on a white background — save them and upload here. They show the exact item you sell.',
            ),
            para(
              '2. Then tap REMOVE BG on the photo. It cuts the background out right here, free, for any number '
              'of photos. Check the edges look clean before saving.',
            ),
            para(
              "3. If the cut-out isn't clean (hair, see-through fabric, glass), do that photo in Adobe Express's "
              'free background remover and upload the PNG it gives you:',
            ),
            link(
              'Adobe Express — free background remover',
              'https://www.adobe.com/express/feature/image/remove-background',
            ),
            const SizedBox(height: 6),
            para(
              'Avoid "free PNG" sites for branded products (iPhones, Nike…): most of their images are '
              "non-commercial only, or were uploaded without the brand's permission. For generic, unbranded items "
              "Freepik works, but check each image's licence — free ones usually require credit:",
            ),
            link('Freepik — transparent PNGs', 'https://www.freepik.com/search?format=search&type=png'),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
    ),
  );
}

/// A photo-background dot/swatch fill: the [PhotoBg] if set, else the tint.
BoxDecoration _bgDecoration(String? value, {BorderRadius? radius, BoxShape shape = BoxShape.rectangle}) =>
    PhotoBg.parse(value)?.decoration(radius: radius, shape: shape) ??
    BoxDecoration(color: AppColors.tint, borderRadius: radius, shape: shape);

/// The picker's answer: [value] is a `photoBgs` entry, null = the app's tint.
class _BgChoice {
  const _BgChoice(this.value, {this.crop = false});
  final String? value;

  /// Open the cropper next (the "Crop photo" button).
  final bool crop;
}

/// Picks what the customer app shows behind [photo]: the app tint, a flat
/// colour, or a two-colour fade (top→bottom or centre→edge), with colours
/// from swatches, a hex code, a click on the photo itself, or the browser's
/// eyedropper. [suggested] is what analyzePhoto detected. Null if cancelled.
Future<_BgChoice?> _showBgPicker(BuildContext context, ProductPhoto photo, String? suggested) async {
  const presets = {
    '#ffffff': 'White',
    '#f7f7f7': 'Off-white',
    '#eeeeee': 'Light grey',
    '#f5efe6': 'Warm beige',
    '#eaf2ff': 'Soft blue',
    '#1f1f1f': 'Black',
  };
  const styles = {PhotoBgStyle.solid: 'Solid', PhotoBgStyle.linear: 'Fade', PhotoBgStyle.radial: 'Centre → edge'};
  // null = app tint. Editing always works on a concrete PhotoBg, so keep the
  // last one around even while "tint" is selected.
  PhotoBg? value = PhotoBg.parse(photo.bg);
  var draft = value ?? PhotoBg.parse(suggested) ?? const PhotoBg(PhotoBgStyle.solid, '#ffffff');
  var slot = 0; // which colour the next pick sets: 0 = a (flat/top/centre), 1 = b
  var picking = false;
  final hexField = TextEditingController(text: draft.a);
  // Cached download, so this is quick; needed to map a tap to a pixel.
  final aspect = (await analyzePhoto(photo.thumb))?.aspect ?? 1;
  if (!context.mounted) return null;

  return await showGlassDialog<_BgChoice>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void apply(PhotoBg next) => setState(() {
          draft = next;
          value = next;
          hexField.text = slot == 0 ? next.a : next.b;
        });
        void setColor(String hex) => apply(slot == 0 ? draft.copyWith(a: hex) : draft.copyWith(b: hex));
        void selectSlot(int s) => setState(() {
          slot = s;
          hexField.text = s == 0 ? draft.a : draft.b;
        });

        Widget circle(BoxDecoration fill, {required bool active, Widget? child}) => Container(
          width: 34,
          height: 34,
          decoration: fill.copyWith(
            border: Border.all(color: active ? AppColors.primary : AppColors.line, width: active ? 3 : 1),
          ),
          child: child,
        );

        Widget slotButton(int s, String label) {
          final hex = s == 0 ? draft.a : draft.b;
          final active = slot == s && value != null;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => selectSlot(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  circle(
                    BoxDecoration(color: PhotoBg.colorOf(hex), shape: BoxShape.circle),
                    active: active,
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        final twoColours = draft.style != PhotoBgStyle.solid;
        final suggestedBg = PhotoBg.parse(suggested);
        return GlassAlertDialog(
          title: const Text('Photo background'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What the customer app shows behind this photo. Match the photo's own background so it "
                  'blends in instead of looking like a box. Tap the photo to pick a colour from it.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                // Preview, as the app draws it. The photo is tappable: picks
                // the colour under the finger into the selected slot.
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: _bgDecoration(value?.toString(), radius: BorderRadius.circular(22)),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: LayoutBuilder(
                          builder: (context, box) => MouseRegion(
                            cursor: SystemMouseCursors.precise,
                            child: GestureDetector(
                              onTapDown: (d) async {
                                setState(() => picking = true);
                                try {
                                  final hex = await photoColorAt(
                                    photo.thumb,
                                    d.localPosition.dx / box.maxWidth,
                                    d.localPosition.dy / box.maxHeight,
                                  );
                                  if (context.mounted) setColor(hex);
                                } finally {
                                  if (context.mounted) setState(() => picking = false);
                                }
                              },
                              child: Image.network(photo.thumb, fit: BoxFit.fill),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (picking) const LinearProgressIndicator(minHeight: 2),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, _BgChoice(value?.toString(), crop: true)),
                    icon: const Icon(Icons.crop, size: 18),
                    label: const Text('Crop photo'),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('App tint'),
                      selected: value == null,
                      onSelected: (_) => setState(() => value = null),
                    ),
                    for (final e in styles.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: value?.style == e.key,
                        onSelected: (_) {
                          if (e.key == PhotoBgStyle.solid) slot = 0;
                          apply(draft.copyWith(style: e.key));
                        },
                      ),
                  ],
                ),
                if (value != null) ...[
                  const SizedBox(height: 12),
                  if (draft.style == PhotoBgStyle.linear) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Direction', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        for (final d in FadeDirection.values)
                          Tooltip(
                            message: '${d.fromLabel} → ${d.toLabel}',
                            child: ChoiceChip(
                              label: Text(d.arrow, style: const TextStyle(fontSize: 16)),
                              selected: draft.direction == d,
                              onSelected: (_) => apply(draft.copyWith(direction: d)),
                            ),
                          ),
                        Tooltip(
                          message: 'Swap the two colours',
                          child: IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            onPressed: () => apply(draft.copyWith(a: draft.b, b: draft.a)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (twoColours)
                    Wrap(spacing: 8, children: [slotButton(0, draft.fromLabel), slotButton(1, draft.toLabel)]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (suggestedBg != null)
                        Tooltip(
                          message: 'Detected from the photo ($suggested)',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => apply(suggestedBg),
                            child: circle(
                              suggestedBg.decoration(shape: BoxShape.circle),
                              active: value.toString() == suggestedBg.toString(),
                              child: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                            ),
                          ),
                        ),
                      for (final e in presets.entries)
                        Tooltip(
                          message: e.value,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setColor(e.key),
                            child: circle(
                              BoxDecoration(color: PhotoBg.colorOf(e.key), shape: BoxShape.circle),
                              active: (slot == 0 ? draft.a : draft.b) == e.key,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hexField,
                          decoration: InputDecoration(
                            labelText: twoColours ? 'Hex colour (${slot == 0 ? 'first' : 'second'})' : 'Hex colour',
                            hintText: '#ffffff',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final hex = v.trim().toLowerCase();
                            if (PhotoBg.parse(hex)?.style == PhotoBgStyle.solid) {
                              setState(() {
                                draft = slot == 0 ? draft.copyWith(a: hex) : draft.copyWith(b: hex);
                                value = draft;
                              });
                            }
                          },
                        ),
                      ),
                      if (canPickScreenColor) ...[
                        const SizedBox(width: 10),
                        // The theme makes buttons full-width; inside a Row
                        // that's an infinite width, so size this one itself.
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () async {
                            final hex = await pickScreenColor();
                            if (hex != null) setColor(hex.toLowerCase());
                          },
                          icon: const Icon(Icons.colorize, size: 18),
                          label: const Text('Eyedropper'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, _BgChoice(value?.toString())),
              child: const Text('Use this background'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(hexField.dispose);
}
