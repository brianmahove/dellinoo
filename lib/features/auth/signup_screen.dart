import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/glass.dart';
import 'auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;
  bool _submitting = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      emailPattern.hasMatch(_email.text.trim()) &&
      _phone.text.replaceAll(' ', '').length == 9 &&
      _password.text.length >= 6 &&
      _confirm.text == _password.text &&
      _agreed;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Returns to whatever pushed the sign-up screen (e.g. checkout, redirected
  /// there by the router when unauthenticated) rather than always going home.
  void _afterSuccess() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _signUp() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signUp(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: '+263 ${_phone.text}',
            password: _password.text,
          );
      if (!mounted) return;
      _afterSuccess();
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _google() async {
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      _afterSuccess();
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _facebook() async {
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).signInWithFacebook();
      if (!mounted) return;
      _afterSuccess();
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _social(String provider) => showGlassToast(context, '$provider sign-up is coming soon');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const AuthHeader(),
            const SizedBox(height: 16),
            const Text('Create Your Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Join Dellinoo and start shopping anything, anytime.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            AuthField(
              controller: _name,
              icon: IconlyLight.profile,
              hint: 'Full Name',
              onChanged: (_) => setState(() {}),
            ),
            AuthField(
              controller: _email,
              icon: IconlyLight.message,
              hint: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            AuthPhoneField(controller: _phone, onChanged: (_) => setState(() {})),
            AuthField(
              controller: _password,
              icon: IconlyLight.lock,
              hint: 'Create Password',
              obscure: true,
              onChanged: (_) => setState(() {}),
            ),
            AuthField(
              controller: _confirm,
              icon: IconlyLight.lock,
              hint: 'Confirm Password',
              obscure: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text ? 'Passwords don\'t match' : null,
              spacing: 6,
            ),
            InkWell(
              onTap: () => setState(() => _agreed = !_agreed),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              const TextSpan(
                                text: 'Terms and Conditions',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(text: ' and '),
                              const TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthGradientButton(label: 'Sign Up', loading: _submitting, onPressed: _valid ? _signUp : null),
            const SizedBox(height: 20),
            const AuthDivider(),
            const SizedBox(height: 16),
            AuthSocialButton(provider: SocialProvider.google, onTap: _submitting ? () {} : _google),
            const SizedBox(height: 12),
            AuthSocialButton(provider: SocialProvider.apple, onTap: () => _social('Apple')),
            const SizedBox(height: 12),
            AuthSocialButton(provider: SocialProvider.facebook, onTap: _submitting ? () {} : _facebook),
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text('Already have an account? ', style: TextStyle(color: AppColors.muted)),
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/login'),
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
