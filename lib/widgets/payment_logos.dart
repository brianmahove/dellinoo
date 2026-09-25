import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Visa mark (Font Awesome brand icon, CC BY 4.0) in Visa blue.
class VisaLogo extends StatelessWidget {
  const VisaLogo({super.key, this.height = 20});

  final double height;

  @override
  Widget build(BuildContext context) => FaIcon(FontAwesomeIcons.ccVisa, size: height, color: const Color(0xFF1A1F71));
}

/// Mastercard mark: two overlapping circles in the official colours.
class MastercardLogo extends StatelessWidget {
  const MastercardLogo({super.key, this.height = 16});

  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(height * 1.62, height), painter: _MastercardPainter());
}

class _MastercardPainter extends CustomPainter {
  static const _red = Color(0xFFEB001B);
  static const _yellow = Color(0xFFF79E1B);
  static const _overlap = Color(0xFFFF5F00);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Offset(r, r);
    final right = Offset(size.width - r, r);
    canvas.drawCircle(left, r, Paint()..color = _red);
    canvas.drawCircle(right, r, Paint()..color = _yellow);
    // The lens where the circles meet is orange.
    final lens = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: left, radius: r)),
      Path()..addOval(Rect.fromCircle(center: right, radius: r)),
    );
    canvas.drawPath(lens, Paint()..color = _overlap);
  }

  @override
  bool shouldRepaint(_MastercardPainter old) => false;
}

/// White chip with the Visa and Mastercard marks side by side.
class CardBrandsChip extends StatelessWidget {
  const CardBrandsChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E0D9)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [VisaLogo(height: 18), SizedBox(width: 6), MastercardLogo(height: 14)],
      ),
    );
  }
}
