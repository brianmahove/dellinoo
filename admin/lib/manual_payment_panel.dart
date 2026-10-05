import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'glass_dialog.dart';
import 'notify.dart';
import 'theme.dart';
import 'iconly.dart';

// Manual payments: the customer sends money to the accounts on the Payment
// details screen and types in the transaction reference
// (`orders/{id}.manualPayment`, written by the customer app's
// lib/widgets/manual_payment.dart). The admin matches the reference against
// their EcoCash / InnBucks / bank statement here, then confirms (appends a
// `paid` status event — same as a Paynow payment — and pushes "Payment
// received") or rejects it with a reason (the customer is pushed and can
// resend). Field names kept in sync by hand with the customer app.

String manualChannelLabel(String? c) => switch (c) {
  'ecocash' => 'EcoCash',
  'innbucks' => 'InnBucks',
  'bank' => 'Bank transfer',
  _ => c ?? '',
};

String _lastStatus(Map<String, dynamic> d) {
  final history = d['history'] as List? ?? const [];
  return history.isEmpty ? 'placed' : (history.last as Map)['status'] as String;
}

/// A reference is in and nobody has checked it yet.
bool awaitingManualCheck(Map<String, dynamic> d) =>
    _lastStatus(d) == 'placed' && (d['manualPayment'] as Map?)?['status'] == 'submitted';

/// Shown in place of the status pill for orders waiting on a payment check.
const checkPaymentPill = _CheckPaymentPill();

class _CheckPaymentPill extends StatelessWidget {
  const _CheckPaymentPill();

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: 'Check payment', color: AppColors.accentOrange, background: AppColors.preorderSoft);
}

class ManualPaymentPanel extends StatelessWidget {
  const ManualPaymentPanel({super.key, required this.doc});

  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? const {};
    final mp = d['manualPayment'] as Map<String, dynamic>?;
    if (mp == null) return const SizedBox.shrink();
    final status = mp['status'] as String? ?? 'submitted';
    final pending = awaitingManualCheck(d);
    final submittedAt = (mp['submittedAt'] as Timestamp?)?.toDate();
    final reference = mp['reference'] as String? ?? '';
    final (color, label) = switch (status) {
      'confirmed' => (AppColors.inStock, 'Confirmed'),
      'rejected' => (AppColors.accentOrange, 'Rejected — waiting for the customer to resend'),
      _ when pending => (AppColors.accentOrange, 'Waiting for you to check'),
      _ => (AppColors.muted, 'Submitted'),
    };

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconlyLight.wallet, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manual payment · $label',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  reference,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
              IconButton(
                tooltip: 'Copy reference',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: reference));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
                },
              ),
            ],
          ),
          Text(
            [
              manualChannelLabel(mp['channel'] as String?),
              if ((mp['sender'] as String?)?.isNotEmpty ?? false) 'from ${mp['sender']}',
              if (submittedAt != null) DateFormat.yMMMd().add_jm().format(submittedAt),
            ].join('  ·  '),
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          if (status == 'rejected' && (mp['note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text('Reason given: ${mp['note']}', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => showFormPage(
                    context: context,
                    builder: (_) => _RejectDialog(doc: doc),
                  ),
                  child: const Text("Doesn't match"),
                ),
                FilledButton.icon(
                  onPressed: () => _confirm(context),
                  icon: const Icon(IconlyLight.tick_square, size: 18),
                  label: const Text('Confirm payment'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final d = doc.data() ?? const {};
    final mp = d['manualPayment'] as Map<String, dynamic>;
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Confirm payment?'),
        content: Text(
          'Only confirm once you can see reference ${mp['reference']} for the full amount on your '
          '${manualChannelLabel(mp['channel'] as String?)} statement. The customer is told their order is paid.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await doc.reference.update({
        'manualPayment.status': 'confirmed',
        'manualPayment.confirmedBy': FirebaseAuth.instance.currentUser?.email ?? '',
        'manualPayment.confirmedAt': Timestamp.now(),
        'history': FieldValue.arrayUnion([
          {
            'status': 'paid',
            'at': Timestamp.now(),
            'note': 'Ref ${mp['reference']} (${manualChannelLabel(mp['channel'] as String?)})',
          },
        ]),
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't confirm: $e")));
      return;
    }
    final outcome = await notifyOutcome('Payment confirmed', () => notifyOrderStatus(doc.id));
    messenger.showSnackBar(SnackBar(content: Text(outcome)));
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.doc});

  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.doc.reference.update({
        'manualPayment.status': 'rejected',
        'manualPayment.note': _note.text.trim(),
        'manualPayment.rejectedAt': Timestamp.now(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    final outcome = await notifyOutcome('Marked as not matching', () => notifyOrderStatus(widget.doc.id));
    messenger.showSnackBar(SnackBar(content: Text(outcome)));
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      title: const Text("Reference doesn't match"),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              'The order stays unpaid and the customer is asked to check the reference and send it again.',
              style: TextStyle(color: AppColors.muted),
            ),
            TextField(
              controller: _note,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Reason (shown to the customer)',
                hintText: 'e.g. No payment with this reference yet',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}
