import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/iconly.dart';

const _popular = ['iPhone', 'Sneakers', 'Dress', 'Handbag', 'Watch', 'Laptop', 'AirPods', 'Samsung'];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  /// Last query that returned results; saved to "Recent searches" on leave.
  String _lastHit = '';
  late final _recent = ref.read(recentSearchesProvider.notifier);

  @override
  void dispose() {
    final hit = _lastHit;
    if (hit.isNotEmpty) Future.microtask(() => _recent.add(hit));
    _controller.dispose();
    super.dispose();
  }

  void _set(String q) {
    _controller.text = q;
    setState(() => _query = q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryNames = {for (final c in categories) c.id: c.name.toLowerCase()};

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const BackCircleButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SearchPill(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      onSubmitted: (v) => _recent.add(v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (ref.watch(recentSearchesProvider).isNotEmpty) ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Recent searches',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                                ),
                              ),
                              TextButton(onPressed: _recent.clear, child: const Text('Clear')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final q in ref.watch(recentSearchesProvider))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Icon(IconlyLight.time_circle, color: AppColors.muted),
                              title: Text(q, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              trailing: Icon(IconlyLight.arrow_right_2, size: 18, color: AppColors.muted),
                              onTap: () => _set(q),
                            ),
                          const SizedBox(height: 18),
                        ],
                        const Text('Popular searches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in _popular)
                              PillChip(label: p, selected: false, dense: true, onTap: () => _set(p)),
                          ],
                        ),
                      ],
                    )
                  : ProductsBuilder(
                      builder: (all) {
                        final q = _query.toLowerCase();
                        final results = all
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(q) ||
                                  p.brand.toLowerCase().contains(q) ||
                                  (categoryNames[p.categoryId]?.contains(q) ?? false),
                            )
                            .toList();
                        if (results.isNotEmpty) _lastHit = _query;
                        if (results.isEmpty) {
                          return EmptyState(
                            icon: IconlyLight.search,
                            title: 'No results for "$_query"',
                            message: 'Try another word, or check the spelling.',
                          );
                        }
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                                child: Text(
                                  '${results.length} results',
                                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            ProductSliverGrid(results, animateKey: _query),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
