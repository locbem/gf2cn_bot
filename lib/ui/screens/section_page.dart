import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'dolls_tab.dart';
import 'media_tab.dart';
import 'search_page.dart';
import 'weapons_tab.dart';
import 'world_tab.dart';

/// Một mục lớn của wiki (游戏图鉴 / 世界设定 / 其他资讯) với các tab con
/// lấy đúng theo danh mục của wiki.
class SectionPage extends StatelessWidget {
  const SectionPage({super.key, required this.sectionKey});

  final String sectionKey;

  Widget _tabContent(CatTab tab) {
    final Widget child = switch (sectionKey) {
      'handbook' => tab.key == 'weapons' ? WeaponsTab(tab: tab) : DollsTab(tab: tab),
      'world' => WorldTab(cid: tab.cid),
      _ => MediaTab(cid: tab.cid),
    };
    return KeepAliveTab(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final section = app.data.category.section(sectionKey);
    final tabs = section?.tabs ?? const <CatTab>[];
    final title = s.t('sec_$sectionKey');

    final actions = <Widget>[
      IconButton(
        tooltip: s.t('search'),
        icon: const Icon(Icons.search_rounded),
        onPressed: () => SearchPage.open(context),
      ),
      const LangToggleButton(),
      const SizedBox(width: 8),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: EmptyState(message: s.t('no_data')),
      );
    }

    return DefaultTabController(
      key: ValueKey('$sectionKey-${tabs.length}'),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Align(
              alignment: Alignment.centerLeft,
              child: appTabBar(tabs: [for (final t in tabs) Tab(text: t.name)]),
            ),
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) _tabContent(t)]),
      ),
    );
  }
}
