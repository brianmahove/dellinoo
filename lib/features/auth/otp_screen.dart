import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _verifying = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    ref.read(authProvider.notifier).signIn(widget.phone);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: ''),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Text('Verify your number', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                text: 'Enter the 6-digit code we sent to ',
                children: [
                  TextSpan(
                    text: widget.phone,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) _verify();
              },
              style: const TextStyle(fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: '······', counterText: ''),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _code.text.length == 6 && !_verifying ? _verify : null,
              child: _verifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => showGlassToast(context, 'Code resent'),
                child: const Text("Didn't get a code? Resend"),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo: enter any 6 digits.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
