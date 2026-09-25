import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/brand.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) context.go('/login');
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
              style: TextStyle(color: AppColors.ink, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            SizedBox(height: 4),
            Text('Shop the world, delivered in Zim', style: TextStyle(color: AppColors.ink, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
