import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'iconly.dart';
import 'theme.dart';
import 'user_avatar.dart';

/// The signed-in admin's own account: who they are, change password, sign out.
/// Opened from the avatar in the top bar (in-shell on desktop) or pushed as its
/// own page (mobile, and from "You" on the Admins list), where [showBack] adds
/// an app bar with a back button.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final name = user.displayName;
    final email = user.email ?? '';
    final hasPassword = user.providerData.any((p) => p.providerId == 'password');
    final usesGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    return Scaffold(
      appBar: showBack ? AppBar(title: const Text('Account')) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Panel(
                child: Row(
                  children: [
                    UserAvatar(user: user, radius: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name != null && name.isNotEmpty ? name : 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          SelectableText(email, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            [if (hasPassword) 'Email & password', if (usesGoogle) 'Google'].join('  ·  '),
                            style: TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Panel(child: hasPassword ? const _ChangePasswordForm() : _NoPassword(email: email)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  if (showBack) Navigator.of(context).pop();
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(IconlyLight.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser!;
    setState(() {
      _saving = true;
      _error = null;
      _done = false;
    });
    try {
      // Changing a password is sensitive, so Firebase wants a fresh sign-in first.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: _current.text),
      );
      await user.updatePassword(_new.text);
      _current.clear();
      _new.clear();
      _confirm.clear();
      if (mounted) setState(() => _done = true);
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'wrong-password' || 'invalid-credential' => 'Your current password is incorrect.',
          'weak-password' => 'Choose a stronger password (at least 6 characters).',
          'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
          _ => e.message ?? 'Could not change the password.',
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
            validator: (v) => v != _new.text ? "Passwords don't match" : null,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          if (_done)
            const Text(
              'Password updated.',
              style: TextStyle(color: AppColors.inStock, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update password'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google-only accounts have no password to change; a reset email lets them
/// set one if they also want to sign in with email.
class _NoPassword extends StatefulWidget {
  const _NoPassword({required this.email});

  final String email;

  @override
  State<_NoPassword> createState() => _NoPasswordState();
}

class _NoPasswordState extends State<_NoPassword> {
  bool _sent = false;
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Could not send email')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(
          'You sign in with Google, so there is no password on this account. '
          'You can email yourself a link to set one if you also want to sign in with email.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _busy || _sent ? null : _send,
            child: Text(_sent ? 'Email sent' : 'Email me a link'),
          ),
        ),
      ],
    );
  }
}
