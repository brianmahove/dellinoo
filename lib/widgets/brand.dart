import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Placeholder logo until the client supplies the real one.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.inverted = false});

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: inverted ? AppColors.ink : AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'D',
        style: TextStyle(
          color: inverted ? AppColors.primary : AppColors.ink,
          fontSize: size * 0.58,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 22});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Dellinoo',
      style: TextStyle(color: AppColors.ink, fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }
}
