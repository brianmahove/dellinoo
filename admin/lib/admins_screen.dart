import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Hardcoded protected admin — this account manages the others, so no other
/// admin (however it's signed in) should be able to remove it, only itself.
/// Mirrored in firestore.rules' `admins/{email}` delete rule for real
/// enforcement; this is just the matching UI-level check.
const _protectedAdminEmail = 'mahovebrian@gmail.com';

/// Manages the `admins/{email}` allowlist (see firestore.rules' `isAdmin()`)
/// so new admins can be added from the panel instead of by hand in the
/// Firebase console. Doc existing = admin; the value inside is unused.
class AdminsScreen extends StatelessWidget {
  const AdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myEmail = FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Admins'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (context) => const _AdminForm()),
        icon: const Icon(Icons.add),
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
                  Icon(Icons.admin_panel_settings_outlined, size: 40, color: AppColors.muted),
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
                        child: Icon(Icons.admin_panel_settings_outlined, color: AppColors.accent, size: 20),
                      ),
                      title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: isMe
                          ? Text('You', style: TextStyle(color: AppColors.muted))
                          : isProtected
                          ? Text('Protected', style: TextStyle(color: AppColors.muted))
                          : null,
                      trailing: IconButton(
                        icon: Icon(isProtected ? Icons.lock_outline : Icons.delete_outline),
                        
                        onPressed: !canDelete
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
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
  const _AdminForm();

  @override
  State<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<_AdminForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
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
    setState(() {
      _saving = true;
      _error = null;
    });
    final email = _email.text.trim().toLowerCase();
    try {
      await FirebaseFirestore.instance.collection('admins').doc(email).set({
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': FirebaseAuth.instance.currentUser?.email,
      });
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
    return AlertDialog(
      title: const Text('Add admin'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email',
                onFieldSubmitted: (_) => _saving ? null : _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
