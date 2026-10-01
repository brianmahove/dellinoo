import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contact.dart';
import '../../core/format.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

/// Profile → "Delivery information": how long each kind of order takes, what
/// it costs where, and what the China leg looks like. The fees and areas are
/// the live `delivery_areas` collection — the same list checkout uses — so the
/// admin only ever edits them in one place.
class DeliveryInfoScreen extends ConsumerWidget {
  const DeliveryInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(deliveryAreasProvider);

    return Scaffold(
      appBar: const PageHeader(title: 'Delivery information'),
      floatingActionButton: const WhatsAppButton(message: 'Hi Dellinoo, I have a question about delivery.'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          Text(
            'How your order gets to you, what it costs, and how long it takes.',
            style: TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.45),
          ),
          const SizedBox(height: 18),

          const _SectionTitle(IconlyLight.time_circle, 'How soon will I get it?'),
          // Both promises come straight from StockStatus.etaDays, so the dates
          // here can never drift from the ones on a product card.
          _StockCard(StockStatus.inStock),
          _StockCard(StockStatus.preorder),
          const SizedBox(height: 10),

          const _SectionTitle(Icons.local_shipping_outlined, 'Areas and fees'),
          areas.when(
            loading: () => const _AreasSkeleton(),
            error: (_, _) => _AreasError(onRetry: () => ref.invalidate(deliveryAreasProvider)),
            data: (list) => _AreasCard(list),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 18),
            child: Text(
              'The exact fee for your address is always shown at checkout before you pay.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
            ),
          ),

          const _SectionTitle(IconlyLight.send, 'Orders coming from China'),
          const _JourneyCard(),

          const _SectionTitle(IconlyLight.shield_done, 'On the day'),
          SurfaceCard(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet('We call or WhatsApp you before the courier sets off, so nobody knocks at a closed gate.'),
                _Bullet('Have your order number ready — it is on the order page and in your confirmation.'),
                _Bullet('Someone else can receive the parcel for you; just tell us who to expect.'),
                _Bullet('Check the parcel before the courier leaves. If anything is wrong, tell us the same day.'),
              ],
            ),
          ),

          SurfaceCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not sure about your area?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'If your town is not on the list, message us — we deliver by courier to most of Zimbabwe.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: () async {
                    final ok = await openWhatsApp('Hi Dellinoo, do you deliver to my area?');
                    if (!ok && context.mounted) showGlassToast(context, 'Could not open WhatsApp');
                  },
                  child: const Text('Ask about my area'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/help'),
                    child: const Text('More answers in Help & FAQs'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.accent),
        const SizedBox(width: 9),
        Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// "In stock" / "From China" explained, with today's concrete arrival date.
class _StockCard extends StatelessWidget {
  const _StockCard(this.status);

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final inStock = status == StockStatus.inStock;
    final tint = inStock ? AppColors.inStockSoft : AppColors.preorderSoft;
    final ink = inStock ? AppColors.inStock : AppColors.preorder;
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
            child: Icon(inStock ? IconlyBold.tick_square : IconlyBold.time_circle, color: ink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inStock ? 'In stock' : 'From China',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  inStock
                      ? 'Already here in Zimbabwe. Delivered in about 1–3 days.'
                      : 'We buy it for you in China and fly it in — about 2–3 weeks.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(30)),
                  child: Text(
                    'Order today: ${arrivalShort(status)}',
                    style: TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AreasCard extends StatelessWidget {
  const _AreasCard(this.areas);

  final List<DeliveryArea> areas;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return SurfaceCard(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Text(
          'Delivery areas are being updated. Message us and we will quote your area.',
          style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
        ),
      );
    }
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < areas.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.line, indent: 16, endIndent: 16),
            _AreaRow(areas[i]),
          ],
        ],
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow(this.area);

  final DeliveryArea area;

  @override
  Widget build(BuildContext context) {
    final free = area.fee == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.name,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                Text(area.eta, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: free ? AppColors.inStockSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              free ? 'Free' : money(area.fee),
              style: TextStyle(
                color: free ? AppColors.inStock : AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreasSkeleton extends StatelessWidget {
  const _AreasSkeleton();

  @override
  Widget build(BuildContext context) => SurfaceCard(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 13,
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(7)),
                  ),
                ),
                const SizedBox(width: 40),
                Container(
                  width: 48,
                  height: 13,
                  decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(7)),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _AreasError extends StatelessWidget {
  const _AreasError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Couldn't load the delivery areas. Check your connection and try again.",
          style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      ],
    ),
  );
}

/// The China leg, drawn as the same ordered steps an order's tracking shows.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard();

  static const _steps = [
    (OrderStatus.boughtInChina, 'We buy your item from our supplier and pack it at the warehouse.'),
    (OrderStatus.inTransit, 'Your parcel flies to Zimbabwe with the next shipment.'),
    (OrderStatus.arrivedZim, 'It clears and reaches our Harare base, ready to go out to you.'),
    (OrderStatus.outForDelivery, 'The courier brings it to your address — or you collect at pickup.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You can follow every step on the order page.',
            style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                        child: Icon(_steps[i].$1.icon, size: 17, color: AppColors.accent),
                      ),
                      if (i < _steps.length - 1) Expanded(child: Container(width: 2, color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$1.label,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                          const SizedBox(height: 3),
                          Text(_steps[i].$2, style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.45)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45)),
        ),
      ],
    ),
  );
}
