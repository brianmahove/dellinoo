import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'category_icons.dart';
import 'glass_dialog.dart';
import 'iconly.dart';
import 'theme.dart';

/// One category, as the other admin screens need it.
typedef AdminCategory = ({String id, String name});

/// What the customer app falls back to while the collection is empty — kept
/// in sync by hand with `mockCategories` in the app's lib/data/mock_data.dart.
const kDefaultCategories = <AdminCategory>[
  (id: 'women', name: 'Women'),
  (id: 'men', name: 'Men'),
  (id: 'kids', name: 'Kids'),
  (id: 'shoes', name: 'Shoes'),
  (id: 'handbags', name: 'Handbags'),
  (id: 'wigs', name: 'Wigs'),
  (id: 'phones', name: 'Phones'),
  (id: 'watches', name: 'Watches'),
  (id: 'laptops', name: 'Laptops'),
  (id: 'games', name: 'Games'),
  (id: 'electronics', name: 'Electronics'),
];

/// The live category list, for the screens that have to offer one (the
/// product form's dropdown, the Products filter pills). Falls back to
/// [kDefaultCategories] while the admin hasn't added any, exactly as the
/// customer app does, so a product is never saved into a category the app
/// doesn't show.
Stream<List<AdminCategory>> categoriesStream() => FirebaseFirestore.instance
    .collection('categories')
    .orderBy('sortOrder')
    .snapshots()
    .map(
      (snap) => snap.docs.isEmpty
          ? kDefaultCategories
          : [for (final d in snap.docs) (id: d.id, name: d.data()['name'] as String? ?? d.id)],
    );

/// Categories (Firestore `categories`, public read / admin write).
///
/// The doc id is the category id products point at (`categoryId`), so it is
/// generated once from the name and never changes afterwards — renaming a
/// category only changes what customers read, never which products are in it.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('categories');

  Future<void> _seedDefaults() async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < kDefaultCategories.length; i++) {
      final c = kDefaultCategories[i];
      // The icon key happens to match the id for all of the defaults.
      batch.set(_col.doc(c.id), {'name': c.name, 'icon': c.id, 'sortOrder': i * 10}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFormPage(context: context, builder: (context) => const _CategoryForm()),
        icon: const Icon(IconlyLight.plus),
        label: const Text('Add category'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('sortOrder').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _Empty(onSeed: _seedDefaults);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: docs.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == docs.length) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                      child: Text(
                        'Customers see these in this order on the Shop tab. A category can only be deleted '
                        'once no product is in it.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                      ),
                    );
                  }
                  final doc = docs[i];
                  final d = doc.data();
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(categoryIcon(d['icon'] as String?), color: AppColors.accent, size: 20),
                      ),
                      title: Text(d['name'] as String? ?? doc.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(doc.id, style: TextStyle(color: AppColors.muted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Move up',
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: i == 0 ? null : () => _swap(docs[i - 1], doc),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Move down',
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: i == docs.length - 1 ? null : () => _swap(doc, docs[i + 1]),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(IconlyLight.edit),
                            onPressed: () => showFormPage(
                              context: context,
                              builder: (context) => _CategoryForm(doc: doc),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(IconlyLight.delete),
                            onPressed: () => _delete(context, doc),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reorder by swapping the two docs' positions.
  Future<void> _swap(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(a.reference, {'sortOrder': (b.data()['sortOrder'] as num?)?.toInt() ?? 0});
    batch.update(b.reference, {'sortOrder': (a.data()['sortOrder'] as num?)?.toInt() ?? 0});
    await batch.commit();
  }

  Future<void> _delete(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final name = doc.data()['name'] as String? ?? doc.id;
    // Deleting a category that still has products would leave them
    // uncategorised, so they would vanish from the app's Shop tab.
    final used = await FirebaseFirestore.instance
        .collection('products')
        .where('categoryId', isEqualTo: doc.id)
        .limit(1)
        .get();
    if (!context.mounted) return;
    if (used.docs.isNotEmpty) {
      await showGlassDialog<void>(
        context: context,
        builder: (context) => GlassAlertDialog(
          title: const Text('Category in use'),
          content: Text('Some products are still in "$name". Move them to another category first, then delete it.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Delete category?'),
        content: Text('"$name" will be removed from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSeed});

  final Future<void> Function() onSeed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconlyLight.category, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text('No categories yet', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          SizedBox(
            width: 320,
            child: Text(
              'The app is showing its built-in list until you add some. Start from that list, or add your own.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onSeed, child: const Text('Add the standard categories')),
        ],
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _d?['name'] as String? ?? '');
  late String _icon = _d?['icon'] as String? ?? 'other';
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? get _d => widget.doc?.data();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// "Wigs & hairpieces" -> "wigs-hairpieces". Every product stores this id,
  /// so it is only ever generated when the category is created.
  static String _slug(String name) {
    final s = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'category' : s;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final col = FirebaseFirestore.instance.collection('categories');
    try {
      if (widget.doc != null) {
        await widget.doc!.reference.update({'name': _name.text.trim(), 'icon': _icon});
      } else {
        final id = _slug(_name.text.trim());
        final existing = await col.doc(id).get();
        if (existing.exists) throw 'There is already a category called "${existing.data()?['name'] ?? id}".';
        // Goes last; the arrows on the list move it afterwards.
        final last = await col.orderBy('sortOrder', descending: true).limit(1).get();
        final sortOrder = ((last.docs.firstOrNull?.data()['sortOrder'] as num?)?.toInt() ?? -10) + 10;
        await col.doc(id).set({'name': _name.text.trim(), 'icon': _icon, 'sortOrder': sortOrder});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: Text(widget.doc == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Wigs'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              Text('Icon', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              Container(
                height: 150,
                decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(8),
                child: GridView.extent(
                  maxCrossAxisExtent: 56,
                  children: [
                    for (final key in categoryIcons.keys)
                      Tooltip(
                        message: key,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _icon = key),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _icon == key ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              categoryIcons[key],
                              size: 20,
                              color: _icon == key ? AppColors.onPrimary : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.doc != null)
                Text(
                  'Products stay in this category when you rename it.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              if (_error != null) Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
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
