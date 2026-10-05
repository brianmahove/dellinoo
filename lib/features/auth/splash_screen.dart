import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/push.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/motion.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // Firebase Auth persists the session on its own — a returning signed-in
      // customer should land straight on Home, not be sent through /login
      // again just because the splash screen didn't check.
      if (ref.read(authProvider) != null) {
        context.go('/home');
        // Launched by tapping a notification: open what it was about on top
        // of Home, so back still lands somewhere sensible.
        final route = Push.takePendingRoute();
        if (route != null) WidgetsBinding.instance.addPostFrameCallback((_) => Push.openRoute(route));
        return;
      }
      // First launch: explain how Dellinoo works before asking to sign in.
      context.go(hasSeenWelcome(ref.read(prefsProvider)) ? '/login' : '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Always white: the logo's dark-violet lettering needs a light background, even in dark mode.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // The full logo (bag, wordmark and caption) centred, as in the brand artwork.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: _Entrance(child: BrandLogo(stacked: true, width: MediaQuery.sizeOf(context).width * 0.78)),
              ),
            ),
            const Spacer(),
            _Entrance(
              delay: 350,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'by ${AppInfo.developer}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6B6D73),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and eases the child up from slightly small; shown as-is when the OS
/// "reduce motion" setting is on.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});

  final Widget child;

  /// Milliseconds to wait before starting.
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: child,
    );
  }
}
