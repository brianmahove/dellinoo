import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_access.dart';
import 'router.dart';
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

/// The nav destinations the signed-in admin may use, with their branch index.
List<(int, AdminDestination)> _allowedDestinations() => [
  for (var i = 0; i < adminDestinations.length; i++)
    if (AdminAccess.allows(adminDestinations[i].area)) (i, adminDestinations[i]),
];

/// Signed-in shell: checks the `admins/{email}` allowlist (mirrors
/// firestore.rules' `isAdmin()`) before showing any admin screen — this is a
/// UX check only, the real enforcement is the security rules themselves, so
/// this can never be the only thing standing between a stranger and the data.
///
/// The pages themselves are the router's branches (see `router.dart`): each has
/// its own URL, and `StatefulShellRoute.indexedStack` keeps a visited branch
/// alive, so switching tabs doesn't rebuild the screen or reload its Firestore
/// stream (which is what made pages flash back to a spinner).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.navigationShell, required this.user});

  final StatefulNavigationShell navigationShell;

  /// The signed-in account. Passed in rather than read from FirebaseAuth here,
  /// because the router only builds this once the session has been restored.
  final User user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  /// The admin's own doc, streamed so a change to their access (or removing
  /// them) shows up without a reload. Created once, not inside build().
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _adminCheck = widget.user.email == null
      ? null
      : FirebaseFirestore.instance.collection('admins').doc(widget.user.email).snapshots();

  /// Nav destinations this admin may use, as (branch index, destination).
  List<(int, AdminDestination)> get _allowed => _allowedDestinations();

  /// Branch indices that have a bottom-bar tab of their own on mobile.
  List<int> get _tabBranches => [for (final (i, _) in _allowed.take(_mobileTabs)) i];

  /// A limited admin who opened (or bookmarked) a screen they can't use is
  /// sent to their first allowed one.
  void _keepInsideAccess() {
    final i = _index;
    if (i >= adminDestinations.length || AdminAccess.allows(adminDestinations[i].area)) return;
    final first = _allowed.firstOrNull?.$1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.navigationShell.goBranch(first ?? accountBranch);
    });
  }

  int get _index => widget.navigationShell.currentIndex;

  /// Tapping the tab you are already on goes back to that branch's own start.
  void _select(int i) => widget.navigationShell.goBranch(i, initialLocation: i == _index);

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email = user.email;
    if (email == null) return _denied('This account has no email address.');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _adminCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data?.exists != true) return _denied('$email is not an admin.');
        AdminAccess.load(snapshot.data!.data());
        _keepInsideAccess();
        if (_allowed.isEmpty) return _denied('$email has no access yet — ask the owner to give you some.');

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return wide ? _wideLayout(user) : _narrowLayout(user);
          },
        );
      },
    );
  }

  Widget _wideLayout(User user) {
    return Scaffold(
      backgroundColor: AppColors.tint,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _TopNav(
              index: _index,
              items: _allowed,
              onSelect: _select,
              onAccount: () => _select(accountBranch),
              user: user,
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
                child: widget.navigationShell,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrowLayout(User user) {
    // Pages without a bottom-bar tab of their own are reached through "More",
    // so that is where their back arrow goes.
    final tabs = _tabBranches;
    final underMore = !tabs.contains(_index) && _index != moreBranch;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: underMore
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => _select(moreBranch),
                icon: const Icon(IconlyLight.arrow_left_2),
              )
            : null,
        title: Row(
          children: [
            if (!underMore) ...[
              Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
              const SizedBox(width: 10),
            ],
            // No per-screen titles any more, so the bar says where you are.
            Text(switch (_index) {
              moreBranch => 'More',
              accountBranch => 'Account',
              _ => adminDestinations[_index].label,
            }),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => _select(accountBranch),
            icon: const Icon(IconlyLight.profile),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        // Eight labels don't fit a phone: the first few get a tab, the rest live under "More".
        selectedIndex: tabs.contains(_index) ? tabs.indexOf(_index) : tabs.length,
        onDestinationSelected: (i) => _select(i == tabs.length ? moreBranch : tabs[i]),
        destinations: [
          for (final i in tabs)
            NavigationDestination(
              icon: Icon(adminDestinations[i].icon),
              selectedIcon: Icon(adminDestinations[i].selectedIcon),
              label: adminDestinations[i].label,
            ),
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
  const _TopNav({
    required this.index,
    required this.items,
    required this.onSelect,
    required this.onAccount,
    required this.user,
  });

  final int index;

  /// The destinations this admin may use, with their branch index.
  final List<(int, AdminDestination)> items;
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
                      for (var n = 0; n < items.length; n++) ...[
                        if (n != 0) const SizedBox(width: 28),
                        _NavLink(
                          destination: items[n].$2,
                          selected: items[n].$1 == index,
                          onTap: () => onSelect(items[n].$1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _UserMenu(user: user, selected: index == accountBranch, onTap: onAccount),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.destination, required this.selected, required this.onTap});

  final AdminDestination destination;
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

/// Mobile "More" tab (`/more`): a full page listing the destinations that don't
/// fit in the bottom bar, plus the account and sign-out.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

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
        for (final (_, d) in _allowedDestinations().skip(_mobileTabs)) ...[
          _MoreTile(icon: d.icon, label: d.label, hint: _hints[d.label], onTap: () => context.go(d.path)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        _MoreTile(
          icon: IconlyLight.profile,
          label: 'My account',
          hint: 'Profile and password',
          onTap: () => context.go(accountPath),
        ),
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
