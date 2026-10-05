import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'iconly.dart';

/// The accounts customers pay into manually (Firestore `meta/paymentDetails`,
/// read by the customer app's manual payment sheet — field names kept in
/// sync by hand with `PaymentDetails` in lib/data/models.dart). Leave a
/// channel's number blank to stop offering it.
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  static const _fields = [
    'ecocashNumber',
    'ecocashName',
    'ecocashUssd',
    'innbucksNumber',
    'innbucksName',
    'bankName',
    'bankAccountName',
    'bankAccountNumber',
    'bankBranch',
    'instructions',
  ];

  final _doc = FirebaseFirestore.instance.collection('meta').doc('paymentDetails');
  final _controllers = {for (final f in _fields) f: TextEditingController()};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = (await _doc.get()).data() ?? const {};
      for (final f in _fields) {
        _controllers[f]!.text = data[f] as String? ?? '';
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _doc.set({
        for (final f in _fields) f: _controllers[f]!.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(const SnackBar(content: Text('Payment details saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(String key, String label, {String? hint, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controllers[key],
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  Widget _section(IconData icon, String title, String subtitle, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySoft,
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(IconlyLight.tick_square),
        label: const Text('Save'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Customers who choose "Pay manually" send money to these accounts and enter the transaction '
                'reference. Match it on your statement, then confirm the order on the Orders screen. '
                'Leave a number blank to hide that option.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              _section(IconlyLight.wallet, 'EcoCash', 'Merchant code or the number customers send money to.', [
                _field('ecocashNumber', 'EcoCash number / merchant code', hint: 'e.g. 0771234567'),
                _field('ecocashName', 'Registered name', hint: 'The name customers see when they send'),
                _field(
                  'ecocashUssd',
                  'USSD code the app dials (optional)',
                  hint: 'Blank = *153*1*1*{number}*{amount}#  (Send money). Use {number} and {amount}.',
                ),
              ]),
              const SizedBox(height: 10),
              _section(IconlyLight.wallet, 'InnBucks', 'The InnBucks account customers send money to.', [
                _field('innbucksNumber', 'InnBucks number'),
                _field('innbucksName', 'Registered name'),
              ]),
              const SizedBox(height: 10),
              _section(IconlyLight.document, 'Bank transfer', 'For customers paying from a bank or ZIPIT.', [
                _field('bankName', 'Bank', hint: 'e.g. NMB Bank'),
                _field('bankAccountName', 'Account name'),
                _field('bankAccountNumber', 'Account number'),
                _field('bankBranch', 'Branch'),
              ]),
              const SizedBox(height: 10),
              _section(
                IconlyLight.info_circle,
                'Instructions (optional)',
                'Replaces the default text at the top of the sheet.',
                [
                  _field(
                    'instructions',
                    'Instructions',
                    hint: 'e.g. Send the exact amount, then enter the reference from your SMS.',
                    maxLines: 3,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
