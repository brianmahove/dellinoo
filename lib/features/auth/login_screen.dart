import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/glass.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  bool get _valid => emailPattern.hasMatch(_identifier.text.trim()) && _password.text.isNotEmpty;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signInWithPassword(email: _identifier.text.trim(), password: _password.text);
      if (!mounted) return;
      context.go('/home');
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
      context.go('/home');
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
      context.go('/home');
    } catch (e) {
      final message = authErrorMessage(e);
      if (mounted && message != null) showGlassToast(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _social(String provider) => showGlassToast(context, '$provider sign-in is coming soon');

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            AuthHeader(
              showBack: canPop,
              // trailing: TextButton(onPressed: () => context.go('/home'), child: const Text('Skip')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome Back!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to continue your shopping experience with Dellinoo.',
                        style: TextStyle(color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const BrandHero(width: 150),
              ],
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Email Address',
              controller: _identifier,
              icon: IconlyLight.profile,
              hint: 'Enter your email address',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            AuthField(
              label: 'Password',
              controller: _password,
              icon: IconlyLight.lock,
              hint: 'Enter your password',
              obscure: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => showGlassToast(context, 'Password reset isn\'t available yet'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthGradientButton(label: 'Log In', loading: _submitting, onPressed: _valid ? _logIn : null),
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
                  Text("Don't have an account? ", style: TextStyle(color: AppColors.muted)),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: const Text(
                      'Sign Up',
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
