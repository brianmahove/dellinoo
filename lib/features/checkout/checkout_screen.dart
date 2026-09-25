import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../core/iconly.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Address _address = mockAddress;
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
    final paid = await showGlassDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(method: _payment, phone: _walletPhone.text),
    );
    if (!mounted) return;
    setState(() => _placing = false);
    if (paid != true) return;

    final order = ref
        .read(ordersProvider.notifier)
        .place(items: ref.read(cartProvider), address: _address, area: _area!, payment: _payment);
    ref.read(cartProvider.notifier).clear();
    context.go('/order-success/${order.id}');
  }

  static const _steps = ['Address', 'Delivery', 'Payment'];

  void _next() {
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
          final updated = await showGlassBottomSheet<Address>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _AddressSheet(initial: _address),
          );
          if (updated != null) setState(() => _address = updated);
        },
        child: const Text('Change'),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconlyLight.location, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_address.fullName}  ·  ${_address.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_address.oneLine, style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
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
          for (final m in PaymentMethod.values)
            _SelectTile(
              selected: _payment == m,
              onTap: () => setState(() => _payment = m),
              leading: _PaymentLogo(m),
              title: m.label,
              subtitle: m.subtitle,
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
          _AmountRow('Total', money(subtotal + fee), bold: true),
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
            child: FilledButton(
              onPressed: _placing ? null : _next,
              child: Text(_step < _steps.length - 1 ? 'Continue' : 'Pay ${money(subtotal + fee)}'),
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
                    color: i <= current ? AppColors.primary : AppColors.line,
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
                    ? const Icon(Icons.check_rounded, size: 16, color: AppColors.black)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: i <= current ? AppColors.black : AppColors.muted,
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
                color: selected ? AppColors.ink : AppColors.muted,
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
    final (color, text) = switch (method) {
      PaymentMethod.ecocash => (const Color(0xFF0057A8), 'Eco'),
      PaymentMethod.onemoney => (const Color(0xFFE2231A), 'One'),
      PaymentMethod.innbucks => (const Color(0xFF00843D), 'Inn'),
      PaymentMethod.card => (const Color(0xFF3C3C46), null),
    };
    return Container(
      width: 40,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: text == null
          ? const Icon(IconlyBold.wallet, color: Colors.white, size: 18)
          : Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

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
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Simulates the gateway handshake (e.g. EcoCash USSD prompt) until the
/// real payment gateway is wired up.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.method, required this.phone});

  final PaymentMethod method;
  final String phone;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (widget.method) {
      PaymentMethod.ecocash || PaymentMethod.onemoney =>
        'Check your phone (${widget.phone}) and enter your ${widget.method.label} PIN to approve the payment.',
      PaymentMethod.innbucks => 'Generating your InnBucks payment code…',
      PaymentMethod.card => 'Redirecting to secure card payment…',
    };
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: _done
                ? Icon(IconlyBold.tick_square, color: AppColors.inStock, size: 56)
                : const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 16),
          Text(
            _done ? 'Payment received' : 'Waiting for payment',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _done ? 'Thank you!' : message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (!_done) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ],
        ],
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.initial});

  final Address initial;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _name = TextEditingController(text: widget.initial.fullName);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _street = TextEditingController(text: widget.initial.street);
  late final _city = TextEditingController(text: widget.initial.city);

  @override
  void dispose() {
    for (final c in [_name, _phone, _street, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Delivery address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _street,
            decoration: const InputDecoration(labelText: 'Street address / suburb'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City / town'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(Address(fullName: _name.text, phone: _phone.text, street: _street.text, city: _city.text)),
            child: const Text('Save address'),
          ),
        ],
      ),
    );
  }
}
