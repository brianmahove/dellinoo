import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/payment_logos.dart';

/// Three-slide intro shown on first launch: what Dellinoo sells, the two
/// delivery speeds, and how to pay / get help.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markWelcomeSeen(ref.read(prefsProvider));
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(onPressed: last ? null : _finish, child: const Text('Skip')),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_ShopSlide(), _DeliverySlide(), _PaySlide()],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.ink : AppColors.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
                child: Text(last ? 'Get started' : 'Next'),
              ),
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
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ShopSlide extends StatelessWidget {
  const _ShopSlide();

  @override
  Widget build(BuildContext context) {
    Widget photo(String url, double size, double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: NetImage(url, fit: BoxFit.contain),
      ),
    );

    return _Slide(
      art: _Art(
        children: [
          Positioned(
            left: 6,
            top: 40,
            child: photo(
              'https://cdn.dummyjson.com/product-images/smartphones/iphone-13-pro/thumbnail.webp',
              110,
              -0.12,
            ),
          ),
          Positioned(
            right: 4,
            top: 20,
            child: photo(
              'https://cdn.dummyjson.com/product-images/mens-shoes/nike-air-jordan-1-red-and-black/thumbnail.webp',
              104,
              0.14,
            ),
          ),
          Positioned(
            bottom: 14,
            child: photo(
              "https://cdn.dummyjson.com/product-images/womens-dresses/black-women's-gown/thumbnail.webp",
              124,
              0.02,
            ),
          ),
        ],
      ),
      title: 'Shop the world,\ndelivered in Zim',
      body: 'Fashion, shoes, phones, laptops and more, at great prices.',
    );
  }
}

class _DeliverySlide extends StatelessWidget {
  const _DeliverySlide();

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, Color color, String title, String sub) => GlassBox(
      shadow: true,
      borderRadius: BorderRadius.circular(22),
      tint: AppColors.glass(0.85),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(sub, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return _Slide(
      art: _Art(
        children: [
          Positioned(
            top: 60,
            left: 10,
            child: option(IconlyBold.tick_square, AppColors.inStock, 'In stock', 'Delivered in 1–3 days'),
          ),
          Positioned(
            bottom: 60,
            right: 10,
            child: option(IconlyBold.send, AppColors.preorder, 'From China', 'Arrives in 2–3 weeks'),
          ),
        ],
      ),
      title: 'Two ways to get it',
      body: 'Every product shows when it will reach you, so there are no surprises.',
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
            child: Transform.rotate(angle: -0.1, child: chip(PaymentMethod.ecocash.logo, width: 110)),
          ),
          Positioned(top: 34, right: 18, child: Transform.rotate(angle: 0.1, child: chip(PaymentMethod.onemoney.logo))),
          Positioned(
            bottom: 70,
            left: 26,
            child: Transform.rotate(angle: 0.06, child: chip(PaymentMethod.innbucks.logo, width: 64)),
          ),
          Positioned(
            bottom: 90,
            right: 20,
            child: Transform.rotate(
              angle: -0.08,
              child: Column(
                children: [chip(PaymentMethod.card.logo, width: 88), const SizedBox(height: 8), const CardBrandsChip()],
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
