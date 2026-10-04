import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/cached_image.dart';
import '../widgets/common.dart';
import 'doll_detail_page.dart';
import 'media_detail_page.dart';
import 'story_reader_page.dart';
import 'weapon_detail_page.dart';

/// Tìm kiếm toàn bộ: nhân vật, vũ khí, bài thiết lập, tư liệu.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final q = _q.toLowerCase();
    bool has(String v) => v.toLowerCase().contains(q);

    final List<DollSummary> dolls = q.isEmpty
        ? const []
        : [
            for (final d in app.data.dolls)
              if (has(d.name) || has(d.nameZh) || has(d.enName) || has(d.weapon)) d,
          ];
    final List<Weapon> weapons = q.isEmpty
        ? const []
        : [for (final w in app.data.weapons) if (has(w.name) || has(w.nameZh)) w];
    final List<WorldSummary> world = q.isEmpty
        ? const []
        : [for (final w in app.data.world) if (has(w.title) || has(w.titleZh) || w.chapters.any(has)) w];
    final List<MediaItem> media = q.isEmpty
        ? const []
        : [for (final m in app.data.media) if (has(m.title) || has(m.titleZh)) m];
    final total = dolls.length + weapons.length + world.length + media.length;

    final children = <Widget>[];
    void group(String title, int count, List<Widget> tiles) {
      if (tiles.isEmpty) return;
      children.add(SectionLabel('$title ($count)'));
      children.addAll(tiles);
    }

    group(s.t('results_dolls'), dolls.length, [
      for (final d in dolls)
        ListTile(
          leading: AppImage(d.pic, width: 40, height: 56, decodeWidth: 40, borderRadius: BorderRadius.circular(8)),
          title: Text(d.name),
          subtitle: Text([d.rarity, d.attr, d.role].where((e) => e.isNotEmpty).join(' · ')),
          onTap: () => DollDetailPage.open(context, d.id),
        ),
    ]);
    group(s.t('results_weapons'), weapons.length, [
      for (final w in weapons)
        ListTile(
          leading: SizedBox(
            width: 72,
            child: AppImage(w.pic, fit: BoxFit.contain, decodeWidth: 72, placeholderColor: Colors.transparent),
          ),
          title: Text(w.name),
          onTap: () => WeaponDetailPage.open(context, w.id),
        ),
    ]);
    group(s.t('results_world'), world.length, [
      for (final w in world)
        ListTile(
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(w.title),
          subtitle: Text(s.t('chapters_count', {'n': w.chapters.length})),
          onTap: () => StoryReaderPage.open(context, w.id),
        ),
    ]);
    group(s.t('results_media'), media.length, [
      for (final m in media)
        ListTile(
          leading: const Icon(Icons.perm_media_outlined),
          title: Text(m.title),
          onTap: () => MediaDetailPage.open(context, m.id),
        ),
    ]);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: searchDecoration(s.t('search_hint')),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 200), () {
                if (mounted) setState(() => _q = v.trim());
              });
            },
          ),
        ),
      ),
      body: q.isEmpty
          ? const EmptyState(message: '', icon: Icons.search_rounded)
          : total == 0
              ? EmptyState(message: s.t('no_results'), icon: Icons.search_off_rounded)
              : MaxWidth(
                  maxWidth: 900,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: children,
                  ),
                ),
    );
  }
}
