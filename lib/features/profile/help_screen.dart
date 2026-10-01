import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/contact.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/motion.dart';

/// One question and its answer, with an optional button that takes the
/// customer straight to the screen the answer talks about.
class _Faq {
  const _Faq(this.question, this.answer, {this.actionLabel, this.onAction});

  final String question;
  final String answer;
  final String? actionLabel;
  final void Function(BuildContext context)? onAction;

  bool matches(String query) => question.toLowerCase().contains(query) || answer.toLowerCase().contains(query);
}

class _FaqSection {
  const _FaqSection(this.icon, this.title, this.faqs);

  final IconData icon;
  final String title;
  final List<_Faq> faqs;
}

void Function(BuildContext) _push(String route) =>
    (context) => context.push(route);

void Function(BuildContext) _whatsApp(String message) => (context) async {
  final ok = await openWhatsApp(message);
  if (!ok && context.mounted) showGlassToast(context, 'Could not open WhatsApp');
};

/// Static, hardcoded help content — the answers change rarely and the admin
/// panel has no FAQ editor, so this is deliberately not a Firestore
/// collection. Keep the returns/warranty wording in sync with the product
/// page's `_TrustBadges`.
final _sections = <_FaqSection>[
  _FaqSection(IconlyLight.bag, 'Ordering', [
    const _Faq(
      'How do I place an order?',
      'Add what you want to your cart, open the Cart tab and tap Checkout. Choose a delivery '
          'address, pay, and you get an order number like DL10345 that you can follow under Orders.',
    ),
    const _Faq(
      'Do I need an account?',
      'Yes. Checkout asks you to sign in so your orders, addresses and invoices stay attached '
          'to you — and so we can reach you when your parcel lands.',
    ),
    _Faq(
      'Can I change or cancel an order?',
      'Message us on WhatsApp with your order number as soon as you can. Items already bought '
          'in China are harder to cancel, so the sooner the better.',
      actionLabel: 'Chat on WhatsApp',
      onAction: _whatsApp('Hi Dellinoo, I need to change an order.'),
    ),
    _Faq(
      "I can't find the item I want",
      'Send us a link from any shop (or just describe it) and we will come back to you with a '
          'price. Most things we can get, we will get.',
      actionLabel: 'Request an item',
      onAction: _push('/request-item'),
    ),
  ]),
  _FaqSection(IconlyLight.time_circle, 'Stock and arrival times', [
    const _Faq(
      'What does "In stock" mean?',
      'The item is already here in Zimbabwe, so it reaches you in about 1–3 days. Every product '
          'shows the date you should have it by.',
    ),
    const _Faq(
      'What does "From China" mean?',
      'It is a pre-order: we buy it for you in China and fly it in. That usually takes about '
          '2–3 weeks, and the product page always shows the expected date.',
    ),
    _Faq(
      'Why does my order have extra steps?',
      'Orders with China items pass through Bought in China, Flying to Zimbabwe and Arrived in '
          'Harare before delivery. You can watch each step on the order page.',
      actionLabel: 'My orders',
      onAction: _push('/orders'),
    ),
  ]),
  _FaqSection(IconlyLight.wallet, 'Payment', [
    const _Faq(
      'How can I pay?',
      'EcoCash and InnBucks through Paynow. Visa, Mastercard and ZimSwitch cards are coming '
          'soon. All prices are in US dollars.',
    ),
    _Faq(
      'My payment did not go through',
      'Nothing is lost — open the order and tap Complete payment. You can try again with a '
          'different method if the first one failed.',
      actionLabel: 'My orders',
      onAction: _push('/orders'),
    ),
    const _Faq(
      'How do I know my payment worked?',
      'The order turns to Paid on its own as soon as the payment is confirmed. You do not need '
          'to send us a screenshot, though you are welcome to.',
    ),
    const _Faq(
      'Do you have promo codes?',
      'Yes — enter the code in the promo box at checkout and the discount comes off your items '
          'straight away. Delivery is never discounted.',
    ),
  ]),
  _FaqSection(Icons.local_shipping_outlined, 'Delivery', [
    const _Faq(
      'How much is delivery?',
      'It depends on your area. Pick your address at checkout and the fee is shown before you '
          'pay. There is also a free pickup point if you would rather collect.',
    ),
    _Faq(
      'Where do you deliver?',
      'Across our listed delivery areas. If yours is not on the list at checkout, message us '
          'and we will work something out.',
      actionLabel: 'Chat on WhatsApp',
      onAction: _whatsApp('Hi Dellinoo, do you deliver to my area?'),
    ),
    _Faq(
      'Can I save more than one address?',
      'Yes. Add home, work or a friend’s place under Delivery addresses and choose between '
          'them at checkout.',
      actionLabel: 'Delivery addresses',
      onAction: _push('/addresses'),
    ),
  ]),
  // TODO: confirm the returns window and warranty terms with the client before
  // release — these mirror the product page's trust badges, which are
  // themselves placeholders.
  _FaqSection(IconlyLight.shield_done, 'Returns and warranty', [
    _Faq(
      'Can I return something?',
      'If an item arrives damaged or is not what you ordered, tell us within 7 days and we will '
          'sort it out. Message us with your order number and a photo.',
      actionLabel: 'Chat on WhatsApp',
      onAction: _whatsApp('Hi Dellinoo, I would like to return an item from my order.'),
    ),
    const _Faq(
      'Is there a warranty?',
      'Phones, laptops, watches and other electronics carry a 6-month warranty against faults. '
          'Keep your order number — it is your proof of purchase.',
    ),
    const _Faq(
      'Are the products genuine?',
      'We buy directly from our suppliers in China and check goods before they go out. If '
          'something is not right, we make it right.',
    ),
  ]),
  _FaqSection(IconlyLight.profile, 'Account and privacy', [
    _Faq(
      'How do I change my name, email or password?',
      'Tap your name at the top of the Profile tab to open your account, where you can rename '
          'yourself, change your email or password and link sign-in methods.',
      actionLabel: 'My account',
      onAction: _push('/account'),
    ),
    _Faq(
      'How do I delete my account?',
      'Your account page has a Delete account button, and your saved addresses go with it. Past '
          'orders are kept as business records, as our data deletion policy explains.',
      actionLabel: 'My account',
      onAction: _push('/account'),
    ),
  ]),
  _FaqSection(IconlyLight.document, 'Invoices', [
    _Faq(
      'Can I get an invoice?',
      'Open the order and tap Request an invoice, then fill in the name, address and TIN it '
          'should be made out to. We send the PDF to you on WhatsApp.',
      actionLabel: 'My orders',
      onAction: _push('/orders'),
    ),
  ]),
];

