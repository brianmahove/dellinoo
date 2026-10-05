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

  /// Deep violet — main brand colour (buttons, active states, links),
  /// sampled from the Dellinoo bag mark. Legible on both light and dark
  /// surfaces, so (like the old yellow) it stays a plain const.
  static const primary = Color(0xFF5B21D6);

  /// Lighter violet — gradient partner for [primary] (buttons, dark-mode tints).
  static const primaryLight = Color(0xFF8B5CF6);

  /// Orange — the other end of the logo's violet-to-orange gradient. Used
  /// sparingly for brand moments (logo, splash, CTA pop), not as a workhorse UI colour.
  static const accentOrange = Color(0xFFFF8A00);

  /// Warm gold, kept from the old yellow palette for ratings/stars only.
  static const gold = Color(0xFFFFC107);

  /// Violet-to-orange, for the logo wordmark and full-bleed brand moments.
  static const brandGradient = [primary, accentOrange];

  /// Two-tone violet, for solid brand buttons (sign up / log in).
  static const buttonGradient = [primaryLight, primary];

  /// Amber-to-orange, for the pop-out action beside a violet one ("Buy Now").
  static const orangeGradient = [Color(0xFFFFB020), accentOrange];

  /// Always-white. Use for anything drawn *on* [primary] or [accentOrange].
  static const onPrimary = Colors.white;

  /// Always-black. Use for surfaces that stay dark in both modes (e.g. the
  /// dark promo banner) — not for text on [primary] any more, see [onPrimary].
  static const black = Color(0xFF020910);
  static const sale = Color(0xFFE53935);
  static const danger = Color(0xFFE53950);

  static Color get primarySoft => dark ? const Color(0xFF2A1F52) : const Color(0xFFEDE4FB);

  /// Slightly deeper lavender than [surface], for small controls (circle
  /// buttons, search pill) on the white page. [surface] in dark mode.
  static Color get tint => dark ? surface : const Color(0xFFF1F0FB);

  /// Readable violet for text/icons on normal surfaces.
  static Color get accent => dark ? primaryLight : primary;

  /// Main text colour (black in light mode, near-white in dark mode).
  static Color get ink => dark ? const Color(0xFFF3F3F5) : black;

  /// Text/icons drawn on an [ink]-filled surface.
  static Color get onInk => dark ? black : Colors.white;

  /// Secondary text. Darker than the palette's #929498 so it stays readable.
  static Color get muted => dark ? const Color(0xFFA3A5AB) : const Color(0xFF6B6D73);
  static Color get line => dark ? const Color(0xFF2E3036) : const Color(0xFFE8E6F2);

  /// Page background: pure white in light mode.
  static Color get background => dark ? const Color(0xFF0E0F12) : Colors.white;

  /// Cards, panels and bars. A pale lavender in light mode so they stand out
  /// from the white page (a white surface would disappear on it).
  static Color get surface => dark ? const Color(0xFF1A1C21) : const Color(0xFFF5F4FB);
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

  /// Reads colours from the light palette when [light] is true, whatever the
  /// app's mode — for overlays drawn on a light photo background (e.g. a
  /// white-background product photo in dark mode, where dark glass and
  /// near-white text would vanish). Pair with `OnLightBackdrop.of(context)`.
  static T lightIf<T>(bool light, T Function() read) {
    if (!light || !dark) return read();
    dark = false;
    try {
      return read();
    } finally {
      dark = true;
    }
  }
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
        onPrimary: AppColors.onPrimary,
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
          (s) => s.contains(WidgetState.disabled) ? AppColors.muted : AppColors.onPrimary,
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
      // Same look as the login/signup `AuthField`: pale lavender, 16px corners, violet ring on focus.
      fillColor: AppColors.dark ? AppColors.field : const Color(0xFFF1F0FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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
        (s) => s.contains(WidgetState.selected) ? AppColors.accentOrange : AppColors.muted,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.onPrimary : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.field,
      ),
    ),
  );
}
