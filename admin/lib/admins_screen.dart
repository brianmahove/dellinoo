import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_access.dart';
import 'glass_dialog.dart';
import 'router.dart';
import 'theme.dart';
import 'iconly.dart';

/// Hardcoded protected admin — this account manages the others, so no other
/// admin (however it's signed in) should be able to remove it, only itself.
/// Mirrored in firestore.rules' `admins/{email}` delete rule for real
/// enforcement; this is just the matching UI-level check.
const _protectedAdminEmail = 'mahovebrian@gmail.com';

/// Manages the `admins/{email}` allowlist (see firestore.rules' `isAdmin()`)
/// so new admins can be added from the panel instead of by hand in the
/// Firebase console. Doc existing = admin. Its optional `access` list limits
/// which areas of the panel that person can use (see `admin_access.dart`);
/// no list = full admin.
class AdminsScreen extends StatelessWidget {
  const AdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myEmail = FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFormPage(context: context, builder: (context) => const _AdminForm()),
        icon: const Icon(IconlyLight.plus),
        label: const Text('Add admin'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('admins').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = [...snapshot.data!.docs]..sort((a, b) => a.id.compareTo(b.id));
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconlyLight.shield_done, size: 40, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('No admins yet', style: TextStyle(color: AppColors.muted)),
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
                  final isMe = doc.id == myEmail;
                  final isProtected = doc.id == _protectedAdminEmail && !isMe;
                  final canDelete = !isMe && !isProtected;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(IconlyLight.shield_done, color: AppColors.accent, size: 20),
                      ),
                      onTap: isMe
                          ? () => context.go(accountPath)
                          : isProtected
                          ? null
                          : () => showFormPage(
                              context: context,
                              builder: (context) => _AdminForm(existing: doc),
                            ),
                      title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        isMe
                            ? 'You · tap to manage your account'
                            : isProtected
                            ? 'Protected · Full access'
                            : '${AdminAccess.summary(doc.data())} · tap to change',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      trailing: IconButton(
                        icon: Icon(isProtected ? IconlyLight.lock : IconlyLight.delete),

                        onPressed: !canDelete
                            ? null
                            : () async {
                                final ok = await showGlassDialog<bool>(
                                  context: context,
                                  builder: (context) => GlassAlertDialog(
                                    title: const Text('Remove admin?'),
                                    content: Text('"${doc.id}" will lose access to this panel.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) await doc.reference.delete();
                              },
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

class _AdminForm extends StatefulWidget {
  const _AdminForm({this.existing});

  /// Set when editing someone's access; the email is then fixed.
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  @override
  State<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<_AdminForm> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.existing?.id);
  late bool _full = widget.existing == null || widget.existing!.data()['access'] is! List;
  late final Set<String> _areas = {
    if (widget.existing?.data()['access'] is List) ...(widget.existing!.data()['access'] as List).whereType<String>(),
  };
  bool _saving = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_full && _areas.isEmpty) {
      setState(() => _error = 'Pick at least one area, or give full access.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final email = _email.text.trim().toLowerCase();
    try {
      // Keep the list in the panel's own order, whatever order they ticked in.
      final access = [
        for (final a in accessAreas)
          if (_areas.contains(a.key)) a.key,
      ];
      final doc = FirebaseFirestore.instance.collection('admins').doc(email);
      if (widget.existing == null) {
        await doc.set({
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': FirebaseAuth.instance.currentUser?.email,
          if (!_full) 'access': access,
        });
      } else {
        await doc.update({'access': _full ? FieldValue.delete() : access});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: Text(widget.existing == null ? 'Add admin' : 'Change access'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: widget.existing == null,
                  autofocus: widget.existing == null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email',
                  onFieldSubmitted: (_) => _saving ? null : _save(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Full access', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Everything, including adding and removing admins',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  value: _full,
                  onChanged: (v) => setState(() => _full = v),
                ),
                if (!_full) ...[
                  Text(
                    'They can use only:',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                  ),
                  for (final a in accessAreas)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(a.hint, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      value: _areas.contains(a.key),
                      onChanged: (v) => setState(() => v == true ? _areas.add(a.key) : _areas.remove(a.key)),
                    ),
                ],
                if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
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
              : Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
