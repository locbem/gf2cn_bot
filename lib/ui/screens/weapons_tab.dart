import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/cached_image.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'weapon_detail_page.dart';

/// Tab "Vũ khí" (武器介绍): lưới + tìm kiếm + lọc loại/độ hiếm.
class WeaponsTab extends StatefulWidget {
  const WeaponsTab({super.key, required this.tab});

  final CatTab tab;

  @override
  State<WeaponsTab> createState() => _WeaponsTabState();
}

class _WeaponsTabState extends State<WeaponsTab> {
  final Map<String, int> _selected = {};
  String _query = '';

  bool _matches(Weapon w, String q) {
    for (final f in widget.tab.filters) {
      final v = _selected[f.key] ?? 0;
      if (v != 0 && w.field(f.field) != v) return false;
    }
    if (q.isEmpty) return true;
    return w.name.toLowerCase().contains(q) || w.nameZh.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final q = _query.toLowerCase();
    final items = [for (final w in app.data.weapons) if (_matches(w, q)) w];
    final typeFilter = widget.tab.filter('type');
    return CustomScrollView(
      key: const PageStorageKey('weapons'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          sliver: SliverToBoxAdapter(
            child: FilterBar(
              filters: widget.tab.filters,
              selected: _selected,
              hint: s.t('search_weapons_hint'),
              colorOf: (key, id) => key == 'rarity' ? AppColors.weaponRarity(id) : null,
              onQueryChanged: (v) => setState(() => _query = v),
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
            child: EmptyState(message: s.t('no_results'), icon: Icons.search_off_rounded),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => WeaponCard(
                weapon: items[i],
                typeName: typeFilter?.optionName(items[i].type) ?? '',
              ),
            ),
          ),
      ],
    );
  }
}

class WeaponCard extends StatelessWidget {
  const WeaponCard({super.key, required this.weapon, required this.typeName});

  final Weapon weapon;
  final String typeName;

  @override
  Widget build(BuildContext context) {
    final rarity = AppColors.weaponRarity(weapon.rarity);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => WeaponDetailPage.open(context, weapon.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [rarity.withValues(alpha: 0.16), Colors.transparent],
            ),
          ),
          child: Stack(
            children: [
              Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: rarity)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'weapon-${weapon.id}',
                        child: AppImage(
                          weapon.pic,
                          fit: BoxFit.contain,
                          decodeWidth: 240,
                          placeholderColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weapon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    if (typeName.isNotEmpty)
                      Text(typeName, style: const TextStyle(fontSize: 11.5, color: AppColors.textDim)),
                  ],
                ),
              ),
              Positioned(top: 6, right: 6, child: CornerBadge(weapon.icon)),
            ],
          ),
        ),
      ),
    );
  }
}