/// Profile → "Help & FAQs": searchable, expandable answers plus a way through
/// to WhatsApp when none of them fit.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    // Keep only the sections that still have a matching question.
    final sections = query.isEmpty
        ? _sections
        : [
            for (final s in _sections)
              if (s.faqs.any((f) => f.matches(query)))
                _FaqSection(s.icon, s.title, s.faqs.where((f) => f.matches(query)).toList()),
          ];

    return Scaffold(
      appBar: const PageHeader(title: 'Help & FAQs'),
      floatingActionButton: const WhatsAppButton(message: 'Hi Dellinoo, I have a question.'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          Text(
            'Answers to the questions we get asked most. Still stuck? We are on WhatsApp.',
            style: TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.45),
          ),
          const SizedBox(height: 16),
          _SearchField(controller: _search, onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 18),
          if (sections.isEmpty)
            _NoResults(onChat: () => _whatsApp('Hi Dellinoo, I have a question: $_query')(context))
          else
            for (final section in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                child: Row(
                  children: [
                    Icon(section.icon, size: 19, color: AppColors.accent),
                    const SizedBox(width: 9),
                    Text(section.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // A Material rather than a SurfaceCard: ExpansionTile is a
              // ListTile, and it paints its background and ink splash on the
              // nearest Material ancestor — a plain coloured box in between
              // would hide them (and Flutter asserts about it).
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 2),
                      for (var i = 0; i < section.faqs.length; i++) ...[
                        if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.line, indent: 16, endIndent: 16),
                        _FaqTile(
                          faq: section.faqs[i],
                          // Searching should reveal the match, not make the
                          // customer tap every result open again.
                          initiallyExpanded: query.isNotEmpty,
                        ),
                      ],
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ],
          const SizedBox(height: 4),
          const _ContactCard(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: AppColors.ink, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search help',
        hintStyle: TextStyle(color: AppColors.muted, fontSize: 15),
        prefixIcon: Icon(IconlyLight.search, color: AppColors.muted, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: AppColors.muted, size: 20),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.initiallyExpanded});

  final _Faq faq;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final action = faq.actionLabel;
    return Theme(
      // ExpansionTile draws its own top/bottom dividers; this card has its own.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // Rebuild the tile when a search changes which answers are on screen,
        // so `initiallyExpanded` is honoured for the new set.
        key: ValueKey('${faq.question}-$initiallyExpanded'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.muted,
        title: Text(
          faq.question,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        children: [
          Text(faq.answer, style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5)),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: PressScale(
                child: GestureDetector(
                  onTap: () => faq.onAction?.call(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          action,
                          style: TextStyle(color: AppColors.accent, fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Icon(IconlyLight.arrow_right_2, size: 15, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onChat});

  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      child: Column(
        children: [
          Icon(IconlyLight.search, size: 34, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No answer for that', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Ask us directly — we usually reply within the hour.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          GradientButton(onPressed: onChat, child: const Text('Ask on WhatsApp')),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          const FaIcon(FontAwesomeIcons.whatsapp, size: 32, color: Color(0xFF25D366)),
          const SizedBox(height: 12),
          const Text('Still need a hand?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Message us on WhatsApp with your order number and we will pick it up from there.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () => _whatsApp('Hi Dellinoo, I have a question.')(context),
            child: const Text('Chat with us'),
          ),
        ],
      ),
    );
  }
}
