import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admins_screen.dart';
import 'coupons_screen.dart';
import 'dashboard_screen.dart';
import 'requests_screen.dart';
import 'delivery_areas_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'theme.dart';

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
  _Destination(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _Destination(Icons.inventory_2_outlined, Icons.inventory_2, 'Products'),
  _Destination(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  _Destination(Icons.local_shipping_outlined, Icons.local_shipping, 'Delivery areas'),
  _Destination(Icons.sell_outlined, Icons.sell, 'Coupons'),
  _Destination(Icons.travel_explore_outlined, Icons.travel_explore, 'Requests'),
  _Destination(Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admins'),
];
const _screens = [
  DashboardScreen(),
  ProductsScreen(),
  OrdersScreen(),
  DeliveryAreasScreen(),
  CouponsScreen(),
  RequestsScreen(),
  AdminsScreen(),
];

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

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email;
    if (email == null) return _denied('This account has no email address.');

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('admins').doc(email).get(),
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
            _TopNav(index: _index, onSelect: (i) => setState(() => _index = i), user: widget.user),
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
                child: _screens[_index],
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
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _screens[_index],
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
                child: const Icon(Icons.block, size: 30, color: AppColors.danger),
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
  const _TopNav({required this.index, required this.onSelect, required this.user});

  final int index;
  final ValueChanged<int> onSelect;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _topNavHeight,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo_full.png',height: 28),
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
          _UserMenu(user: user),
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

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoURL;
    final initial = (user.email ?? user.displayName ?? '?').substring(0, 1).toUpperCase();
    return PopupMenuButton<void>(
      tooltip: user.email ?? '',
      offset: const Offset(0, 46),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            user.email ?? '',
            style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => FirebaseAuth.instance.signOut(),
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.ink),
              const SizedBox(width: 10),
              const Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? Text(
                  initial,
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                )
              : null,
        ),
      ),
    );
  }
}
