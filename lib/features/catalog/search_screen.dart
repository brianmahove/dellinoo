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

  @override
  void dispose() {
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
                                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            ProductSliverGrid(results),
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
