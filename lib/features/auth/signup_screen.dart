import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/contact.dart';
import '../../core/iconly.dart';
import '../../core/phone.dart';
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
  late final _termsTap = TapGestureRecognizer()..onTap = () => _openLink(AppInfo.termsUrl);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => _openLink(AppInfo.privacyUrl);

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      emailPattern.hasMatch(_email.text.trim()) &&
      isZimMobile(_phone.text) &&
      _passwordOk &&
      _confirm.text == _password.text &&
      _agreed;

  bool get _hasLength => _password.text.length >= 8;
  bool get _hasUpper => RegExp('[A-Z]').hasMatch(_password.text);
  bool get _hasDigit => RegExp('[0-9]').hasMatch(_password.text);
  bool get _passwordOk => _hasLength && _hasUpper && _hasDigit;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// Returns to whatever pushed the sign-up screen (e.g. checkout, redirected
  /// there by the router when unauthenticated) rather than always going home.
  Future<void> _openLink(String url) async {
    final ok = await openLink(url);
    if (!ok && mounted) showGlassToast(context, 'Could not open the page');
  }

  void _afterSuccess() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _signUp() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signUp(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: formatZimPhone(_phone.text) ?? '',
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

  void _social(String provider) => showGlassToast(context, '$provider sign-up is coming soon');

  Widget _rule(String text, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_rounded : Icons.circle_outlined,
          size: ok ? 16 : 12,
          color: ok ? const Color(0xFF2E9E5B) : AppColors.muted,
        ),
        SizedBox(width: ok ? 8 : 10),
        Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.ink)),
      ],
    ),
  );

  TextSpan _link(String text, GestureRecognizer tap) => TextSpan(
    text: text,
    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
    recognizer: tap,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const AuthHeader(),
              const SizedBox(height: 16),
              const Text(
                'Create Your Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to shop and ship goods from China, track orders and enjoy exclusive deals.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              AuthField(
                pill: true,
                controller: _name,
                icon: IconlyLight.profile,
                hint: 'Full Name',
                onChanged: (_) => setState(() {}),
              ),
              AuthField(
                pill: true,
                controller: _email,
                icon: IconlyLight.message,
                hint: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              AuthPhoneField(pill: true, controller: _phone, onChanged: (_) => setState(() {})),
              AuthField(
                pill: true,
                controller: _password,
                icon: IconlyLight.lock,
                hint: 'Password',
                obscure: true,
                onChanged: (_) => setState(() {}),
              ),
              AuthField(
                pill: true,
                controller: _confirm,
                icon: IconlyLight.lock,
                hint: 'Confirm Password',
                obscure: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text
                    ? 'Passwords don\'t match'
                    : null,
                spacing: 8,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rule('At least 8 characters', _hasLength),
                    _rule('Include a capital letter (A–Z)', _hasUpper),
                    _rule('Include a number (0–9)', _hasDigit),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                        side: const BorderSide(color: AppColors.primary, width: 1.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: AppColors.ink, fontSize: 14, height: 1.4),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                _link('Terms & Conditions', _termsTap),
                                const TextSpan(text: ' and '),
                                _link('Privacy Policy.', _privacyTap),
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
              const AuthDivider(label: 'or sign up with'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AuthSocialButton(
                      compact: true,
                      provider: SocialProvider.google,
                      onTap: _submitting ? () {} : _google,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthSocialButton(
                      compact: true,
                      provider: SocialProvider.apple,
                      onTap: () => _social('Apple'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: AppColors.ink)),
                    GestureDetector(
                      onTap: () => context.canPop() ? context.pop() : context.go('/login'),
                      child: const Text(
                        'Log In',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
