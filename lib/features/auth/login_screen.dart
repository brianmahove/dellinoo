import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/brand.dart';
import '../../core/iconly.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '771234567');

  bool get _valid => _phone.text.replaceAll(' ', '').length == 9;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: () => context.go('/home'), child: const Text('Skip'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
            const SizedBox(height: 24),
            const Text('Welcome to Dellinoo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Enter your phone number to sign in or create an account. We will send you a verification code.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            const Text('Phone number', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 16, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: '77 123 4567',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconlyLight.call, size: 20, color: AppColors.muted),
                      SizedBox(width: 6),
                      Text('+263', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _valid
                  ? () => context.push(Uri(path: '/otp', queryParameters: {'phone': '+263 ${_phone.text}'}).toString())
                  : null,
              child: const Text('Continue'),
            ),
            const SizedBox(height: 16),
            Text(
              'By continuing you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
