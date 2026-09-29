import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
const _stockStatuses = ['inStock', 'preorder'];

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No products yet.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              return Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        d['thumbnail'] as String? ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  title: Text(d['name'] as String? ?? '(no name)'),
                  subtitle: Text(
                    '${d['categoryId']} · \$${d['price']} · ${d['stockStatus']}${(d['isNew'] as bool? ?? false) ? ' · NEW' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openForm(context, doc: doc),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(context, doc)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _openForm(BuildContext context, {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) {
    return showDialog(
      context: context,
      builder: (context) => _ProductForm(doc: doc),
    );
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
    return AlertDialog(
      title: Text(widget.doc == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  items: [for (final c in _categoryIds) DropdownMenuItem(value: c, child: Text(c))],
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
                        decoration: const InputDecoration(labelText: 'Old price (optional, for sale badge)'),
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
