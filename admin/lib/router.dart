import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'account_screen.dart';
import 'admins_screen.dart';
import 'categories_screen.dart';
import 'coupons_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'delivery_areas_screen.dart';
import 'iconly.dart';
import 'invoices_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'payment_details_screen.dart';
import 'products_screen.dart';
import 'requests_screen.dart';
import 'shell.dart';

/// One nav destination: its URL, its icons and the screen behind it.
///
/// The URL is the point of this list — every screen the admin can click to has
/// its own address (`/orders`, `/delivery-areas`, …) so links can be shared and
/// bookmarked, the browser's back/forward buttons work, and a refresh stays put.
class AdminDestination {
  const AdminDestination(this.path, this.icon, this.selectedIcon, this.label, this.screen);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
}

const adminDestinations = [
  AdminDestination('/dashboard', IconlyLight.category, IconlyBold.category, 'Dashboard', DashboardScreen()),
  AdminDestination('/products', IconlyLight.bag, IconlyBold.bag, 'Products', ProductsScreen()),
  AdminDestination('/orders', IconlyLight.paper, IconlyBold.paper, 'Orders', OrdersScreen()),
  AdminDestination('/categories', IconlyLight.folder, IconlyBold.folder, 'Categories', CategoriesScreen()),
  AdminDestination('/customers', IconlyLight.user_1, IconlyBold.user_3, 'Customers', CustomersScreen()),
  AdminDestination(
    '/delivery-areas',
    IconlyLight.location,
    IconlyBold.location,
    'Delivery areas',
    DeliveryAreasScreen(),
  ),
  AdminDestination('/coupons', IconlyLight.discount, IconlyBold.discount, 'Coupons', CouponsScreen()),
  AdminDestination('/requests', IconlyLight.discovery, IconlyBold.discovery, 'Requests', RequestsScreen()),
  AdminDestination('/invoices', IconlyLight.document, IconlyBold.document, 'Invoices', InvoicesScreen()),
  AdminDestination(
    '/notifications',
    IconlyLight.notification,
    IconlyBold.notification,
    'Notifications',
    NotificationsScreen(),
  ),
  AdminDestination(
    '/payment-details',
    IconlyLight.wallet,
    IconlyBold.wallet,
    'Payment details',
    PaymentDetailsScreen(),
  ),
  AdminDestination('/admins', IconlyLight.shield_done, IconlyBold.shield_done, 'Admins', AdminsScreen()),
];

/// Branch index of `/account` (one past the nav destinations) and of the
/// mobile-only `/more` menu. They're branches like any other so they get a URL
/// too, but they're not drawn in the top nav.
/// (= `adminDestinations.length`, spelled out because a `switch` on the branch
/// index needs constants and a list's length isn't one.)
const accountBranch = 12;
const moreBranch = 13;

const accountPath = '/account';
const morePath = '/more';

/// Signed-in state as a [Listenable], so the router can re-run its redirect
/// when the admin signs in or out.
///
/// [ready] stays false until Firebase Auth has restored (or failed to restore)
/// the cached web session — without it every reload would flash the login
/// screen before the session came back.
class AdminAuth extends ChangeNotifier {
  AdminAuth() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      _ready = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;
  User? _user;
  bool _ready = false;

  User? get user => _user;
  bool get ready => _ready;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// The router is built immediately, before Firebase Auth has restored the
/// cached session — showing a separate "loading" app or redirecting to a
/// loading route first would mount a plain Navigator, and on web that rewrites
/// the browser URL to `/`, losing the address the admin actually opened. So
/// nothing navigates while the session is restoring: the URL stays put and the
/// shell shows a spinner until [AdminAuth.ready].
GoRouter buildAdminRouter(AdminAuth auth) {
  return GoRouter(
    initialLocation: adminDestinations.first.path,
    refreshListenable: auth,
    redirect: (context, state) {
      final here = state.matchedLocation;
      // Session still restoring: stay where we are, spinner below.
      if (!auth.ready) return null;
      if (auth.user == null) {
        if (here == '/login') return null;
        // Remember where they were headed, so signing in lands there.
        return Uri(path: '/login', queryParameters: here == '/' ? null : {'from': state.uri.toString()}).toString();
      }
      if (here == '/login') return state.uri.queryParameters['from'] ?? adminDestinations.first.path;
      if (here == '/') return adminDestinations.first.path;
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        // Held back until there's a signed-in user to check against the admin
        // allowlist; the URL is untouched meanwhile.
        builder: (context, state, navigationShell) => ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final user = auth.user;
            if (!auth.ready || user == null) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return AdminShell(key: ValueKey(user.uid), navigationShell: navigationShell, user: user);
          },
        ),
        branches: [
          for (final d in adminDestinations)
            StatefulShellBranch(
              routes: [GoRoute(path: d.path, builder: (context, state) => d.screen)],
            ),
          StatefulShellBranch(
            routes: [GoRoute(path: accountPath, builder: (context, state) => const AccountScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: morePath, builder: (context, state) => const MorePage())],
          ),
        ],
      ),
    ],
  );
}
