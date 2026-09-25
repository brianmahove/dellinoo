import 'package:flutter/material.dart';

/// Keeps every tab alive (like IndexedStack, so scroll positions survive) but
/// switches with a "fade through": the old tab fades out, then the new one
/// fades in while growing slightly — the standard motion for bottom nav tabs.
class FadeThroughTabs extends StatefulWidget {
  const FadeThroughTabs({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughTabs> createState() => _FadeThroughTabsState();
}

class _FadeThroughTabsState extends State<FadeThroughTabs> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late int _previous = widget.currentIndex;

  @override
  void didUpdateWidget(FadeThroughTabs old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previous = old.currentIndex;
      _c.forward(from: 0);
    }
  }

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
        final t = _c.value;
        // First 35%: outgoing fades out. Remaining 65%: incoming fades + scales in.
        final outOpacity = (1 - t / 0.35).clamp(0.0, 1.0);
        final inT = Curves.easeOutCubic.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _tab(i, outOpacity: outOpacity, inT: inT, animating: _c.isAnimating),
          ],
        );
      },
    );
  }

  Widget _tab(int i, {required double outOpacity, required double inT, required bool animating}) {
    final current = i == widget.currentIndex;
    final leaving = animating && i == _previous && !current;
    final visible = current || leaving;
    Widget child = widget.children[i];
    if (current && animating) {
      child = Opacity(
        opacity: inT,
        child: Transform.scale(scale: 0.94 + 0.06 * inT, child: child),
      );
    } else if (leaving) {
      child = Opacity(opacity: outOpacity, child: child);
    }
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(ignoring: !current, child: child),
      ),
    );
  }
}
