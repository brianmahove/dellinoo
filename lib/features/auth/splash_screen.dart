import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      // First launch: explain how Dellinoo works before asking to sign in.
      context.go(hasSeenWelcome(ref.read(prefsProvider)) ? '/login' : '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'by ${AppInfo.developer}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.black.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 84, inverted: true),
            SizedBox(height: 18),
            Text(
              'Dellinoo',
              style: TextStyle(color: AppColors.black, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            SizedBox(height: 4),
            Text('Shop the world, delivered in Zim', style: TextStyle(color: AppColors.black, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
