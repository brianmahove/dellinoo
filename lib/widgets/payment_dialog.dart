import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/contact.dart';
import '../core/iconly.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/payments_api.dart';
import '../state/providers.dart';
import 'common.dart';
import 'glass.dart';
import 'payment_logos.dart';

const _logName = 'payments';

/// Lets the customer pick a different payment method than the one chosen at
/// checkout (e.g. EcoCash didn't go through, try InnBucks instead) before
/// retrying an unpaid order, then runs [PaymentWaitDialog] with that choice.
/// Used by order_success_screen.dart/order_detail_screen.dart's "Complete
/// payment" button.
Future<void> retryPayment(
  BuildContext context, {
  required String orderId,
  required PaymentMethod initialMethod,
  required String initialPhone,
}) async {
  final choice = await showGlassBottomSheet<_PaymentChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentMethodPicker(initialMethod: initialMethod, initialPhone: initialPhone),
  );
  if (choice == null || !context.mounted) return;
  await showGlassDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PaymentWaitDialog(orderId: orderId, method: choice.method, phone: choice.phone),
  );
}

class _PaymentChoice {
  const _PaymentChoice(this.method, this.phone);
  final PaymentMethod method;
  final String phone;
}

class _PaymentMethodPicker extends StatefulWidget {
  const _PaymentMethodPicker({required this.initialMethod, required this.initialPhone});

  final PaymentMethod initialMethod;
  final String initialPhone;

  @override
  State<_PaymentMethodPicker> createState() => _PaymentMethodPickerState();
}

class _PaymentMethodPickerState extends State<_PaymentMethodPicker> {
  late PaymentMethod _method = widget.initialMethod.selectable
      ? widget.initialMethod
      : PaymentMethod.selectableValues.first;
  late final _phone = TextEditingController(text: widget.initialPhone);

