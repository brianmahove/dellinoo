import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'delivery_areas_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';

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

        const destinations = [
          NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Products')),
          NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Orders')),
          NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), label: Text('Delivery areas')),
        ];
        const screens = [ProductsScreen(), OrdersScreen(), DeliveryAreasScreen()];

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Icon(Icons.storefront)),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: 'Sign out',
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                      ),
                    ),
                  ),
                ),
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: screens[_index]),
            ],
          ),
        );
      },
    );
  }

  Widget _denied(String reason) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Access denied', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(reason, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
