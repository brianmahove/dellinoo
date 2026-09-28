import 'package:flutter/material.dart';

/// The client's bag-and-smile mark, vendored as a flat image with a
/// transparent background (`assets/images/logo_icon.png`), so it can sit on
/// any surface — light, dark or the brand gradient.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo_icon.png', width: size, height: size, fit: BoxFit.contain);
  }
}

/// The full logo: bag mark, "Dellinoo" wordmark and the "Your One-Stop
/// Shopping Experience" caption, on a transparent background. Sized by [width].
///
/// The default is the wide lockup (bag beside the name) for headers; with
/// [stacked] the bag sits above the name and caption, for the splash.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.width, this.stacked = false});

  final double width;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      stacked ? 'assets/images/logo_stacked.png' : 'assets/images/logo_full.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}

/// The bag with floating category bubbles (phone, headphones, shoes, dress,
/// cart), used as the login screen's illustration.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo_hero.png', width: width, fit: BoxFit.contain);
  }
}
