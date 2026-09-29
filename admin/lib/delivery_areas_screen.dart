import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class DeliveryAreasScreen extends StatelessWidget {
  const DeliveryAreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery areas'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (context) => const _AreaForm()),
        icon: const Icon(Icons.add),
        label: const Text('Add area'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('delivery_areas').orderBy('sortOrder').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No delivery areas yet', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();
                  final fee = (d['fee'] as num?)?.toDouble() ?? 0;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(Icons.local_shipping_outlined, color: AppColors.accent, size: 20),
                      ),
                      title: Text(d['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${d['eta']}', style: TextStyle(color: AppColors.muted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fee == 0 ? 'FREE' : '\$${fee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: fee == 0 ? AppColors.inStock : AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => _AreaForm(doc: doc),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete area?'),
                                  content: Text('"${d['name']}" will be removed.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await doc.reference.delete();
                            },
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
}

class _AreaForm extends StatefulWidget {
  const _AreaForm({this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends State<_AreaForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _d?['name'] as String? ?? '');
  late final _fee = TextEditingController(text: (_d?['fee'] as num?)?.toString() ?? '0');
  late final _eta = TextEditingController(text: _d?['eta'] as String? ?? '');
  late final _sortOrder = TextEditingController(text: (_d?['sortOrder'] as num?)?.toString() ?? '0');
  bool _saving = false;

  Map<String, dynamic>? get _d => widget.doc?.data();

  @override
  void dispose() {
    for (final c in [_name, _fee, _eta, _sortOrder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'fee': double.parse(_fee.text.trim()),
      'eta': _eta.text.trim(),
      'sortOrder': int.parse(_sortOrder.text.trim()),
    };
    final areas = FirebaseFirestore.instance.collection('delivery_areas');
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await areas.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.doc == null ? 'Add delivery area' : 'Edit delivery area'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _fee,
                decoration: const InputDecoration(labelText: 'Fee (USD, 0 for free)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Required number' : null,
              ),
              TextFormField(
                controller: _eta,
                decoration: const InputDecoration(labelText: 'Estimated time (e.g. "1–2 days")'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _sortOrder,
                decoration: const InputDecoration(labelText: 'Display order (lower = shown first)'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Required number' : null,
              ),
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
