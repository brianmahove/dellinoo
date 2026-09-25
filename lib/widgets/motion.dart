import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'brand.dart';

/// True when the user asked the OS to reduce motion; decorative effects skip.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ---------------------------------------------------------------------------
// Press-down

/// Shrinks its child slightly while a finger is on it, then springs back.
/// Doesn't consume taps, so the child's own InkWell/GestureDetector still works.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.96});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counting money

/// Shows a price that rolls to its new value instead of jumping.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, this.style});

  final double value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(money(v), style: style),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer

/// A soft band of light that sweeps across [child] every few seconds.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.child, this.period = const Duration(milliseconds: 2800)});

  final Widget child;
  final Duration period;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        // Sweep during the first 40% of the period, rest the remainder.
        final t = (_c.value / 0.4).clamp(0.0, 1.0);
        final x = -1.0 + 3.0 * t;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 1, 0),
            end: Alignment(x, 0),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.75),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Heart burst

/// Little hearts that fly out from [center] (global coordinates) and fade.
void showHeartBurst(BuildContext context, Offset center) {
  if (reduceMotion(context)) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _HeartBurst(center: center, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _HeartBurst extends StatefulWidget {
  const _HeartBurst({required this.center, required this.onDone});

  final Offset center;
  final VoidCallback onDone;

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward().whenComplete(widget.onDone);
  static const _count = 7;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Stack(
            children: [
              for (var i = 0; i < _count; i++)
                () {
                  final angle = -math.pi / 2 + (i - (_count - 1) / 2) * 0.42;
                  final dist = 18 + 34 * t;
                  final pos = widget.center + Offset(math.cos(angle), math.sin(angle)) * dist;
                  final size = 9.0 + (i.isEven ? 3 : 0);
                  return Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Opacity(
                      opacity: (1 - _c.value).clamp(0.0, 1.0),
                      child: Icon(Icons.favorite, size: size, color: AppColors.danger),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawn tick + confetti (order placed)

/// A green tick that draws itself inside a circle that pops in.
class DrawnCheck extends StatefulWidget {
  const DrawnCheck({super.key, this.size = 110});

  final double size;

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final pop = Curves.elasticOut.transform((_c.value / 0.55).clamp(0.0, 1.0));
        final draw = Curves.easeOutCubic.transform(((_c.value - 0.35) / 0.65).clamp(0.0, 1.0));
        return Transform.scale(
          scale: pop,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: AppColors.inStockSoft, shape: BoxShape.circle),
            child: CustomPaint(painter: _CheckPainter(draw, AppColors.inStock)),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// One-shot confetti burst in the brand colours, falling from the top.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 90});

  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [AppColors.primary, AppColors.black, Color(0xFFFFE08A), Colors.white, Color(0xFF1E8E52)];
    _pieces = List.generate(
      widget.count,
      (_) => _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.25,
        speed: 0.7 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.25,
        spin: (r.nextDouble() - 0.5) * 14,
        size: 6 + r.nextDouble() * 7,
        color: colors[r.nextInt(colors.length)],
        round: r.nextBool(),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * local * p.speed;
      final x = size.width * (p.x + p.drift * local) + math.sin(local * 10 + p.x * 6) * 12;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - local * local).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Pull-to-refresh with the logo

/// Indicator for [CupertinoSliverRefreshControl]: the logo turns as you pull
/// and keeps spinning while refreshing.
Widget logoRefreshIndicator(
  BuildContext context,
  RefreshIndicatorMode mode,
  double pulledExtent,
  double refreshTriggerPullDistance,
  double refreshIndicatorExtent,
) {
  final pull = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
  return Center(
    child: Opacity(
      opacity: mode == RefreshIndicatorMode.inactive ? 0 : pull,
      child: mode == RefreshIndicatorMode.refresh || mode == RefreshIndicatorMode.armed
          ? const _SpinningLogo()
          : Transform.rotate(
              angle: pull * math.pi * 2,
              child: Transform.scale(scale: 0.6 + 0.4 * pull, child: const BrandMark(size: 36)),
            ),
    ),
  );
}

class _SpinningLogo extends StatefulWidget {
  const _SpinningLogo();

  @override
  State<_SpinningLogo> createState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<_SpinningLogo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: const BrandMark(size: 36));
}

// ---------------------------------------------------------------------------
// Circular theme reveal

/// Wraps the whole app. [ThemeRevealState.reveal] snapshots the current screen,
/// switches the theme underneath, then wipes the snapshot away in a growing
/// circle from the tap point.
final themeRevealKey = GlobalKey<ThemeRevealState>();

class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});

  final Widget child;

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  ui.Image? _snapshot;
  Offset _origin = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> reveal(Offset origin, VoidCallback switchTheme) async {
    final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    // This widget sits above MaterialApp, so read screen info from the View, not MediaQuery.
    final view = View.of(context);
    final reduced = view.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (boundary == null || reduced) {
      switchTheme();
      return;
    }
    final image = await boundary.toImage(pixelRatio: view.devicePixelRatio);
    if (!mounted) return;
    setState(() {
      _snapshot = image;
      _origin = origin;
    });
    switchTheme();
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() => _snapshot = null);
    image.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _boundary, child: widget.child),
          if (_snapshot != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _RevealPainter(_snapshot!, _origin, Curves.easeInOutCubic.transform(_c.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.image, this.origin, this.progress);

  final ui.Image image;
  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);
    canvas.saveLayer(Offset.zero & size, Paint());
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.fill);
    canvas.drawCircle(origin, maxRadius * progress, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter old) => old.progress != progress || old.image != image;
}
