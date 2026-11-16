import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/payment_logos.dart';

/// Single welcome screen shown on first launch: how to pay and get help.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await markWelcomeSeen(ref.read(prefsProvider));
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: _PaySlide()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: FilledButton(onPressed: () => _finish(context, ref), child: const Text('Get started')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(child: Center(child: art)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Yellow disc with content floating on top — shared backdrop for the slides.
class _Art extends StatelessWidget {
  const _Art({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
              shape: BoxShape.circle,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _PaySlide extends StatelessWidget {
  const _PaySlide();

  @override
  Widget build(BuildContext context) {
    Widget chip(String asset, {double width = 96}) => Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );

    return _Slide(
      art: _Art(
        children: [
          Positioned(
            top: 50,
            left: 16,
            child: Transform.rotate(angle: -0.1, child: chip(PaymentMethod.ecocash.logo!, width: 110)),
          ),
          Positioned(
            top: 34,
            right: 18,
            child: Transform.rotate(angle: 0.1, child: chip(PaymentMethod.onemoney.logo!)),
          ),
          Positioned(
            bottom: 70,
            left: 26,
            child: Transform.rotate(angle: 0.06, child: chip(PaymentMethod.innbucks.logo!, width: 64)),
          ),
          Positioned(
            bottom: 90,
            right: 20,
            child: Transform.rotate(
              angle: -0.08,
              child: Column(
                children: [
                  chip(PaymentMethod.card.logo!, width: 88),
                  const SizedBox(height: 8),
                  const CardBrandsChip(),
                ],
              ),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Center(child: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 40)),
          ),
        ],
      ),
      title: 'Pay your way,\nhelp on WhatsApp',
      body: 'EcoCash, OneMoney, InnBucks or card. Questions? Chat with us anytime.',
    );
  }
}
