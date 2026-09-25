import 'dart:ui';

import 'package:flutter/material.dart';

/// Saturation boost applied before blurring — this is what makes iOS glass
/// look vibrant (colours glow through) instead of a flat grey smear.
ColorFilter _saturate(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return ColorFilter.matrix([
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// iOS-style material: saturate, then blur.
ImageFilter iosGlassFilter(double sigma) => ImageFilter.compose(
  outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  inner: _saturate(1.8),
);

/// One shared instance so grouped backdrops can batch into a single pass.
final _defaultFilter = iosGlassFilter(GlassBox.defaultBlur);

/// Lets every [GlassBox] inside share one blur pass. Only wrap regions whose
/// glass sits on top of content drawn *before* it inside the same region
/// (e.g. a single product card: photo first, then its glass). Don't wrap a
/// whole scrolling screen: the shared snapshot is taken once, so glass further
/// down would blur stale content.
typedef GlassGroup = BackdropGroup;

/// iPhone-style frosted glass: saturated blur, light tint, soft top sheen,
/// a thin bright rim and a gentle drop shadow.
///
/// Only use it where content sits *behind* the widget (over photos, or above
/// scrolling content) — elsewhere the blur is invisible and just costs GPU time.
/// Inside a [GlassGroup] it joins that group's shared blur pass; otherwise it
/// blurs the live content behind it on its own.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.tint = const Color(0x8CFFFFFF),
    this.blur = defaultBlur,
    this.padding,
    this.border = true,
    this.shadow = false,
  });

  static const defaultBlur = 22.0;

  /// Set to false to swap every blur for a plain translucent fill — a quick
  /// escape hatch if low-end phones struggle.
  static bool enabled = true;

  final Widget child;
  final BorderRadius borderRadius;
  final Color tint;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = tint.computeLuminance() < 0.4;
    final content = padding == null ? child : Padding(padding: padding!, child: child);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? tint : tint.withValues(alpha: (tint.a + 0.35).clamp(0, 1)),
        borderRadius: borderRadius,
        // Soft light falling on the top half of the glass.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.10 : 0.30),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: border
          ? CustomPaint(
              foregroundPainter: _RimPainter(borderRadius, dark: dark),
              child: content,
            )
          : content,
    );

    if (enabled) {
      final filter = blur == defaultBlur ? _defaultFilter : iosGlassFilter(blur);
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropGroup.of(context) != null
            ? BackdropFilter.grouped(filter: filter, child: surface)
            : BackdropFilter(filter: filter, child: surface),
      );
    }
    if (!shadow) return surface;
    return CustomPaint(
      painter: _OuterShadowPainter(borderRadius, alpha: dark ? 0.18 : 0.1),
      child: surface,
    );
  }
}

/// Drop shadow painted only *outside* the glass. A normal BoxShadow also
/// fills the area under the box, which shows through translucent glass as a
/// dark smudge.
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter(this.radius, {required this.alpha});

  final BorderRadius radius;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect((Offset.zero & size).inflate(60)),
        Path()..addRRect(shape),
      ),
    );
    canvas.drawRRect(
      shape.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) => old.radius != radius || old.alpha != alpha;
}

/// Hairline rim that is bright where light hits (top-left) and fades out,
/// like the edge of a glass pane.
class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, {required this.dark});

  final BorderRadius radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.45 : 0.9),
          Colors.white.withValues(alpha: dark ? 0.08 : 0.2),
          Colors.white.withValues(alpha: dark ? 0.2 : 0.5),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect).deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius || old.dark != dark;
}

// ---------- Popups with a frosted back screen ----------

const _popupBlur = 18.0;
final _popupScrim = Colors.black.withValues(alpha: 0.12);

/// Blurs whatever is behind a popup, fading in/out with the route animation,
/// with the normal (tap-to-dismiss) barrier on top.
Widget _glassBarrier(Animation<double> animation, Widget barrier) {
  return Stack(
    fit: StackFit.expand,
    children: [
      AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final sigma = _popupBlur * animation.value + 0.01;
          return BackdropFilter(filter: iosGlassFilter(sigma), child: const SizedBox.expand());
        },
      ),
      barrier,
    ],
  );
}

class _GlassDialogRoute<T> extends DialogRoute<T> {
  _GlassDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
  });

  @override
  Widget buildModalBarrier() => _glassBarrier(animation!, super.buildModalBarrier());
}

class _GlassBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _GlassBottomSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.modalBarrierColor,
  });

  @override
  Widget buildModalBarrier() => _glassBarrier(animation!, super.buildModalBarrier());
}

/// Drop-in for [showDialog] with a frosted back screen.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _GlassDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: _popupScrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Drop-in for [showModalBottomSheet] with a frosted back screen.
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _GlassBottomSheetRoute<T>(
      builder: builder,
      isScrollControlled: isScrollControlled,
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      modalBarrierColor: _popupScrim,
    ),
  );
}

// ---------- Toasts ----------

/// Frosted floating toast (replaces plain SnackBars). Replaces any toast
/// already showing so rapid taps don't queue up.
void showGlassToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // The SnackBar itself is invisible; the GlassBox is the whole toast.
        // No clipping/elevation so its outer shadow and rim aren't cut off.
        backgroundColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: EdgeInsets.zero,
        duration: duration,
        persist: false,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        content: GlassBox(
          shadow: true,
          borderRadius: BorderRadius.circular(22),
          tint: Colors.white.withValues(alpha: 0.6),
          padding: EdgeInsets.fromLTRB(18, actionLabel == null ? 15 : 7, 7, actionLabel == null ? 15 : 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFF020910), fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (actionLabel != null)
                FilledButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction?.call();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      ),
    );
}
