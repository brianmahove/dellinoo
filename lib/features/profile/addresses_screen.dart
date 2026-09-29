import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressBookProvider);

    return Scaffold(
      appBar: const PageHeader(title: 'Delivery addresses'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addresses.isEmpty
          ? EmptyState(
              icon: IconlyLight.location,
              title: 'No saved addresses',
              message: 'Add one to speed up checkout.',
              action: FilledButton(onPressed: () => _openForm(context), child: const Text('Add address')),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: addresses.length,
              itemBuilder: (context, i) => _AddressCard(addresses[i]),
            ),
    );
  }

  static void _openForm(BuildContext context, {SavedAddress? existing}) {
    showGlassBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddressForm(existing: existing),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard(this.saved);

  final SavedAddress saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: saved.isDefault ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(saved.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (saved.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Default',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      AddressesScreen._openForm(context, existing: saved);
                    case 'default':
                      ref.read(addressBookProvider.notifier).update(saved.copyWith(isDefault: true));
                    case 'delete':
                      ref.read(addressBookProvider.notifier).remove(saved.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!saved.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${saved.address.fullName} · ${saved.address.phone}', style: TextStyle(color: AppColors.muted)),
          Text(saved.address.oneLine, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.existing});

  final SavedAddress? existing;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _name = TextEditingController(text: widget.existing?.address.fullName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.address.phone ?? '');
  late final _street = TextEditingController(text: widget.existing?.address.street ?? '');
  late final _city = TextEditingController(text: widget.existing?.address.city ?? '');
  late bool _isDefault = widget.existing?.isDefault ?? ref.read(addressBookProvider).isEmpty;
  bool _saving = false;

  bool get _valid =>
      _label.text.trim().isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _street.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty;

  @override
  void dispose() {
    for (final c in [_label, _name, _phone, _street, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final address = Address(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      street: _street.text.trim(),
      city: _city.text.trim(),
    );
    try {
      final notifier = ref.read(addressBookProvider.notifier);
      if (widget.existing != null) {
        await notifier.update(
          widget.existing!.copyWith(label: _label.text.trim(), address: address, isDefault: _isDefault),
        );
      } else {
        await notifier.add(label: _label.text.trim(), address: address, isDefault: _isDefault);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showGlassToast(context, "Couldn't save that address — check your connection and try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add address' : 'Edit address',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label (e.g. Home, Work)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _street,
            decoration: const InputDecoration(labelText: 'Street address / suburb'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City / town'),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            value: _isDefault,
            onChanged: widget.existing?.isDefault == true ? null : (v) => setState(() => _isDefault = v ?? false),
            title: const Text('Use as my default address'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _valid && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save address'),
          ),
        ],
      ),
    );
  }
}
