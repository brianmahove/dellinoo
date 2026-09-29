import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ported from the customer app's `lib/core/theme.dart` (light mode only —
/// the admin panel doesn't need a dark-mode toggle). Kept in sync by hand;
/// see the note in shell.dart about the two apps not sharing code yet.
abstract final class AppColors {
  static const primary = Color(0xFF5B21D6);
  static const primaryLight = Color(0xFF8B5CF6);
  static const accentOrange = Color(0xFFFF8A00);

  static const brandGradient = [primary, accentOrange];
  static const buttonGradient = [primaryLight, primary];

  static const onPrimary = Colors.white;
  static const black = Color(0xFF020910);
  static const danger = Color(0xFFE53950);

  static const primarySoft = Color(0xFFEDE4FB);
  static const tint = Color(0xFFF1F0FB);
  static const accent = primary;
  static const ink = black;
  static const onInk = Colors.white;
  static const muted = Color(0xFF6B6D73);
  static const line = Color(0xFFE8E6F2);
  static const background = Colors.white;
  static const surface = Color(0xFFF5F4FB);
  static const field = Color(0xFFEFEFEF);
  static const inStock = Color(0xFF1E8E52);
  static const inStockSoft = Color(0xFFE6F6EE);
  static const preorder = Color(0xFFA35F00);
  static const preorderSoft = Color(0xFFFFF4DE);
  static const dangerSoft = Color(0xFFFBD9DE);
}

final _stadium = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());

ThemeData buildAdminTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.ink,
    onSecondary: AppColors.onInk,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );
  final text = GoogleFonts.urbanistTextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final buttonText = text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? AppColors.line : AppColors.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? AppColors.muted : AppColors.onPrimary,
        ),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
        shape: _stadium,
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(buttonText),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: buttonText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.tint, // pale lavender, same as the customer app's login fields
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      hintStyle: TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerTheme: DividerThemeData(color: AppColors.line, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      actionTextColor: AppColors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted, fontSize: 12),
      indicatorColor: AppColors.primarySoft,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
  );
}

/// Violet-to-orange pill button, matching the customer app's `GradientButton`.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.colors = AppColors.buttonGradient,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: AppColors.onPrimary, size: 18), const SizedBox(width: 8)],
                    DefaultTextStyle(
                      style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded status pill, used for stock status / order status badges.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
