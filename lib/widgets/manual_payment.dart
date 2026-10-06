import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/contact.dart';
import '../core/format.dart';
import '../core/iconly.dart';
import '../core/theme.dart';
import '../core/ussd.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'common.dart';
import 'glass.dart';
import 'payment_logos.dart';

/// Manual payment, no gateway: shows the client's accounts (admin-managed,
/// `meta/paymentDetails`) and the exact amount, then takes the transaction
/// reference from the customer's confirmation SMS. The admin matches that
/// reference against their own statement and confirms the order in the admin
/// panel (Orders → Confirm payment), which marks it paid and pushes the
/// usual "Payment received" notification.
///
/// [channel] preselects one (the EcoCash tile passes EcoCash), and
/// [autoDial] runs the EcoCash USSD code as soon as the sheet opens, so the
/// customer goes straight to EcoCash's PIN prompt.
///
/// Returns true once a reference was submitted.
Future<bool> showManualPaymentSheet(
  BuildContext context,
  Order order, {
  ManualChannel? channel,
  bool autoDial = false,
}) async {
  final submitted = await showGlassBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ManualPaymentSheet(order: order, initialChannel: channel, autoDial: autoDial),
  );
  return submitted ?? false;
}

class _ManualPaymentSheet extends ConsumerStatefulWidget {
  const _ManualPaymentSheet({required this.order, this.initialChannel, this.autoDial = false});

  final Order order;
  final ManualChannel? initialChannel;
  final bool autoDial;

  @override
  ConsumerState<_ManualPaymentSheet> createState() => _ManualPaymentSheetState();
}

class _ManualPaymentSheetState extends ConsumerState<_ManualPaymentSheet> {
  ManualChannel? _channel;
  late final _reference = TextEditingController(text: widget.order.manualPayment?.reference ?? '');
  late final _sender = TextEditingController(text: widget.order.manualPayment?.sender ?? widget.order.address.phone);
  bool _saving = false;

