import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/glass.dart';

/// The Zimbabwe number saved on the customer's profile (`users/{uid}.phone`),
/// or null if none. Errors (offline, rules) count as "unknown" and also return
/// null, which [ensurePhoneOnFile] treats as "don't block".
Future<({bool known, String? phone})> _loadPhone(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final phone = doc.data()?['phone'] as String?;
    return (known: true, phone: phone);
  } catch (_) {
    return (known: false, phone: null);
  }
}

/// Makes sure the signed-in customer has a Zimbabwe mobile number on file.
///
/// Email sign-up collects it; Google and Facebook don't, and accounts made
/// before the Zimbabwe-only rule have none. If it's missing this opens a dialog
/// that can only be closed by saving a valid number (or signing out). Returns
/// true when a number is on file. If the profile can't be read (e.g. offline)
/// it lets the customer through rather than locking them out.
Future<bool> ensurePhoneOnFile(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider);
  if (user == null) return false;
  final loaded = await _loadPhone(user.uid);
  if (!loaded.known) return true;
  if (loaded.phone != null && isZimMobile(loaded.phone!)) return true;
  if (!context.mounted) return false;
  final saved = await showGlassDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PhoneDialog(uid: user.uid),
  );
  return saved == true;
}

class _PhoneDialog extends ConsumerStatefulWidget {
  const _PhoneDialog({required this.uid});
  final String uid;

  @override
  ConsumerState<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends ConsumerState<_PhoneDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => isZimMobile(_controller.text);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'phone': formatZimPhone(_controller.text),
      }, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showGlassToast(context, "Couldn't save your number. Check your connection and try again.");
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add your phone number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Dellinoo is for customers in Zimbabwe. We use your number for delivery and order updates.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '🇿🇼  +263  ',
                hintText: '77 123 4567',
                errorText: _controller.text.length >= 9 && !_valid ? zimPhoneHint : null,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _valid && !_saving ? _save : null, child: Text(_saving ? 'Saving…' : 'Save')),
            TextButton(onPressed: _saving ? null : _signOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
