import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/contact.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/motion.dart';

/// Profile → "Settings": every preference in one place. Appearance and data
/// saver used to sit on the Profile list itself; they live here now so there
/// is only ever one home for a setting.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final recentlyViewed = ref.watch(recentlyViewedProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    return Scaffold(
      appBar: const PageHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const _GroupTitle(IconlyLight.show, 'Appearance'),
          _Card([
            _Tile(
              icon: AppColors.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              title: 'Theme',
              subtitle: switch (ref.watch(themeModeProvider)) {
                ThemeMode.system => 'Same as phone',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              onTap: () => showAppearanceSheet(context, ref),
            ),
            _SwitchTile(
              icon: IconlyLight.star,
              title: 'Visual effects',
              subtitle: 'Frosted blur on cards and menus. Turn off if the app feels slow.',
              value: ref.watch(glassEffectsProvider),
              onChanged: ref.read(glassEffectsProvider.notifier).set,
            ),
            _SwitchTile(
              icon: IconlyLight.activity,
              title: 'Reduce motion',
              subtitle: 'Skip confetti, shimmer and other decorative animations.',
              value: ref.watch(reduceMotionProvider),
              onChanged: ref.read(reduceMotionProvider.notifier).set,
            ),
          ]),

          const _GroupTitle(IconlyLight.notification, 'Notifications'),
          _Card([
            // Order updates have no switch: they're about money the customer
            // already paid. Android's own app settings can still mute them.
            if (user != null)
              _SwitchTile(
                icon: IconlyLight.heart,
                title: 'Price drop alerts',
                subtitle: 'When something on your wishlist gets cheaper',
                value: ref.watch(priceDropAlertsProvider),
                onChanged: ref.read(priceDropAlertsProvider.notifier).set,
              ),
            _SwitchTile(
              icon: IconlyLight.discount,
              title: 'Deals & offers',
              subtitle: 'Sales and new arrivals from Dellinoo',
              value: ref.watch(dealsAlertsProvider),
              onChanged: ref.read(dealsAlertsProvider.notifier).set,
            ),
          ]),

          const _GroupTitle(IconlyLight.download, 'Data'),
          _Card([
            _SwitchTile(
              icon: IconlyLight.image,
              title: 'Data saver',
              subtitle: 'Smaller photos to save mobile data',
              value: ref.watch(dataSaverProvider),
              onChanged: ref.read(dataSaverProvider.notifier).set,
            ),
            _Tile(
              icon: IconlyLight.time_circle,
              title: 'Clear recently viewed',
              subtitle: recentlyViewed.isEmpty ? 'Nothing saved yet' : '${recentlyViewed.length} products',
              onTap: recentlyViewed.isEmpty
                  ? null
                  : () => _confirmClear(
                      context,
                      title: 'Clear recently viewed?',
                      message: 'The products you have looked at recently will stop showing on Home.',
                      onConfirm: () {
                        ref.read(recentlyViewedProvider.notifier).clear();
                        showGlassToast(context, 'Recently viewed cleared');
                      },
                    ),
            ),
            _Tile(
              icon: IconlyLight.search,
              title: 'Clear recent searches',
              subtitle: recentSearches.isEmpty ? 'Nothing saved yet' : '${recentSearches.length} searches',
              onTap: recentSearches.isEmpty
                  ? null
                  : () => _confirmClear(
                      context,
                      title: 'Clear recent searches?',
                      message: 'Your saved searches will no longer appear under the search bar.',
                      onConfirm: () {
                        ref.read(recentSearchesProvider.notifier).clear();
                        showGlassToast(context, 'Recent searches cleared');
                      },
                    ),
            ),
            _Tile(
              icon: IconlyLight.delete,
              title: 'Clear cached photos',
              subtitle: 'Frees up space. Photos download again as you browse.',
              onTap: () {
                // Both the live cache and the decoded-image cache; nothing the
                // customer owns is touched.
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                showGlassToast(context, 'Cached photos cleared');
              },
            ),
          ]),

          if (user != null) ...[
            const _GroupTitle(IconlyLight.profile, 'Account'),
            _Card([
              _Tile(
                icon: IconlyLight.user,
                title: 'Your account',
                subtitle: user.email ?? user.name,
                onTap: () => context.push('/account'),
              ),
              _Tile(icon: IconlyLight.location, title: 'Delivery addresses', onTap: () => context.push('/addresses')),
              _Tile(
                icon: IconlyLight.logout,
                title: 'Sign out',
                danger: true,
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ]),
          ],

          const _GroupTitle(IconlyLight.shield_done, 'Privacy & legal'),
          _Card([
            _Tile(
              icon: IconlyLight.document,
              title: 'Privacy policy',
              trailing: Icons.open_in_new,
              onTap: () => _openLink(context, AppInfo.privacyUrl),
            ),
            _Tile(
              icon: IconlyLight.delete,
              title: 'How to delete your data',
              trailing: Icons.open_in_new,
              onTap: () => _openLink(context, AppInfo.dataDeletionUrl),
            ),
            _Tile(
              icon: IconlyLight.info_circle,
              title: 'About Dellinoo',
              subtitle: 'Version ${AppInfo.version}',
              onTap: () => context.push('/about'),
            ),
          ]),

          const SizedBox(height: 8),
          Center(
            child: Text(
              '${AppInfo.name} v${AppInfo.version}',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, String url) async {
  final ok = await openLink(url);
  if (!ok && context.mounted) showGlassToast(context, 'Could not open the page');
}

Future<void> _confirmClear(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) async {
  final ok = await showGlassDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Clear')),
      ],
    ),
  );
  if (ok == true && context.mounted) onConfirm();
}

/// The Light / Dark / Same as phone picker, with the circular theme wipe.
/// Lives here because Settings owns appearance now; Profile no longer shows it.
void showAppearanceSheet(BuildContext context, WidgetRef ref) {
  showGlassBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (_, ref, _) {
        final mode = ref.watch(themeModeProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (m, label) in const [
                      (ThemeMode.system, 'Same as phone'),
                      (ThemeMode.light, 'Light'),
                      (ThemeMode.dark, 'Dark'),
                    ])
                      Builder(
                        builder: (pillContext) => PillChip(
                          label: label,
                          selected: mode == m,
                          dense: true,
                          onTap: () async {
                            final box = pillContext.findRenderObject() as RenderBox?;
                            final origin = box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset.zero;
                            final notifier = ref.read(themeModeProvider.notifier);
                            Navigator.of(sheetContext).pop();
                            // Let the sheet slide away, then wipe to the new theme
                            // in a circle growing from the tapped pill.
                            await Future<void>.delayed(const Duration(milliseconds: 280));
                            await themeRevealKey.currentState?.reveal(origin, () => notifier.set(m));
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.accent),
        const SizedBox(width: 9),
        Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// A Material (not a coloured box) so the tiles inside can paint their ink.
class _Card extends StatelessWidget {
  const _Card(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        const SizedBox(height: 4),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.line, indent: 60, endIndent: 16),
          children[i],
        ],
        const SizedBox(height: 4),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = danger ? AppColors.danger : AppColors.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: danger ? AppColors.danger : AppColors.accent),
        title: Text(
          title,
          style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
        trailing: Icon(trailing ?? IconlyLight.arrow_right_2, size: trailing == null ? 20 : 17, color: AppColors.muted),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    secondary: Icon(icon, color: AppColors.accent),
    title: Text(
      title,
      style: TextStyle(color: AppColors.ink, fontSize: 14.5, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
  );
}
