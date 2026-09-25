import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/glass.dart';

class _Guide {
  const _Guide(this.title, this.columns, this.rows, this.tips);

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> tips;
}

const _clothesTips = [
  'Chest: measure around the fullest part, keeping the tape level.',
  'Waist: measure around your natural waistline.',
  'Between two sizes? Pick the bigger one — imported sizes often run small.',
];

/// Size charts per category. Values are standard Asian sizing (most stock
/// comes from China); the admin can refine them later.
const _guides = {
  'women': _Guide(
    'Women\'s sizes',
    ['Size', 'Bust (cm)', 'Waist (cm)', 'Hips (cm)'],
    [
      ['S', '82–86', '64–68', '88–92'],
      ['M', '86–90', '68–72', '92–96'],
      ['L', '90–96', '72–78', '96–102'],
      ['XL', '96–102', '78–84', '102–108'],
    ],
    _clothesTips,
  ),
  'men': _Guide(
    'Men\'s sizes',
    ['Size', 'Chest (cm)', 'Waist (cm)', 'Neck (cm)'],
    [
      ['S', '88–92', '74–78', '37'],
      ['M', '92–98', '78–84', '38–39'],
      ['L', '98–104', '84–90', '40–41'],
      ['XL', '104–110', '90–96', '42–43'],
      ['XXL', '110–116', '96–102', '44–45'],
    ],
    _clothesTips,
  ),
  'kids': _Guide(
    'Kids\' sizes',
    ['Age', 'Height (cm)', 'Chest (cm)'],
    [
      ['2–3Y', '92–98', '52–54'],
      ['4–5Y', '104–110', '56–58'],
      ['6–7Y', '116–122', '60–62'],
      ['8–9Y', '128–134', '64–67'],
    ],
    [
      'Go by height rather than age — children grow at different speeds.',
      'Buying ahead? Choose one size up so it lasts longer.',
    ],
  ),
  'shoes': _Guide(
    'Shoe sizes',
    ['EU', 'UK', 'US (men)', 'Foot (cm)'],
    [
      ['38', '5', '6', '24.0'],
      ['39', '6', '7', '24.7'],
      ['40', '6.5', '7.5', '25.3'],
      ['41', '7', '8', '26.0'],
      ['42', '8', '9', '26.7'],
      ['43', '9', '10', '27.3'],
      ['44', '9.5', '10.5', '28.0'],
    ],
    [
      'Stand on paper, mark your heel and longest toe, then measure the gap.',
      'Measure in the evening — feet are slightly bigger later in the day.',
      'If you are between sizes, choose the bigger one.',
    ],
  ),
};

bool hasSizeGuide(String categoryId) => _guides.containsKey(categoryId);

void showSizeGuide(BuildContext context, String categoryId) {
  final guide = _guides[categoryId];
  if (guide == null) return;
  showGlassBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(guide.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Table(
              border: TableBorder(horizontalInside: BorderSide(color: AppColors.line)),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.primary),
                  children: [
                    for (final c in guide.columns)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text(
                          c,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                  ],
                ),
                for (final (i, row) in guide.rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(color: i.isEven ? AppColors.field : AppColors.surface),
                    children: [
                      for (final (j, cell) in row.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(
                            cell,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: j == 0 ? FontWeight.w800 : FontWeight.w500, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('How to measure', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final tip in guide.tips)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(tip, style: TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
