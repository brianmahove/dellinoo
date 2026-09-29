import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../auth/auth_widgets.dart' show authErrorMessage, emailPattern;

/// The account's identity — reached by tapping the profile header. Shows the
/// sign-in provider's photo (Google/Facebook) when there is one, lets the
/// customer rename themselves, manage their linked sign-in methods, change
/// email/password, see their default delivery address, and delete their
/// account. Sign-out also lives here (alongside the one already in the
/// Profile menu — both are fine, this is where people look for it first).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final _name = TextEditingController(text: ref.read(authProvider)?.name ?? '');
  bool _savingName = false;
  bool _sendingVerification = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await ref.read(authProvider.notifier).updateName(name);
      if (mounted) showGlassToast(context, 'Name updated');
    } catch (_) {
      if (mounted) showGlassToast(context, "Couldn't save that — check your connection and try again.");
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _sendingVerification = true);
    try {
      await ref.read(authProvider.notifier).sendEmailVerification();
      if (mounted) showGlassToast(context, 'Verification email sent — check your inbox.');
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Future<void> _checkVerified() async {
    await ref.read(authProvider.notifier).refresh();
    if (!mounted) return;
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    showGlassToast(context, verified ? 'Email verified!' : 'Not verified yet.');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      // Only reachable while signed in (see router.dart's redirect), but
      // sign-out could race a still-mounted screen — bail out cleanly.
      return Scaffold(
        appBar: const PageHeader(title: 'Account'),
        body: const SizedBox.shrink(),
      );
    }
    final fbUser = FirebaseAuth.instance.currentUser;
    final providerIds = fbUser?.providerData.map((p) => p.providerId).toSet() ?? const <String>{};
    final hasPassword = providerIds.contains('password');
    final emailVerified = fbUser?.emailVerified ?? true; // Google/Facebook emails count as verified
    final createdAt = fbUser?.metadata.creationTime;
    final addresses = ref.watch(addressBookProvider);
    final defaultAddress = addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;

    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Scaffold(
      appBar: const PageHeader(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Member since ${monthYear(createdAt)}',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Name
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixIcon: _savingName
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(icon: const Icon(IconlyBold.tick_square), onPressed: _saveName),
                  ),
                  onSubmitted: (_) => _saveName(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Email / phone
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _InfoRow(IconlyLight.message, 'Email', user.email ?? 'Not set')),
                    if (hasPassword)
                      TextButton(onPressed: () => _openChangeEmail(context, ref), child: const Text('Change')),
                  ],
                ),
                if (hasPassword && !emailVerified) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.preorderSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.preorder),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email not verified',
                            style: TextStyle(fontSize: 12.5, color: AppColors.preorder, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: _sendingVerification ? null : _resendVerification,
                          child: Text(_sendingVerification ? 'Sending…' : 'Resend'),
                        ),
                        TextButton(onPressed: _checkVerified, child: const Text('I verified')),
                      ],
                    ),
                  ),
                ],
                if (user.phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _InfoRow(IconlyLight.call, 'Phone', user.phone),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sign-in methods
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sign-in methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                _ProviderRow(
                  icon: IconlyLight.lock,
                  label: 'Password',
                  linked: hasPassword,
                  onLink: () => _openAddPassword(context, ref),
                ),
                const SizedBox(height: 10),
                _ProviderRow(
                  faIcon: FontAwesomeIcons.google,
                  label: 'Google',
                  linked: providerIds.contains('google.com'),
                  onLink: () => _link(context, ref, ref.read(authProvider.notifier).linkGoogle),
                ),
                const SizedBox(height: 10),
                _ProviderRow(
                  faIcon: FontAwesomeIcons.facebook,
                  faColor: const Color(0xFF1877F2),
                  label: 'Facebook',
                  linked: providerIds.contains('facebook.com'),
                  onLink: () => _link(context, ref, ref.read(authProvider.notifier).linkFacebook),
                ),
                if (hasPassword) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openChangePassword(context, ref),
                      icon: const Icon(IconlyLight.lock, size: 18),
                      label: const Text('Change password'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Default address
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(IconlyLight.location, color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delivery address', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(
                        defaultAddress == null ? 'No saved address yet' : defaultAddress.address.oneLine,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/addresses'),
                  child: Text(defaultAddress == null ? 'Add' : 'Manage'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: Icon(IconlyLight.logout, color: AppColors.sale),
            label: Text('Sign out', style: TextStyle(color: AppColors.sale)),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => _confirmDelete(context, ref),
              child: Text('Delete account', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared wrapper for the two one-tap link flows (Google/Facebook): runs
  /// [action], swallows a user-cancelled sign-in silently, toasts anything
  /// else.
  Future<void> _link(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      if (context.mounted) showGlassToast(context, 'Linked!');
    } catch (e) {
      final message = authErrorMessage(e);
      if (context.mounted && message != null) showGlassToast(context, message);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          "This removes your account and saved addresses. Past orders are kept as records, as explained in "
          "our Privacy Policy. This can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sale),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _deleteAccount(context, ref);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(authProvider.notifier);
    try {
      await notifier.deleteAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        if (context.mounted) showGlassToast(context, authErrorMessage(e) ?? 'Something went wrong.');
        return;
      }
      // Session too old — re-prove identity, then retry once.
      final fbUser = FirebaseAuth.instance.currentUser;
      final needsPassword = fbUser?.providerData.any((p) => p.providerId == 'password') ?? true;
      String? password;
      if (needsPassword) {
        if (!context.mounted) return;
        password = await _promptPassword(context, 'Confirm your password to delete your account');
        if (password == null) return; // cancelled
      }
      try {
        await notifier.reauthenticate(password: password);
        await notifier.deleteAccount();
      } catch (e2) {
        if (context.mounted) showGlassToast(context, authErrorMessage(e2) ?? 'Something went wrong.');
        return;
      }
    } catch (e) {
      if (context.mounted) showGlassToast(context, authErrorMessage(e) ?? 'Something went wrong.');
      return;
    }
    if (context.mounted) {
      showGlassToast(context, 'Your account has been deleted.');
      context.go('/login');
    }
  }

  Future<String?> _promptPassword(BuildContext context, String title) {
    final controller = TextEditingController();
    return showGlassDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Continue')),
        ],
      ),
    );
  }

  void _openChangeEmail(BuildContext context, WidgetRef ref) {
    showGlassBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _ChangeEmailSheet());
  }

  void _openChangePassword(BuildContext context, WidgetRef ref) {
    showGlassBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _ChangePasswordSheet());
  }

  void _openAddPassword(BuildContext context, WidgetRef ref) {
    showGlassBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _AddPasswordSheet());
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    this.icon,
    this.faIcon,
    this.faColor,
    required this.label,
    required this.linked,
    required this.onLink,
  });

  final IconData? icon;
  final FaIconData? faIcon;
  final Color? faColor;
  final String label;
  final bool linked;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: icon != null
              ? Icon(icon, size: 20, color: AppColors.accent)
              : FaIcon(faIcon, size: 17, color: faColor ?? AppColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        if (linked)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IconlyBold.tick_square, size: 16, color: AppColors.inStock),
              const SizedBox(width: 4),
              Text(
                'Linked',
                style: TextStyle(color: AppColors.inStock, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          )
        else
          TextButton(onPressed: onLink, child: const Text('Link')),
      ],
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => emailPattern.hasMatch(_email.text.trim()) && _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).changeEmail(currentPassword: _password.text, newEmail: _email.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        showGlassToast(context, 'Check ${_email.text.trim()} to confirm the change.');
      }
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          const Text('Change email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            "We'll send a confirmation link to your new email before it takes effect.",
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'New email'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send confirmation link'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  bool get _valid => _current.text.isNotEmpty && _next.text.length >= 6;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (mounted) {
        Navigator.of(context).pop();
        showGlassToast(context, 'Password updated');
      }
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password (min. 6 characters)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save new password'),
          ),
        ],
      ),
    );
  }
}

class _AddPasswordSheet extends ConsumerStatefulWidget {
  const _AddPasswordSheet();

  @override
  ConsumerState<_AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends ConsumerState<_AddPasswordSheet> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).linkPassword(_password.text);
      if (mounted) {
        Navigator.of(context).pop();
        showGlassToast(context, 'You can now also sign in with a password.');
      }
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          const Text('Add a password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            "So you can sign in with your email even without Google or Facebook.",
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password (min. 6 characters)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _password.text.length >= 6 && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add password'),
          ),
        ],
      ),
    );
  }
}
