import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'admins_screen.dart';
import 'coupons_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'requests_screen.dart';
import 'delivery_areas_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'theme.dart';
import 'user_avatar.dart';
import 'iconly.dart';

/// Below this width the shell uses a bottom nav bar (mobile web); at or
/// above it, a sidebar (desktop web) — matches Material's own "compact vs.
/// medium" breakpoint at 600, with a little headroom for the sidebar's width.
const _wideBreakpoint = 720.0;
const _topNavHeight = 72.0;

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _destinations = [
  _Destination(IconlyLight.category, IconlyBold.category, 'Dashboard'),
  _Destination(IconlyLight.bag, IconlyBold.bag, 'Products'),
  _Destination(IconlyLight.paper, IconlyBold.paper, 'Orders'),
  _Destination(IconlyLight.user_1, IconlyBold.user_3, 'Customers'),
  _Destination(IconlyLight.location, IconlyBold.location, 'Delivery areas'),
  _Destination(IconlyLight.discount, IconlyBold.discount, 'Coupons'),
  _Destination(IconlyLight.discovery, IconlyBold.discovery, 'Requests'),
  _Destination(IconlyLight.shield_done, IconlyBold.shield_done, 'Admins'),
];
const _screens = [
  DashboardScreen(),
  ProductsScreen(),
  OrdersScreen(),
  CustomersScreen(),
  DeliveryAreasScreen(),
  CouponsScreen(),
  RequestsScreen(),
  AdminsScreen(),
  AccountScreen(), // not in the nav; opened from the avatar
];

/// Index of [AccountScreen] in [_screens] (one past the nav destinations).
const _accountIndex = 8;

/// Signed-in shell: checks the `admins/{email}` allowlist (mirrors
/// firestore.rules' `isAdmin()`) before showing any admin screen — this is a
/// UX check only, the real enforcement is the security rules themselves, so
/// this can never be the only thing standing between a stranger and the data.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user});

  final User user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  /// Fetched once. Creating this future inside build() restarted it on every
  /// setState (each tab click), flashing the spinner and discarding the pages.
  late final Future<DocumentSnapshot<Map<String, dynamic>>>? _adminCheck = widget.user.email == null
      ? null
      : FirebaseFirestore.instance.collection('admins').doc(widget.user.email).get();

  /// Tabs opened so far. Each is built on first visit and then kept alive in an
  /// IndexedStack, so switching tabs doesn't rebuild the screen or reload its
  /// Firestore stream (which is what made pages flash back to a spinner).
  final _visited = <int>{0};

  Widget _body() {
    _visited.add(_index);
    return IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _screens.length; i++) _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email;
    if (email == null) return _denied('This account has no email address.');

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _adminCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data?.exists != true) return _denied('$email is not an admin.');

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return wide ? _wideLayout(context) : _narrowLayout(context);
          },
        );
      },
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tint,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _TopNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              onAccount: () => setState(() => _index = _accountIndex),
              user: widget.user,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 12)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text('Dellinoo Admin'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen(showBack: true))),
            icon: const Icon(IconlyLight.profile),
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }

  Widget _denied(String reason) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.dangerSoft, shape: BoxShape.circle),
                child: const Icon(IconlyLight.danger, size: 30, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              const Text('Access denied', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                reason,
                style: TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop-web top bar: logo, horizontal nav links, avatar menu — replaces
/// the old NavigationRail sidebar.
class _TopNav extends StatelessWidget {
  const _TopNav({required this.index, required this.onSelect, required this.onAccount, required this.user});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAccount;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _topNavHeight,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo_full.png', height: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _destinations.length; i++) ...[
                  if (i != 0) const SizedBox(width: 36),
                  _NavLink(destination: _destinations[i], selected: i == index, onTap: () => onSelect(i)),
                ],
              ],
            ),
          ),
          _UserMenu(user: user, selected: index == _accountIndex, onTap: onAccount),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentOrange : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Icon(selected ? destination.selectedIcon : destination.icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                destination.label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The avatar in the top bar; opens the Account page.
class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.user, required this.selected, required this.onTap});

  final User user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Account',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: 1.5),
          ),
          child: UserAvatar(user: user, radius: 17),
        ),
      ),
    );
  }
}
