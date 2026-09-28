import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
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
  /// Checkout panel sits right above it, and Profile is short enough not to need it.
  bool get _canHide => const {0, 1, 3}.contains(widget.shell.currentIndex);

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
    final wishlistCount = ref.watch(wishlistProvider).length;
    const tabs = [
      (IconlyLight.home, 'Home'),
      (IconlyLight.bag, 'Shop'),
      (IconlyLight.buy, 'Cart'),
      (IconlyLight.heart, 'Wishlist'),
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
          child: DecoratedBox(
            // Solid, edge-to-edge bar — white in light mode, near-black in dark
            // mode — instead of the floating glass pill.
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: tabs[i].$1,
                          label: tabs[i].$2,
                          selected: shell.currentIndex == i,
                          badge: switch (i) {
                            2 => cartCount,
                            3 => wishlistCount,
                            _ => 0,
                          },
                          onTap: () {
                            setState(() => _navVisible = true);
                            shell.goBranch(i, initialLocation: i == shell.currentIndex);
                          },
                        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: BounceOnChange(
              value: badge,
              child: Badge(
                isLabelVisible: badge > 0,
                backgroundColor: AppColors.danger,
                label: Text('$badge'),
                child: Icon(icon, size: 22, color: selected ? AppColors.onPrimary : AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.muted,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
