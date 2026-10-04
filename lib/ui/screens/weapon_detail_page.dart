import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/cached_image.dart';
import '../widgets/common.dart';
import '../widgets/image_viewer.dart';
import '../widgets/section_card.dart';
import 'doll_detail_page.dart';

/// Trang chi tiết vũ khí: ảnh, loại, độ hiếm, Thuộc tính (属性) và Điều chỉnh (调校).
class WeaponDetailPage extends StatelessWidget {
  const WeaponDetailPage({super.key, required this.id});

  final int id;

  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WeaponDetailPage(id: id)));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final w = app.data.weaponById(id);
    if (w == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(message: s.t('error_load')));
    }
    final tab = app.data.category.tab('weapons');
    final typeName = tab?.filter('type')?.optionName(w.type) ?? '';
    final rarityName = tab?.filter('rarity')?.optionName(w.rarity) ?? '';
    final owner = _ownerOf(app, w);
    final rarity = AppColors.weaponRarity(w.rarity);
    final wide = isWide(context);

    final header = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rarity.withValues(alpha: 0.22), AppColors.card],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.6,
            child: GestureDetector(
              onTap: () => ImageViewer.open(context, [w.pic], titles: [w.name]),
              child: Hero(
                tag: 'weapon-${w.id}',
                child: AppImage(w.pic, fit: BoxFit.contain, decodeWidth: 600, placeholderColor: Colors.transparent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(w.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(rarityName, color: rarity, icon: Icons.star_rounded),
              Tag(typeName, color: AppColors.text, icon: Icons.category_outlined),
            ],
          ),
          if (owner != null) ...[
            const SizedBox(height: 12),
            Material(
              color: AppColors.cardHigh,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => DollDetailPage.open(context, owner.id),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      AppImage(owner.pic,
                          width: 40, height: 56, decodeWidth: 40, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('w_owner'), style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                            Text(owner.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HtmlSection(title: s.t('w_attributes'), html: w.baseInfo),
        const SizedBox(height: 12),
        HtmlSection(title: s.t('w_tuning'), html: w.character),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(w.name),
        actions: const [LangToggleButton(), SizedBox(width: 8)],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: ListView(padding: const EdgeInsets.all(16), children: [header]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(4, 16, 16, 32),
                    children: [MaxWidth(maxWidth: 860, child: sections)],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              children: [header, const SizedBox(height: 12), sections],
            ),
    );
  }

  /// Nhân vật sở hữu vũ khí ấn ký: theo belong_hero, hoặc theo tên vũ khí.
  static DollSummary? _ownerOf(AppController app, Weapon w) {
    if (w.belongHero != 0) {
      final d = app.data.dollById(w.belongHero);
      if (d != null) return d;
    }
    for (final d in app.data.dolls) {
      if (d.weapon.isNotEmpty && d.weapon == w.name) return d;
    }
    return null;
  }
}
