import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colours live here only. Swap them when the final logo arrives.
abstract final class AppColors {
  static const primary = Color(0xFFFFC107);
  static const primarySoft = Color(0xFFFFF3CD);

  /// Darker gold for text/icons on light surfaces, where pure yellow is hard to read.
  static const accent = Color(0xFFE0A200);
  static const ink = Color(0xFF020910);
  static const muted = Color(0xFF929498);
  static const line = Color(0xFFE6E0D9);
  static const background = Color(0xFFF2EEE9);
  static const field = Color(0xFFEFEFEF);
  static const inStock = Color(0xFF1E9E5A);
  static const inStockSoft = Color(0xFFE6F6EE);
  static const preorder = Color(0xFFB86E00);
  static const preorderSoft = Color(0xFFFFF4DE);
  static const sale = Color(0xFFE53935);
  static const danger = Color(0xFFE53950);
  static const dangerSoft = Color(0xFFFBD9DE);

  /// Soft backgrounds behind product photos, picked per product.
  static const tints = [
    Color(0xFFDCD8F0),
    Color(0xFFF7E3B5),
    Color(0xFFCFE0EC),
    Color(0xFFD9E3C8),
    Color(0xFFF2D6DC),
    Color(0xFFE6DDD3),
  ];

  static Color tintFor(String id) => tints[id.hashCode.abs() % tints.length];
}

/// Font family used across the app. Gilroy (from the design) is a paid font;
/// Urbanist is the closest free match. Swap here if a Gilroy licence is bought.
TextTheme _textTheme() => GoogleFonts.urbanistTextTheme();

final _stadium = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.ink,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
  );
  final text = _textTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final buttonText = text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15);

  return ThemeData(
    useMaterial3: true,
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
          (s) => s.contains(WidgetState.disabled) ? AppColors.muted : AppColors.ink,
        ),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
        shape: _stadium,
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(buttonText),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.field,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
      labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      actionTextColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
      ),
    ),
  );
}
