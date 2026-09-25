import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
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
