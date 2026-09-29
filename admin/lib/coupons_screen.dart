import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'glass_dialog.dart';
import 'theme.dart';

/// Promo codes (`coupons/{CODE}`). The doc id IS the code (uppercase). The
/// payments Worker re-reads these docs to work out what to charge, so
/// editing one here changes what customers pay from the next payment on.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGlassDialog(context: context, builder: (context) => const _CouponForm()),
        icon: const Icon(Icons.add),
        label: const Text('Add coupon'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell_outlined, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No coupons yet', style: TextStyle(color: AppColors.muted)),
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
                  final percent = (d['percentOff'] as num?)?.toDouble();
                  final amount = (d['amountOff'] as num?)?.toDouble();
                  final expires = (d['expiresAt'] as Timestamp?)?.toDate();
                  final active = d['active'] as bool? ?? false;
                  final bits = [
                    percent != null ? '${percent.toStringAsFixed(0)}% off' : '\$${(amount ?? 0).toStringAsFixed(2)} off',
                    if (d['minSubtotal'] != null) 'min \$${d['minSubtotal']}',
                    if (d['firstOrderOnly'] == true) 'first order only',
                    if (expires != null) 'expires ${expires.toLocal().toString().substring(0, 10)}',
                  ];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(Icons.sell_outlined, color: AppColors.accent, size: 20),
                      ),
                      title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      subtitle: Text(bits.join(' · '), style: TextStyle(color: AppColors.muted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(value: active, onChanged: (v) => doc.reference.update({'active': v})),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                showGlassDialog(context: context, builder: (context) => _CouponForm(doc: doc)),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showGlassDialog<bool>(
                                context: context,
                                builder: (context) => GlassAlertDialog(
                                  title: Text('Delete ${doc.id}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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

class _CouponForm extends StatefulWidget {
  const _CouponForm({this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? get _d => widget.doc?.data();
  late final _code = TextEditingController(text: widget.doc?.id ?? '');
  late bool _isPercent = _d == null || _d!['percentOff'] != null;
  late final _value = TextEditingController(
    text: ((_d?['percentOff'] ?? _d?['amountOff']) as num?)?.toString() ?? '',
  );
  late final _min = TextEditingController(text: (_d?['minSubtotal'] as num?)?.toString() ?? '');
  late DateTime? _expires = (_d?['expiresAt'] as Timestamp?)?.toDate();
  late bool _firstOnly = _d?['firstOrderOnly'] as bool? ?? false;
  late bool _active = _d?['active'] as bool? ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_code, _value, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final code = _code.text.trim().toUpperCase();
    final value = double.parse(_value.text.trim());
    await FirebaseFirestore.instance.collection('coupons').doc(code).set({
      'percentOff': _isPercent ? value : null,
      'amountOff': _isPercent ? null : value,
      'minSubtotal': _min.text.trim().isEmpty ? null : double.parse(_min.text.trim()),
      'firstOrderOnly': _firstOnly,
      'expiresAt': _expires == null ? null : Timestamp.fromDate(_expires!),
      'active': _active,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: Text(widget.doc == null ? 'Add coupon' : 'Edit ${widget.doc!.id}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  enabled: widget.doc == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code (e.g. WELCOME10)'),
                  validator: (v) => RegExp(r'^[A-Za-z0-9_-]{3,20}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '3–20 letters, numbers, - or _',
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('% off')),
                    ButtonSegment(value: false, label: Text('\$ off')),
                  ],
                  selected: {_isPercent},
                  onSelectionChanged: (s) => setState(() => _isPercent = s.first),
                ),
                TextFormField(
                  controller: _value,
                  decoration: InputDecoration(labelText: _isPercent ? 'Percent (1–90)' : 'Amount (USD)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a positive number';
                    if (_isPercent && n > 90) return 'Max 90%';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _min,
                  decoration: const InputDecoration(labelText: 'Minimum order subtotal (optional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v!.trim().isEmpty || double.tryParse(v.trim()) != null ? null : 'Must be a number',
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expires == null ? 'No expiry' : 'Expires ${_expires!.toLocal().toString().substring(0, 10)}',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expires ?? now.add(const Duration(days: 30)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 730)),
                        );
                        // Valid through the end of the chosen day.
                        if (date != null) setState(() => _expires = DateTime(date.year, date.month, date.day, 23, 59));
                      },
                      child: const Text('Set expiry'),
                    ),
                    if (_expires != null)
                      IconButton(
                        onPressed: () => setState(() => _expires = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
                CheckboxListTile(
                  value: _firstOnly,
                  onChanged: (v) => setState(() => _firstOnly = v ?? false),
                  title: const Text('First order only'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v ?? true),
                  title: const Text('Active'),
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
