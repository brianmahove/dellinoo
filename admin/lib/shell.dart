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
import 'invoices_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'payment_details_screen.dart';
import 'products_screen.dart';
import 'theme.dart';
import 'user_avatar.dart';
import 'iconly.dart';

/// Below this width the shell uses a bottom nav bar (mobile web); at or
/// above it, a sidebar (desktop web) — matches Material's own "compact vs.
/// medium" breakpoint at 600, with a little headroom for the sidebar's width.
const _wideBreakpoint = 720.0;
const _topNavHeight = 72.0;

/// Destinations that get their own bottom-bar tab on mobile; the rest go under "More".
const _mobileTabs = 4;

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
  _Destination(IconlyLight.document, IconlyBold.document, 'Invoices'),
  _Destination(IconlyLight.notification, IconlyBold.notification, 'Notifications'),
  _Destination(IconlyLight.wallet, IconlyBold.wallet, 'Payment details'),
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
  InvoicesScreen(),
  NotificationsScreen(),
  PaymentDetailsScreen(),
  AdminsScreen(),
  AccountScreen(), // not in the nav; opened from the avatar
  SizedBox.shrink(), // placeholder for the mobile "More" page, built in _body()
];

/// Index of [AccountScreen] in [_screens] (one past the nav destinations).
const _accountIndex = 11;

/// Index of the mobile-only "More" page (a menu of the destinations without a bottom-bar tab).
const _moreIndex = 12;

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
        for (var i = 0; i < _screens.length; i++)
          if (i == _moreIndex)
            _MorePage(
              onSelect: (i) => setState(() => _index = i),
              onAccount: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen(showBack: true))),
            )
          else if (_visited.contains(i))
            _screens[i]
          else
            const SizedBox.shrink(),
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
        // From a page that lives under "More", the arrow goes back to that menu.
        automaticallyImplyLeading: false,
        leading: _index >= _mobileTabs && _index < _destinations.length
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() => _index = _moreIndex),
                icon: const Icon(IconlyLight.arrow_left_2),
              )
            : null,
        title: Row(
          children: [
            if (_index < _mobileTabs || _index >= _destinations.length) ...[
              Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
              const SizedBox(width: 10),
            ],
            // No per-screen titles any more, so the bar says where you are.
            Text(
              _index == _moreIndex
                  ? 'More'
                  : _index < _destinations.length
                  ? _destinations[_index].label
                  : 'Account',
            ),
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
        // Eight labels don't fit a phone: the first few get a tab, the rest live under "More".
        selectedIndex: _index < _mobileTabs ? _index : _mobileTabs,
        onDestinationSelected: (i) => setState(() => _index = i == _mobileTabs ? _moreIndex : i),
        destinations: [
          for (final d in _destinations.take(_mobileTabs))
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          const NavigationDestination(
            icon: Icon(IconlyLight.more_square),
            selectedIcon: Icon(IconlyBold.more_square),
            label: 'More',
          ),
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
          // Centred while the links fit, horizontally scrollable once they
          // don't (ten destinations overflow a narrow laptop window).
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _destinations.length; i++) ...[
                        if (i != 0) const SizedBox(width: 28),
                        _NavLink(destination: _destinations[i], selected: i == index, onTap: () => onSelect(i)),
                      ],
                    ],
                  ),
                ),
              ),
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

/// Mobile "More" tab: a full page listing the destinations that don't fit in the
/// bottom bar, plus the account and sign-out.
class _MorePage extends StatelessWidget {
  const _MorePage({required this.onSelect, required this.onAccount});

  final ValueChanged<int> onSelect;
  final VoidCallback onAccount;

  static const _hints = {
    'Delivery areas': 'Where you deliver and the fees',
    'Coupons': 'Discount codes for checkout',
    'Requests': 'Items customers asked you to source',
    'Notifications': 'Promo pushes and price-drop alerts',
    'Payment details': 'Accounts for manual payments',
    'Admins': 'Who can use this panel',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = _mobileTabs; i < _destinations.length; i++) ...[
          _MoreTile(
            icon: _destinations[i].icon,
            label: _destinations[i].label,
            hint: _hints[_destinations[i].label],
            onTap: () => onSelect(i),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        _MoreTile(icon: IconlyLight.profile, label: 'My account', hint: 'Profile and password', onTap: onAccount),
        const SizedBox(height: 10),
        _MoreTile(
          icon: IconlyLight.logout,
          label: 'Sign out',
          color: AppColors.danger,
          onTap: () => FirebaseAuth.instance.signOut(),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.label, required this.onTap, this.hint, this.color});

  final IconData icon;
  final String label;
  final String? hint;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.primary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: tone),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color ?? AppColors.ink),
                    ),
                    if (hint != null) Text(hint!, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (color == null) Icon(IconlyLight.arrow_right_2, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
