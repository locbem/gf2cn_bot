import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/cached_image.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'doll_detail_page.dart';

/// Tab "Nhân vật" (人形介绍): lưới ảnh + tìm kiếm + bộ lọc thuộc tính/lớp/đội.
class DollsTab extends StatefulWidget {
  const DollsTab({super.key, required this.tab});

  final CatTab tab;

  @override
  State<DollsTab> createState() => _DollsTabState();
}

class _DollsTabState extends State<DollsTab> {
  final Map<String, int> _selected = {};
  String _query = '';

  List<DollSummary> _filter(List<DollSummary> all) {
    final q = _query.toLowerCase();
    return [
      for (final d in all)
        if (_matches(d, q)) d,
    ];
  }

  bool _matches(DollSummary d, String q) {
    for (final f in widget.tab.filters) {
      final v = _selected[f.key] ?? 0;
      if (v != 0 && d.field(f.field) != v) return false;
    }
    if (q.isEmpty) return true;
    return d.name.toLowerCase().contains(q) ||
        d.nameZh.toLowerCase().contains(q) ||
        d.enName.toLowerCase().contains(q) ||
        d.weapon.toLowerCase().contains(q) ||
        d.team.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final items = _filter(app.data.dolls);
    final wide = isWide(context);
    return CustomScrollView(
      key: const PageStorageKey('dolls'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          sliver: SliverToBoxAdapter(
            child: FilterBar(
              filters: widget.tab.filters,
              selected: _selected,
              hint: s.t('search_dolls_hint'),
              colorOf: (key, id) => key == 'attr' ? AppColors.attr(id) : null,
              onQueryChanged: (q) => setState(() => _query = q),
              onFilterChanged: (key, id) => setState(() {
                if (id == null) {
                  _selected.remove(key);
                } else {
                  _selected[key] = id;
                }
              }),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(message: s.t('no_results'), icon: Icons.person_search_outlined),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: wide ? 150 : 124,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 0.58,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => DollCard(doll: items[i]),
            ),
          ),
      ],
    );
  }
}

class DollCard extends StatelessWidget {
  const DollCard({super.key, required this.doll});

  final DollSummary doll;

  @override
  Widget build(BuildContext context) {
    final rarity = AppColors.dollRarity(doll.rarityLevel);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => DollDetailPage.open(context, doll.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'doll-${doll.id}',
                      child: AppImage(doll.pic, alignment: Alignment.topCenter, decodeWidth: 150),
                    ),
                    // Vạch màu độ hiếm ở đáy ảnh
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 26,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [rarity.withValues(alpha: 0), rarity.withValues(alpha: 0.55)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(left: 0, right: 0, bottom: 0, height: 3, child: ColoredBox(color: rarity)),
                    Positioned(top: 5, left: 5, child: CornerBadge(doll.icon)),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Column(
                        children: [
                          _Dot(color: AppColors.attr(doll.attrId)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: Icon(roleIcon(doll.roleId), size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              doll.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 1.5),
        ),
      );
}
