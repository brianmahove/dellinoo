import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/glass.dart';
import '../../core/iconly.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    const tabs = [
      (IconlyLight.home, 'Home'),
      (IconlyLight.bag, 'Shop'),
      (IconlyLight.buy, 'Cart'),
      (IconlyLight.profile, 'Profile'),
    ];

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: GlassBox(
          shadow: true,
          borderRadius: BorderRadius.circular(34),
          tint: Colors.white.withValues(alpha: 0.45),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: tabs[i].$1,
                      label: tabs[i].$2,
                      selected: shell.currentIndex == i,
                      badge: i == 2 ? cartCount : 0,
                      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                    ),
                  ),
              ],
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
                    decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              )
            : Center(
                key: const ValueKey('off'),
                child: Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.danger,
                  label: Text('$badge'),
                  child: Icon(icon, size: 26, color: AppColors.ink),
                ),
              ),
      ),
    );
  }
}
