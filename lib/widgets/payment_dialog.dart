import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';

import '../core/contact.dart';
import '../core/iconly.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/payments_api.dart';

/// Initiates a real Paynow payment for [orderId] via the payments Cloudflare
/// Worker (see payments_api.dart), then waits — via a Firestore snapshot
/// listener on the order doc, never polling — for the Worker's Paynow
/// webhook to append a `paid` StatusEvent. Pops `true` once paid, or `false`
/// on cancel/timeout/error; the order itself is left untouched either way
/// (still `placed`, safely retryable — see order_detail_screen.dart's
/// "Complete payment" button).
class PaymentWaitDialog extends StatefulWidget {
  const PaymentWaitDialog({super.key, required this.orderId, required this.method, required this.phone});

  final String orderId;
  final PaymentMethod method;
  final String phone;

  @override
  State<PaymentWaitDialog> createState() => _PaymentWaitDialogState();
}

class _PaymentWaitDialogState extends State<PaymentWaitDialog> {
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
    try {
      final result = await initiatePaynowPayment(
        orderId: widget.orderId,
        phone: widget.method.needsPhone ? widget.phone : null,
      );
      if (!mounted) return;

      if (result.alreadyPaid) {
        _finish(true);
        return;
      }
      if (!result.ok) {
        setState(() => _errorMessage = result.message ?? "Couldn't start your payment. Please try again.");
        return;
      }
      if (result.flow == PaynowFlow.redirect && result.redirectUrl != null) {
        await openLink(result.redirectUrl!);
      }
      if (!mounted) return;
      setState(() {
        _waiting = true;
        _authorizationCode = result.authorizationCode;
        _authorizationExpires = result.authorizationExpires;
      });
      _listenForPayment();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = "Couldn't reach the payment service. Please check your connection and try again.");
    }
  }

  void _listenForPayment() {
    _sub = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots().listen((snapshot) {
      final history = snapshot.data()?['history'] as List?;
      final paid = history?.any((e) => (e as Map)['status'] == 'paid') ?? false;
      if (paid) _finish(true);
    });
    _timeout = Timer(const Duration(minutes: 3), () => _finish(false));
  }

  void _finish(bool success) {
    if (_done || !mounted) return;
    _done = true;
    _sub?.cancel();
    _timeout?.cancel();
    if (!success) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _paid = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _waitingMessage();
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
          if (!_paid) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: () => _finish(false), child: const Text('Cancel')),
          ],
        ],
      ),
    );
  }

  String _waitingMessage() {
    if (!_waiting) return 'Starting your payment…';
    if (widget.method == PaymentMethod.innbucks && _authorizationCode != null) {
      return 'Open the InnBucks app and enter code ${_authorizationCode!}'
          '${_authorizationExpires != null ? ' (expires ${_authorizationExpires!})' : ''}.';
    }
    return switch (widget.method) {
      PaymentMethod.ecocash || PaymentMethod.onemoney =>
        'Check your phone (${widget.phone}) and enter your ${widget.method.label} PIN to approve the payment.',
      PaymentMethod.innbucks => 'Generating your InnBucks payment code…',
      PaymentMethod.card => 'Complete your payment in the browser, then come back here.',
    };
  }
}
