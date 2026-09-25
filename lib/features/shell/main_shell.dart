import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../core/iconly.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _navVisible = true;

  /// Only the browsing tabs hide the bar; Cart keeps it because its
  /// Checkout panel sits right above it.
  bool get _canHide => widget.shell.currentIndex <= 1;

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final show = switch (n.direction) {
      ScrollDirection.reverse => false, // finger moving up: reading down the page
      ScrollDirection.forward => true,
      ScrollDirection.idle => n.metrics.pixels <= n.metrics.minScrollExtent ? true : _navVisible,
    };
    if (show != _navVisible && (_canHide || show)) setState(() => _navVisible = show);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final cartCount = ref.watch(cartCountProvider);
    const tabs = [
      (IconlyLight.home, 'Home'),
      (IconlyLight.bag, 'Shop'),
      (IconlyLight.buy, 'Cart'),
      (IconlyLight.profile, 'Profile'),
    ];
    final visible = _navVisible || !_canHide;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(onNotification: _onScroll, child: shell),
      bottomNavigationBar: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: GlassBox(
              shadow: true,
              borderRadius: BorderRadius.circular(34),
              tint: AppColors.glass(0.45),
              child: SizedBox(
                height: 68,
                child: Stack(
                  children: [
                    // Glass highlight that slides to the selected tab (iOS style).
                    AnimatedAlign(
                      alignment: Alignment(-1 + 2 * shell.currentIndex / (tabs.length - 1), 0),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      child: FractionallySizedBox(
                        widthFactor: 1 / tabs.length,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: AppColors.dark ? 0.22 : 0.3),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white.withValues(alpha: AppColors.dark ? 0.12 : 0.6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _NavItem(
                              icon: tabs[i].$1,
                              label: tabs[i].$2,
                              selected: shell.currentIndex == i,
                              badge: i == 2 ? cartCount : 0,
                              onTap: () {
                                setState(() => _navVisible = true);
                                shell.goBranch(i, initialLocation: i == shell.currentIndex);
                              },
                            ),
                          ),
                      ],
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: selected
            ? Column(
                key: const ValueKey('on'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              )
            : Center(
                key: const ValueKey('off'),
                child: BounceOnChange(
                  value: badge,
                  child: Badge(
                    isLabelVisible: badge > 0,
                    backgroundColor: AppColors.danger,
                    label: Text('$badge'),
                    child: Icon(icon, size: 26, color: AppColors.ink),
                  ),
                ),
              ),
      ),
    );
  }
}