  @override
  void dispose() {
    _phone.dispose();
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
          const Text('Pay with', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // OneMoney stays hidden here too — see checkout_screen.dart.
          for (final m in PaymentMethod.selectableValues)
            SelectTile(
              selected: _method == m,
              onTap: () => setState(() => _method = m),
              leading: PaymentLogo(m),
              title: m.label,
              subtitle: m.subtitle,
              trailing: m == PaymentMethod.card ? const CardBrandsChip() : null,
            ),
          if (_method.needsPhone) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                labelText: '${_method.label} number',
                prefixIcon: const Icon(IconlyLight.call),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () => Navigator.of(context).pop(_PaymentChoice(_method, _phone.text)),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// Initiates a real Paynow payment for [orderId] via the payments Cloudflare
/// Worker (see payments_api.dart), then waits — via a Firestore snapshot
/// listener on the order doc, never polling — for the Worker's Paynow
/// webhook to append a `paid` StatusEvent. Pops `true` once paid, or `false`
/// on cancel/timeout/error; the order itself is left untouched either way
/// (still `placed`, safely retryable — see order_detail_screen.dart's
/// "Complete payment" button).
class PaymentWaitDialog extends ConsumerStatefulWidget {
  const PaymentWaitDialog({super.key, required this.orderId, required this.method, required this.phone});

  final String orderId;
  final PaymentMethod method;
  final String phone;

  @override
  ConsumerState<PaymentWaitDialog> createState() => _PaymentWaitDialogState();
}

class _PaymentWaitDialogState extends ConsumerState<PaymentWaitDialog> {
  bool _waiting = false;
  bool _paid = false;
  bool _done = false;
  String? _errorMessage;
  String? _authorizationCode;
  String? _authorizationExpires;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    developer.log('starting payment for order ${widget.orderId} via ${widget.method.name}', name: _logName);
    try {
      final result = await initiatePaynowPayment(
        orderId: widget.orderId,
        method: widget.method,
        phone: widget.method.needsPhone ? widget.phone : null,
      );
      if (!mounted) return;

      if (result.alreadyPaid) {
        developer.log('order ${widget.orderId} was already paid', name: _logName);
        _finish(true, reason: 'already paid');
        return;
      }
      if (!result.ok) {
        // The Worker responded but reported an error. Note this does NOT
        // mean Paynow definitely failed to charge — if the failure happened
        // after Paynow accepted the transaction (e.g. the Worker's Firestore
        // write throwing), the order can still end up paid later via the
        // webhook. Cross-check with `wrangler tail` if this and a later
        // "paid" order both show up for the same orderId.
        developer.log(
          'order ${widget.orderId}: initiate returned an error — ${result.error}: ${result.message}',
          name: _logName,
        );
        setState(() => _errorMessage = result.message ?? "Couldn't start your payment. Please try again.");
        return;
      }
      if (result.flow == PaynowFlow.redirect && result.redirectUrl != null) {
        developer.log('order ${widget.orderId}: opening card redirect', name: _logName);
        await openLink(result.redirectUrl!);
      }
      if (!mounted) return;
      setState(() {
        _waiting = true;
        _authorizationCode = result.authorizationCode;
        _authorizationExpires = result.authorizationExpires;
      });
      developer.log('order ${widget.orderId}: waiting on Firestore for a paid status', name: _logName);
      _listenForPayment();
    } catch (err, stack) {
      developer.log('order ${widget.orderId}: initiate request threw', name: _logName, error: err, stackTrace: stack);
      if (!mounted) return;
      setState(() => _errorMessage = "Couldn't reach the payment service. Please check your connection and try again.");
    }
  }

  void _listenForPayment() {
    _sub = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots().listen((snapshot) {
      final history = snapshot.data()?['history'] as List?;
      final statuses = history?.map((e) => (e as Map)['status']).toList();
      developer.log('order ${widget.orderId}: history now $statuses', name: _logName);
      final paid = history?.any((e) => (e as Map)['status'] == 'paid') ?? false;
      if (paid) _finish(true, reason: 'Firestore listener saw paid');
    });
    _timeout = Timer(const Duration(minutes: 3), () => _finish(false, reason: 'timed out after 3 minutes'));
  }

  void _finish(bool success, {required String reason}) {
    if (_done || !mounted) return;
    _done = true;
    developer.log('order ${widget.orderId}: finishing (success=$success, reason=$reason)', name: _logName);
    _sub?.cancel();
    _timeout?.cancel();
    if (!success) {
      Navigator.of(context).pop(false);
      return;
    }
    // Without this, any screen reading ordersProvider (order-success,
    // order-detail) keeps showing this order as unpaid until the next full
    // re-fetch, even though it's genuinely paid now.
    ref.read(ordersProvider.notifier).markPaid(widget.orderId);
    setState(() => _paid = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _waitingMessage();
    return GlassAlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: _paid
                ? Icon(IconlyBold.tick_square, color: AppColors.inStock, size: 56)
                : _errorMessage != null
                ? Icon(Icons.error_outline, color: AppColors.accentOrange, size: 48)
                : const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 16),
          Text(
            _paid
                ? 'Payment received'
                : _errorMessage != null
                ? 'Payment problem'
                : 'Waiting for payment',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _paid ? 'Thank you!' : (_errorMessage ?? message),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (_showInnbucksCode) ...[
            const SizedBox(height: 14),
            _InnbucksCode(code: _authorizationCode!, expires: _authorizationExpires),
          ],
          if (!_paid) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _finish(false, reason: 'cancelled by customer'),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _showInnbucksCode =>
      widget.method == PaymentMethod.innbucks &&
      _waiting &&
      !_paid &&
      _errorMessage == null &&
      _authorizationCode != null;

  String _waitingMessage() {
    if (!_waiting) return 'Starting your payment…';
    if (_showInnbucksCode) return 'Open the InnBucks app and enter this code to approve the payment.';
    return switch (widget.method) {
      PaymentMethod.ecocash || PaymentMethod.onemoney =>
        'Check your phone (${widget.phone}) and enter your ${widget.method.label} PIN to approve the payment.',
      PaymentMethod.innbucks => 'Generating your InnBucks payment code…',
      PaymentMethod.card => 'Complete your payment in the browser, then come back here.',
    };
  }
}

/// The InnBucks authorization code, big and copyable.
class _InnbucksCode extends StatelessWidget {
  const _InnbucksCode({required this.code, this.expires});

  final String code;
  final String? expires;

  @override
  Widget build(BuildContext context) {
    // Groups of 3 read more easily ("123 456 789").
    final spaced = code.replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]} ');
    return Column(
      children: [
        Material(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              showGlassToast(context, 'Code copied');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      spaced,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
        if (expires != null) ...[
          const SizedBox(height: 8),
          Text('Expires $expires', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ],
    );
  }
}
