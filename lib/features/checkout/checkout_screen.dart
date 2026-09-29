import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/motion.dart';
import '../../widgets/payment_dialog.dart';
import '../../widgets/payment_logos.dart';
import '../../core/iconly.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// The address chosen this session via "Change" — overrides the saved
  /// default until the user picks another one. `null` means "use whatever
  /// the default saved address (or the blank fallback) resolves to".
  Address? _addressOverride;

  /// The address actually in effect, recomputed every build (see build()) —
  /// kept for `_placeOrder`, which isn't build() and so can't recompute it
  /// from providers itself without triggering an extra rebuild mid-callback.
  Address _currentAddress = const Address(fullName: '', phone: '', street: '', city: '');
  DeliveryArea? _area;
  PaymentMethod _payment = PaymentMethod.ecocash;
  final _walletPhone = TextEditingController(text: '0771234567');
  bool _placing = false;
  int _step = 0;

  @override
  void dispose() {
    _walletPhone.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_area == null) {
      showGlassToast(context, 'Please choose a delivery option');
      return;
    }
    setState(() => _placing = true);

    Order order;
    try {
      order = await ref
          .read(ordersProvider.notifier)
          .place(items: ref.read(cartProvider), address: _currentAddress, area: _area!, payment: _payment);
    } catch (_) {
      if (mounted) {
        showGlassToast(context, "Couldn't place your order. Please try again.");
        setState(() => _placing = false);
      }
      return;
    }
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();

    // The order now exists (unpaid) in Firestore either way — payment
    // outcome only decides whether it's already paid when we get to order
    // detail, which offers "Complete payment" if not (see PaymentWaitDialog).
    await showGlassDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentWaitDialog(orderId: order.id, method: _payment, phone: _walletPhone.text),
    );
    if (!mounted) return;
    context.go('/order-success/${order.id}');
  }

  static const _steps = ['Address', 'Delivery', 'Payment'];

  void _next() {
    if (_step == 0 && (_currentAddress.street.isEmpty || _currentAddress.city.isEmpty)) {
      HapticFeedback.heavyImpact();
      showGlassToast(context, 'Please add or choose a delivery address');
      return;
    }
    if (_step == 1 && _area == null) {
      HapticFeedback.heavyImpact();
      showGlassToast(context, 'Please choose a delivery option');
      return;
    }
    if (_step < _steps.length - 1) {
      HapticFeedback.selectionClick();
      setState(() => _step++);
    } else {
      _placeOrder();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final areas = ref.watch(deliveryAreasProvider).value ?? const [];
    final fee = _area?.fee ?? 0;

    final savedAddresses = ref.watch(addressBookProvider);
    final authUser = ref.watch(authProvider);
    final defaultSaved = savedAddresses.where((a) => a.isDefault).firstOrNull ?? savedAddresses.firstOrNull;
    // Recomputed every build so a saved default that finishes loading after
    // the first frame (or a change made on the addresses screen) shows up
    // here without extra plumbing; an explicit "Change" pick always wins.
    _currentAddress =
        _addressOverride ??
        defaultSaved?.address ??
        Address(fullName: authUser?.name ?? '', phone: authUser?.phone ?? '', street: '', city: '');
    final hasAddress = _currentAddress.street.isNotEmpty && _currentAddress.city.isNotEmpty;

    if (items.isEmpty) {
      return Scaffold(
        appBar: const PageHeader(title: 'Checkout'),
        body: const EmptyState(icon: IconlyLight.bag, title: 'Nothing to check out', message: 'Your cart is empty.'),
      );
    }

    final addressSection = _Section(
      title: 'Delivery address',
      trailing: TextButton(
        onPressed: () async {
          final picked = await showGlassBottomSheet<Address>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddressPicker(),
          );
          if (picked != null) setState(() => _addressOverride = picked);
        },
        child: const Text('Change'),
      ),
      child: hasAddress
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(IconlyLight.location, color: AppColors.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentAddress.fullName}  ·  ${_currentAddress.phone}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(_currentAddress.oneLine, style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            )
          : Text('No delivery address yet — tap Change to add one.', style: TextStyle(color: AppColors.muted)),
    );
    final deliverySection = _Section(
      title: 'Delivery option',
      child: Column(
        children: [
          for (final a in areas)
            _SelectTile(
              selected: _area?.id == a.id,
              onTap: () => setState(() => _area = a),
              title: a.name,
              subtitle: a.eta,
              trailing: Text(
                a.fee == 0 ? 'FREE' : money(a.fee),
                style: TextStyle(fontWeight: FontWeight.w700, color: a.fee == 0 ? AppColors.inStock : AppColors.ink),
              ),
            ),
        ],
      ),
    );
    final paymentSection = _Section(
      title: 'Payment method',
      child: Column(
        children: [
          // OneMoney is hidden until we confirm with Paynow whether/how they
          // support it — it wasn't listed as an option on the merchant's
          // integration setup page (Sep 2026).
          for (final m in PaymentMethod.values)
            if (m != PaymentMethod.onemoney)
              _SelectTile(
                selected: _payment == m,
                onTap: () => setState(() => _payment = m),
                leading: _PaymentLogo(m),
                title: m.label,
                subtitle: m.subtitle,
                // Card also takes Visa and Mastercard, shown next to the ZimSwitch logo.
                trailing: m == PaymentMethod.card ? const CardBrandsChip() : null,
              ),
          if (_payment.needsPhone) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _walletPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                labelText: '${_payment.label} number',
                prefixIcon: const Icon(IconlyLight.call),
              ),
            ),
          ],
        ],
      ),
    );
    final summarySection = _Section(
      title: 'Order summary (${items.length} ${items.length == 1 ? 'item' : 'items'})',
      child: Column(
        children: [
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 48, height: 48, child: NetImage(i.product.thumbnail)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          [if (i.options.isNotEmpty) i.optionsLabel, 'Qty ${i.quantity}'].join('  ·  '),
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(money(i.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: 8),
          _AmountRow('Subtotal', money(subtotal)),
          _AmountRow('Delivery', _area == null ? '—' : (fee == 0 ? 'FREE' : money(fee))),
          const SizedBox(height: 4),
          _AmountRow('Total', money(subtotal + fee), bold: true, amount: subtotal + fee),
        ],
      ),
    );

    final pages = [
      [addressSection, summarySection],
      [deliverySection],
      [paymentSection, summarySection],
    ];

    return PopScope(
      // System back steps backwards through checkout before leaving it.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: PageHeader(
          title: 'Checkout',
          onBack: _back,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: _StepIndicator(steps: _steps, current: _step),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: ListView(
            key: ValueKey(_step),
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: pages[_step],
          ),
        ),
        floatingActionButton: const WhatsAppButton(message: 'Hi Dellinoo, I need help with checking out.'),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: GradientButton(
              onPressed: _placing ? null : _next,
              trailingIcon: IconlyLight.arrow_right,
              child: _step < _steps.length - 1
                  ? const Text('Continue')
                  : Row(mainAxisSize: MainAxisSize.min, children: [const Text('Pay '), AnimatedMoney(subtotal + fee)]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "1 Address - 2 Delivery - 3 Payment" progress header.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i <= current ? AppColors.accentOrange : AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: i <= current ? AppColors.primary : AppColors.line, width: 1.5),
              ),
              child: Center(
                child: i < current
                    ? const Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: i <= current ? AppColors.onPrimary : AppColors.muted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              steps[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                color: i <= current ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accentOrange : AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 10),
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentLogo extends StatelessWidget {
  const _PaymentLogo(this.method);

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E0D9)),
      ),
      child: Image.asset(method.logo, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.bold = false, this.amount});

  final String label;
  final String value;
  final bool bold;

  /// When set, the value rolls to new amounts instead of jumping.
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 13.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      color: bold ? AppColors.ink : AppColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          // The bold total is the price the customer pays, so it wears the violet.
          amount == null
              ? Text(value, style: style)
              : AnimatedMoney(amount!, style: bold ? style.copyWith(color: AppColors.accent) : style),
        ],
      ),
    );
  }
}

/// Sheet shown by checkout's "Change": pick one of the customer's saved
/// addresses, or go add a new one (via the full addresses screen — see
/// AddressesScreen — rather than a duplicate form here).
class _AddressPicker extends ConsumerWidget {
  const _AddressPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressBookProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Delivery address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text("You haven't saved any addresses yet.", style: TextStyle(color: AppColors.muted)),
            )
          else
            for (final saved in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(saved.address),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(IconlyLight.location, color: AppColors.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(saved.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${saved.address.fullName} · ${saved.address.oneLine}',
                                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/addresses');
            },
            icon: const Icon(Icons.add),
            label: const Text('Add a new address'),
          ),
        ],
      ),
    );
  }
}