  /// Dial once only, not again if the customer switches channel and back.
  late bool _autoDialPending = widget.autoDial;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel ?? widget.order.manualPayment?.channel;
  }

  @override
  void dispose() {
    _reference.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _submit(ManualChannel channel) async {
    final reference = _reference.text.trim().toUpperCase();
    if (reference.length < 4) {
      HapticFeedback.heavyImpact();
      showGlassToast(context, 'Please enter the transaction reference from your confirmation message');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(ordersProvider.notifier)
          .submitManualPayment(
            widget.order.docId,
            ManualPayment(
              channel: channel,
              reference: reference,
              sender: _sender.text.trim(),
              submittedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showGlassToast(context, "Couldn't save your reference. Please check your connection and try again.");
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(paymentDetailsProvider);
    final order = widget.order;
    final rejected = order.manualPayment?.status == ManualPaymentStatus.rejected ? order.manualPayment : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: details.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _Unavailable(order: order, message: "Couldn't load our payment details."),
          data: (d) {
            final channels = d.channels;
            if (channels.isEmpty) {
              return _Unavailable(order: order, message: "Manual payment details aren't set up yet.");
            }
            final channel = channels.contains(_channel) ? _channel! : channels.first;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        channel == widget.initialChannel && channel != ManualChannel.bank
                            ? 'Pay ${money(order.total)} with ${channel.label}'
                            : 'Pay ${money(order.total)} manually',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Closing leaves the order unpaid; "Complete payment" reopens this later.
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  d.instructions.isNotEmpty
                      ? d.instructions
                      : 'Send the exact amount to one of the accounts below, then enter the reference '
                            'from your confirmation message. We check it and confirm your order.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                if (rejected != null) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    color: AppColors.accentOrange,
                    text:
                        "We couldn't match reference ${rejected.reference}"
                        '${rejected.note?.isNotEmpty ?? false ? ': ${rejected.note}' : '.'} '
                        'Please check it and send it again.',
                  ),
                ],
                const SizedBox(height: 16),
                const _StepLabel('1', 'Send the money'),
                const SizedBox(height: 8),
                for (final c in channels)
                  SelectTile(
                    selected: c == channel,
                    onTap: () => setState(() => _channel = c),
                    title: c.label,
                    subtitle: d.linesFor(c).first.$2,
                  ),
                const SizedBox(height: 4),
                if (channel == ManualChannel.ecocash && ussdSupported) ...[
                  _EcocashUssdButton(
                    code: d.ecocashUssdFor(order.total),
                    amount: order.total,
                    autoRun: _autoDialPending,
                    onAutoRun: () => _autoDialPending = false,
                  ),
                  const SizedBox(height: 12),
                ],
                _DetailsCard(
                  rows: [...d.linesFor(channel), ('Amount', money(order.total)), ('Reference / note', order.id)],
                ),
                const SizedBox(height: 6),
                Text(
                  channel == ManualChannel.ecocash && ussdSupported
                      ? 'Or send it yourself with the details above.'
                      : 'If your app lets you add a note or reference, put ${order.id} so we can find your payment faster.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 18),
                const _StepLabel('2', 'Tell us the transaction reference'),
                const SizedBox(height: 10),
                TextField(
                  controller: _reference,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(60),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9.\-/ ]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Transaction reference',
                    helperText: channel.referenceHint,
                    helperMaxLines: 2,
                    prefixIcon: const Icon(IconlyLight.document),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sender,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: InputDecoration(
                    labelText: channel == ManualChannel.bank ? 'Paid from (account name)' : 'Paid from (phone number)',
                    prefixIcon: const Icon(IconlyLight.profile),
                  ),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  onPressed: _saving ? null : () => _submit(channel),
                  icon: IconlyLight.send,
                  child: Text(_saving ? 'Sending…' : "I've paid — send reference"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Runs the EcoCash "Send money" USSD code with the client's number and the
/// order total already filled in, so the customer only sees EcoCash's own
/// PIN prompt and confirmation. Their reference arrives by SMS afterwards.
class _EcocashUssdButton extends StatefulWidget {
  const _EcocashUssdButton({required this.code, required this.amount, this.autoRun = false, this.onAutoRun});

  final String code;
  final double amount;
  final bool autoRun;
  final VoidCallback? onAutoRun;

  @override
  State<_EcocashUssdButton> createState() => _EcocashUssdButtonState();
}

class _EcocashUssdButtonState extends State<_EcocashUssdButton> {
  UssdResult? _last;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) {
      widget.onAutoRun?.call();
      // After the sheet's slide-in, so EcoCash's prompt doesn't cut it off.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _run();
      });
    }
  }

  Future<void> _run() async {
    HapticFeedback.selectionClick();
    final result = await runUssd(widget.code);
    if (!mounted) return;
    setState(() => _last = result);
    if (result == UssdResult.failed) {
      showGlassToast(context, "Couldn't open EcoCash. Dial ${widget.code} yourself.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = switch (_last) {
      UssdResult.called =>
        'Enter your EcoCash PIN and confirm. When the confirmation SMS arrives, type its reference below.',
      UssdResult.dialer => 'Tap the call button in your dialer to start the payment, then enter your PIN.',
      _ => 'Opens EcoCash with the amount filled in. You just enter your PIN and confirm.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          onPressed: _run,
          icon: IconlyLight.call,
          child: Text(_last == null ? 'Pay ${money(widget.amount)} with EcoCash' : 'Open EcoCash again'),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.code));
            showGlassToast(context, 'Code copied');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$hint  '),
                  TextSpan(
                    text: widget.code,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
              style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.number, this.text);

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Label/value rows, each value tap-to-copy.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (label, value) in rows)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                showGlassToast(context, '$label copied');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconlyLight.info_circle, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.order, required this.message});

  final Order order;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pay manually', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          '$message Message us on WhatsApp and we will send you the details for order ${order.id}.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        GradientButton(
          onPressed: () => openWhatsApp('Hi Dellinoo, how do I pay for order ${order.id} (${money(order.total)})?'),
          child: const Text('Message us on WhatsApp'),
        ),
      ],
    );
  }
}

/// Order-screen card for a manual payment that's waiting on the admin, or
/// was rejected — with a button to (re)send the reference.
class ManualPaymentStatusCard extends StatelessWidget {
  const ManualPaymentStatusCard(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final mp = order.manualPayment;
    if (mp == null || order.status != OrderStatus.placed || mp.status == ManualPaymentStatus.confirmed) {
      return const SizedBox.shrink();
    }
    final rejected = mp.status == ManualPaymentStatus.rejected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (rejected ? AppColors.accentOrange : AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  rejected ? IconlyLight.info_circle : IconlyLight.time_circle,
                  color: rejected ? AppColors.accentOrange : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  rejected ? "We couldn't confirm your payment" : 'Checking your payment',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rejected
                  ? 'Reference ${mp.reference} (${mp.channel.label}) didn\'t match'
                        '${mp.note?.isNotEmpty ?? false ? ': ${mp.note}' : '.'}'
                  : 'Reference ${mp.reference} via ${mp.channel.label}, sent ${dateTime(mp.submittedAt)}. '
                        "We'll notify you as soon as it's confirmed.",
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showManualPaymentSheet(context, order),
                child: Text(rejected ? 'Send reference again' : 'Edit reference'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
