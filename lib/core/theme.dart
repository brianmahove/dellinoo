import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colours live here only. Swap them when the final logo arrives.
///
/// Most colours flip with [dark]; the app remounts when the mode changes
/// (see `main.dart`), so widgets can read these directly in `build`.
abstract final class AppColors {
  static bool dark = false;

  static const primary = Color(0xFFFFC107);

  /// Always-black. Use for anything drawn *on* yellow, and for surfaces
  /// that stay dark in both modes (e.g. the dark promo banner).
  static const black = Color(0xFF020910);
  static const sale = Color(0xFFE53935);
  static const danger = Color(0xFFE53950);

  static Color get primarySoft => dark ? const Color(0xFF3A300A) : const Color(0xFFFFF3CD);

  /// Gold for text/icons on normal surfaces, where pure yellow is hard to read.
  static Color get accent => dark ? primary : const Color(0xFFB98500);

  /// Main text colour (black in light mode, near-white in dark mode).
  static Color get ink => dark ? const Color(0xFFF3F3F5) : black;

  /// Text/icons drawn on an [ink]-filled surface.
  static Color get onInk => dark ? black : Colors.white;

  /// Secondary text. Darker than the palette's #929498 so it stays readable.
  static Color get muted => dark ? const Color(0xFFA3A5AB) : const Color(0xFF6B6D73);
  static Color get line => dark ? const Color(0xFF2E3036) : const Color(0xFFE6E0D9);
  static Color get background => dark ? const Color(0xFF0E0F12) : const Color(0xFFF2EEE9);
  static Color get surface => dark ? const Color(0xFF1A1C21) : Colors.white;
  static Color get field => dark ? const Color(0xFF262830) : const Color(0xFFEFEFEF);
  static Color get inStock => dark ? const Color(0xFF4ADE80) : const Color(0xFF1E8E52);
  static Color get inStockSoft => dark ? const Color(0xFF12301F) : const Color(0xFFE6F6EE);
  static Color get preorder => dark ? const Color(0xFFFFB547) : const Color(0xFFA35F00);
  static Color get preorderSoft => dark ? const Color(0xFF33260C) : const Color(0xFFFFF4DE);
  static Color get dangerSoft => dark ? const Color(0xFF3A1A1F) : const Color(0xFFFBD9DE);

  /// Frosted-glass fill at the given strength.
  static Color glass(double alpha) => dark
      ? const Color(0xFF1C1E24).withValues(alpha: (alpha + 0.15).clamp(0, 1))
      : Colors.white.withValues(alpha: alpha);

  /// Soft backgrounds behind product photos, picked per product.
  static List<Color> get tints => dark
      ? const [
          Color(0xFF2A2742),
          Color(0xFF3A3221),
          Color(0xFF1F2E3A),
          Color(0xFF263020),
          Color(0xFF3A252B),
          Color(0xFF2F2A25),
        ]
      : const [
          Color(0xFFDCD8F0),
          Color(0xFFF7E3B5),
          Color(0xFFCFE0EC),
          Color(0xFFD9E3C8),
          Color(0xFFF2D6DC),
          Color(0xFFE6DDD3),
        ];

  static Color tintFor(String id) => tints[id.hashCode.abs() % tints.length];
}

final _stadium = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());

/// Builds the theme for the current [AppColors.dark] mode.
ThemeData buildTheme() {
  final dark = AppColors.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.black,
        secondary: AppColors.ink,
        onSecondary: AppColors.onInk,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
      );
  final base = dark ? ThemeData(brightness: Brightness.dark).textTheme : ThemeData().textTheme;
  // Gilroy (from the design) is a paid font; Urbanist is the closest free match.
  // Gilroy (from the design) is a paid font; Urbanist is the closest free match.
  final text = GoogleFonts.urbanistTextTheme(base).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final buttonText = text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15);
  final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

  return ThemeData(
    useMaterial3: true,
    // iPhone-style slide for pushed pages (product page overrides with its
    // own grow transition; tabs use a fade-through).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlay,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? AppColors.line : AppColors.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? AppColors.muted : AppColors.black,
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
        // Black (not yellow) so links like "See all" stay readable outdoors.
        foregroundColor: AppColors.ink,
        textStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
          decorationThickness: 2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: AppColors.line),
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
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: AppColors.line, space: 1),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.black : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.field,
      ),
    ),
  );
}
