import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'delivery_areas_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'theme.dart';

/// Below this width the shell uses a bottom nav bar (mobile web); at or
/// above it, a sidebar (desktop web) — matches Material's own "compact vs.
/// medium" breakpoint at 600, with a little headroom for the sidebar's width.
const _wideBreakpoint = 720.0;

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _destinations = [
  _Destination(Icons.inventory_2_outlined, Icons.inventory_2, 'Products'),
  _Destination(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  _Destination(Icons.local_shipping_outlined, Icons.local_shipping, 'Delivery areas'),
];
const _screens = [ProductsScreen(), OrdersScreen(), DeliveryAreasScreen()];

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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset('assets/images/logo_icon.png', width: 36, height: 36),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: Icon(Icons.logout, color: AppColors.muted),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          VerticalDivider(width: 1, color: AppColors.line),
          Expanded(child: _screens[_index]),
        ],
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
