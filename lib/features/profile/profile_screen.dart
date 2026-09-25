import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contact.dart';
import '../../core/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../core/iconly.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider);
    int count(bool Function(Order) test) => orders.where(test).length;

    void soon(String what) => showGlassToast(context, '$what — coming in the next build');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(26)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user == null ? '?' : user.name.split(' ').map((w) => w[0]).take(2).join(),
                    style: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: user == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to Dellinoo',
                              style: TextStyle(color: AppColors.onInk, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.black,
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(120, 38),
                              ),
                              onPressed: () => context.go('/login'),
                              child: const Text('Sign in'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(color: AppColors.onInk, fontSize: 19, fontWeight: FontWeight.w700),
                            ),
                            Text(user.phone, style: TextStyle(color: AppColors.onInk.withValues(alpha: 0.7))),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('My orders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    TextButton(onPressed: () => context.push('/orders'), child: const Text('View all')),
                  ],
                ),
                Row(
                  children: [
                    _OrderShortcut(
                      IconlyLight.wallet,
                      'Paid',
                      count((o) => o.status == OrderStatus.paid || o.status == OrderStatus.placed),
                    ),
                    _OrderShortcut(
                      IconlyLight.bag_2,
                      'Processing',
                      count(
                        (o) => {
                          OrderStatus.processing,
                          OrderStatus.boughtInChina,
                          OrderStatus.inTransit,
                          OrderStatus.arrivedZim,
                        }.contains(o.status),
                      ),
                    ),
                    _OrderShortcut(
                      Icons.local_shipping_outlined,
                      'On the way',
                      count((o) => o.status == OrderStatus.outForDelivery),
                    ),
                    _OrderShortcut(
                      IconlyLight.tick_square,
                      'Delivered',
                      count((o) => o.status == OrderStatus.delivered),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Group([
            _Item(IconlyLight.paper, 'My orders', () => context.push('/orders')),
            _Item(IconlyLight.heart, 'Wishlist', () => context.push('/wishlist')),
            _Item(IconlyLight.location, 'Delivery addresses', () => soon('Addresses'), subtitle: mockAddress.oneLine),
          ]),
          _Group([
            _Item(IconlyLight.chat, 'Chat with us on WhatsApp', () => openWhatsApp('Hi Dellinoo, I have a question.')),
            _Item(IconlyLight.info_square, 'Help & FAQs', () => soon('Help')),
            _Item(Icons.local_shipping_outlined, 'Delivery information', () => soon('Delivery info')),
          ]),
          _Group([
            _Item(
              AppColors.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              'Appearance',
              () => _showAppearanceSheet(context, ref),
              subtitle: switch (ref.watch(themeModeProvider)) {
                ThemeMode.system => 'Same as phone',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
            ),
            SwitchListTile(
              secondary: Icon(IconlyLight.download, color: AppColors.ink),
              title: Text(
                'Data saver',
                style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Smaller photos to save mobile data',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              value: ref.watch(dataSaverProvider),
              onChanged: ref.read(dataSaverProvider.notifier).set,
            ),
            _Item(IconlyLight.setting, 'Settings', () => soon('Settings')),
            _Item(IconlyLight.info_circle, 'About Dellinoo', () => soon('About')),
            if (user != null)
              _Item(IconlyLight.logout, 'Sign out', () {
                ref.read(authProvider.notifier).signOut();
                context.go('/login');
              }, danger: true),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Text('Dellinoo v1.0.0', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          // Room to scroll the last items clear of the floating nav bar.
          SizedBox(height: kNavBarSpace + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _OrderShortcut extends StatelessWidget {
  const _OrderShortcut(this.icon, this.label, this.count);

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push('/orders'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: Icon(icon, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.items);

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(children: items),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, this.onTap, {this.subtitle, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.sale : AppColors.ink;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      trailing: danger ? null : Icon(IconlyLight.arrow_right_2, color: AppColors.muted),
    );
  }
}

void _showAppearanceSheet(BuildContext context, WidgetRef ref) {
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
                      PillChip(
                        label: label,
                        selected: mode == m,
                        dense: true,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          ref.read(themeModeProvider.notifier).set(m);
                        },
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
