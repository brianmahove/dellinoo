import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/payment_logos.dart';
import 'auth_widgets.dart';

/// Welcome screen shown on first launch: brand, three selling points, payment options.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _go(BuildContext context, WidgetRef ref, String route) async {
    await markWelcomeSeen(ref.read(prefsProvider));
    if (context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    children: [
                      const BrandLogo(width: 240),
                      const SizedBox(height: 8),
                      const BrandHero(width: 260),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accentOrange),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Welcome to Dellinoo!',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accentOrange),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Shop a wide range of quality products,\nall in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.35),
                      ),
                      const SizedBox(height: 20),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(
                              child: _Feature(icon: IconlyLight.buy, title: 'One-Stop\nShop'),
                            ),
                            VerticalDivider(color: AppColors.line, width: 1),
                            const Expanded(
                              child: _Feature(
                                icon: Icons.local_shipping_outlined,
                                title: 'Flexible\nDelivery Options',
                                badge: 'Nationwide',
                              ),
                            ),
                            VerticalDivider(color: AppColors.line, width: 1),
                            const Expanded(
                              child: _Feature(icon: IconlyLight.shield_done, title: 'Safe &\nReliable\nShopping'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _PaymentStrip(),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == 0 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.18),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.buttonGradient),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => _go(context, ref, '/signup'),
                            child: const SizedBox(
                              height: 56,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded, color: AppColors.onPrimary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => _go(context, ref, '/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.4),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text("Don't have an account? ", style: TextStyle(color: AppColors.ink)),
                          GestureDetector(
                            onTap: () => _go(context, ref, '/signup'),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, this.badge});

  final IconData icon;
  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
              child: Text(
                badge!,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF020910)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentStrip extends StatelessWidget {
  const _PaymentStrip();

  @override
  Widget build(BuildContext context) {
    Widget logo(PaymentMethod m) => Expanded(
      child: SizedBox(height: 30, child: Image.asset(m.logo!, fit: BoxFit.contain)),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 18, 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.buttonGradient),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white24,
                    child: Icon(IconlyLight.wallet, size: 18, color: AppColors.onPrimary),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Easy Payment Options',
                    style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              logo(PaymentMethod.ecocash),
              logo(PaymentMethod.onemoney),
              logo(PaymentMethod.innbucks),
              logo(PaymentMethod.card),
              const Expanded(child: CardBrandsChip()),
            ],
          ),
        ],
      ),
    );
  }
}
