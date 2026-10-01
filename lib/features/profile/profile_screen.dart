import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contact.dart';
import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../core/iconly.dart';
import '../orders/orders_screen.dart' show OrderStatusFilter;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider);
    final addresses = ref.watch(addressBookProvider);
    final defaultAddress = addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
    int count(bool Function(OrderStatus) test) => orders.where((o) => test(o.status)).length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 0),
            decoration: BoxDecoration(
              // Light lavender-to-peach tint (same family as the brand
              // gradient, just much lighter) so dark text/icons read clearly.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primarySoft, const Color(0xFFFFE9D6)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: user == null ? null : () => context.push('/account'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary,
                        backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                        child: user?.photoUrl != null
                            ? null
                            : Text(
                                user == null ? '?' : user.name.split(' ').map((w) => w[0]).take(2).join(),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
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
                                    style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 140,
                                    child: GradientButton(
                                      height: 40,
                                      colors: AppColors.orangeGradient,
                                      trailingIcon: IconlyLight.arrow_right,
                                      onPressed: () => context.go('/login'),
                                      child: const Text('Sign in', style: TextStyle(fontSize: 14)),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(color: AppColors.ink, fontSize: 19, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    user.phone.isEmpty ? (user.email ?? '') : user.phone,
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ],
                              ),
                      ),
                      if (user != null) Icon(IconlyLight.arrow_right_2, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
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
                    _OrderShortcut(IconlyLight.wallet, OrderStatusFilter.paid, count(OrderStatusFilter.paid.matches)),
                    _OrderShortcut(
                      IconlyLight.bag_2,
                      OrderStatusFilter.processing,
                      count(OrderStatusFilter.processing.matches),
                      orange: true,
                    ),
                    _OrderShortcut(
                      Icons.local_shipping_outlined,
                      OrderStatusFilter.onTheWay,
                      count(OrderStatusFilter.onTheWay.matches),
                    ),
                    _OrderShortcut(
                      IconlyLight.tick_square,
                      OrderStatusFilter.delivered,
                      count(OrderStatusFilter.delivered.matches),
                      orange: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Group([
            // Icons alternate orange / violet down the menu (the `orange` flag).
            _Item(IconlyLight.paper, 'My orders', () => context.push('/orders'), orange: true),
            _Item(IconlyLight.heart, 'Wishlist', () => context.go('/wishlist')),
            _Item(
              IconlyLight.location,
              'Delivery addresses',
              () => context.push('/addresses'),
              subtitle: defaultAddress?.address.oneLine ?? 'Add a delivery address',
              orange: true,
            ),
          ]),
          _Group([
            _Item(
              IconlyLight.search,
              'Request an item',
              () => context.push('/request-item'),
              subtitle: 'Send a link, get a quote',
            ),
            _Item(
              IconlyLight.add_user,
              'Invite friends',
              () {
                if (user == null) {
                  context.push('/login');
                  return;
                }
                // A short, stable code derived from the account id.
                final code = 'DL${user.uid.substring(0, 6).toUpperCase()}';
                shareToWhatsApp(
                  'I shop China-to-Zimbabwe on Dellinoo — clothes, phones, shoes and more. '
                  'Tell them my code $code when you order!',
                );
              },
              subtitle: 'Share Dellinoo on WhatsApp',
              orange: true,
            ),
            _Item(IconlyLight.chat, 'Chat with us on WhatsApp', () => openWhatsApp('Hi Dellinoo, I have a question.')),
            _Item(IconlyLight.info_square, 'Help & FAQs', () => context.push('/help'), orange: true),
            _Item(Icons.local_shipping_outlined, 'Delivery information', () => context.push('/delivery-info')),
          ]),
          _Group([
            // Appearance and data saver live on the Settings screen now, so
            // each preference has exactly one home.
            _Item(
              IconlyLight.setting,
              'Settings',
              () => context.push('/settings'),
              subtitle: 'Appearance, data, privacy',
              orange: true,
            ),
            _Item(IconlyLight.info_circle, 'About Dellinoo', () => context.push('/about')),
            if (user != null)
              _Item(IconlyLight.logout, 'Sign out', () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              }, danger: true),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppInfo.name} v${AppInfo.version} · Made by ',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                PressScale(
                  child: InkWell(
                    onTap: () => openLink(AppInfo.developerUrl),
                    child: ShimmerSweep(
                      child: Text(
                        AppInfo.developer,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Room to scroll the last items clear of the floating nav bar.
          SizedBox(height: kNavBarSpace + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _OrderShortcut extends StatelessWidget {
  const _OrderShortcut(this.icon, this.filter, this.count, {this.orange = false});

  final IconData icon;
  final OrderStatusFilter filter;
  final int count;
  final bool orange;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push('/orders', extra: filter),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: Icon(icon, color: orange ? AppColors.accentOrange : AppColors.accent),
              ),
              const SizedBox(height: 6),
              Text(filter.label, style: const TextStyle(fontSize: 12.5)),
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
    // Material (not a decorated Container) so the ListTiles' tap ripples show.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(children: items),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, this.onTap, {this.subtitle, this.danger = false, this.orange = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  /// Orange icon instead of violet, so the list alternates.
  final bool orange;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.sale : AppColors.ink;
    return ListTile(
      onTap: onTap,
      // Icons alternate brand violet / orange; "Sign out" stays red as a destructive action.
      leading: Icon(icon, color: danger ? AppColors.sale : (orange ? AppColors.accentOrange : AppColors.accent)),
      title: Text(
        title,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      trailing: danger ? null : Icon(IconlyLight.arrow_right_2, color: AppColors.muted),
    );
  }
}
