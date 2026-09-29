import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'iconly.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signInWithPassword() =>
      _run(() => FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/images/logo_full.png', width: 220)),
                  const SizedBox(height: 6),
                  Text(
                    'Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 3,
                      color: AppColors.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Sign in with an admin account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())),
                    icon: Icons.g_mobiledata,
                    child: const Text('Sign in with Google'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('or', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(IconlyLight.message)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(IconlyLight.lock)),
                    onSubmitted: (_) => _busy ? null : _signInWithPassword(),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _busy ? null : _signInWithPassword,
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
