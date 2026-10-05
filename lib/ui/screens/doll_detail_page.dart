import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_controller.dart';
import '../../state/voice_player.dart';
import '../theme.dart';
import '../widgets/cached_image.dart';
import '../widgets/common.dart';
import '../widgets/html_content.dart';
import '../widgets/image_viewer.dart';
import '../widgets/section_card.dart';
import '../widgets/voice_tile.dart';
import 'weapon_detail_page.dart';

/// Trang chi tiết nhân vật – bố cục giống wiki: Hồ sơ / Bồi dưỡng / Tư liệu / Lồng tiếng.
class DollDetailPage extends StatefulWidget {
  const DollDetailPage({super.key, required this.id});

  final int id;

  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DollDetailPage(id: id)));

  @override
  State<DollDetailPage> createState() => _DollDetailPageState();
}

class _DollDetailPageState extends State<DollDetailPage> {
  Future<DollDetail?>? _future;
  int _version = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (app.dataVersion != _version) {
      _version = app.dataVersion;
      _future = app.data.doll(widget.id);
    }
  }

  @override
  void dispose() {
    VoicePlayer.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final summary = app.data.dollById(widget.id);
    return FutureBuilder<DollDetail?>(
      future: _future,
      builder: (context, snap) {
        final detail = snap.data;
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: Text(summary?.name ?? '')),
            body: snap.connectionState == ConnectionState.done
                ? EmptyState(message: app.s.t('error_load'), icon: Icons.error_outline)
                : const LoadingState(),
          );
        }
        return isWide(context) ? _WideLayout(detail: detail) : _NarrowLayout(detail: detail);
      },
    );
  }
}

// ---------------------------------------------------------------- layouts

List<Tab> _tabs(S s) => [
      Tab(text: s.t('tab_profile')),
      Tab(text: s.t('tab_growth')),
      Tab(text: s.t('tab_archive')),
      Tab(text: s.t('tab_voice')),
    ];

List<Widget> _tabChildren(BuildContext context, DollDetail d, {required bool includeInfo}) => [
      _ProfileTab(detail: d, includeInfo: includeInfo),
      _GrowthTab(detail: d),
      _ArchiveTab(detail: d),
      _VoiceTab(detail: d),
    ];

List<Widget> _wrapTabs(List<Widget> children, {required bool nested}) => [
      for (var i = 0; i < children.length; i++) _TabScroll(index: i, nested: nested, child: children[i]),
    ];

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final size = MediaQuery.sizeOf(context);
    final expanded = (size.height * 0.6).clamp(320.0, 560.0).toDouble();
    final tabs = _tabs(s);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                pinned: true,
                expandedHeight: expanded,
                forceElevated: innerScrolled,
                backgroundColor: AppColors.bg,
                title: AnimatedOpacity(
                  opacity: innerScrolled ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(detail.summary.name),
                ),
                actions: const [LangToggleButton(), SizedBox(width: 8)],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _Header(detail: detail),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(46),
                  child: ColoredBox(
                    color: AppColors.bg,
                    child: appTabBar(tabs: tabs, scrollable: false),
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(children: _wrapTabs(_tabChildren(context, detail, includeInfo: true), nested: true)),
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tabs = _tabs(s);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(detail.summary.name),
          actions: const [LangToggleButton(), SizedBox(width: 12)],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 380, child: _SidePanel(detail: detail)),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  appTabBar(tabs: tabs, scrollable: false),
                  Expanded(
                    child: TabBarView(
                      children: _wrapTabs(_tabChildren(context, detail, includeInfo: false), nested: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bọc nội dung tab trong CustomScrollView (tương thích NestedScrollView).
class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.index, required this.nested, required this.child});

  final int index;
  final bool nested;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: PageStorageKey<String>('doll-tab-$index'),
        slivers: [
          if (nested) SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
            sliver: SliverToBoxAdapter(child: MaxWidth(maxWidth: 900, child: child)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- header

List<String> _portraitUrls(DollDetail d) => [
      d.portrait.mobile,
      d.portrait.pc,
      for (final sk in d.skins) ...[sk.mobile, sk.pc],
    ].where((u) => u.isNotEmpty).toList();

List<String> _portraitTitles(DollDetail d, S s) => [
      if (d.portrait.mobile.isNotEmpty) s.t('portrait'),
      if (d.portrait.pc.isNotEmpty) s.t('portrait'),
      for (final sk in d.skins) ...[
        if (sk.mobile.isNotEmpty) sk.name,
        if (sk.pc.isNotEmpty) sk.name,
      ],
    ];

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final portrait = d.portrait.any;
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => ImageViewer.open(context, _portraitUrls(d), titles: _portraitTitles(d, context.s)),
          child: Hero(
            tag: 'doll-${d.summary.id}',
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Chỉ dùng ảnh avatar nhỏ khi không có hình minh hoạ lớn; nếu không nó lộ ra qua phần trong suốt của ảnh lớn.
                if (portrait.isEmpty)
                  AppImage(d.summary.pic, alignment: Alignment.topCenter, decodeWidth: 200)
                else
                  AppImage(
                    portrait,
                    alignment: Alignment.topCenter,
                    decodeWidth: width,
                    placeholderColor: Colors.transparent,
                    showErrorIcon: false,
                  ),
              ],
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.6, 1],
                colors: [Color(0x99000000), Color(0x00000000), Color(0x330E1014), AppColors.bg],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 58,
          child: IgnorePointer(child: _TitleBlock(detail: d)),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final sm = detail.summary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sm.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
          ),
        ),
        if (sm.enName.isNotEmpty)
          Text(sm.enName, style: const TextStyle(color: AppColors.textDim, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(sm.rarity, color: AppColors.dollRarity(sm.rarityLevel), icon: Icons.star_rounded),
            Tag(sm.attr, color: AppColors.attr(sm.attrId), icon: Icons.blur_on_rounded),
            Tag(sm.role, color: AppColors.text, icon: roleIcon(sm.roleId)),
            Tag(sm.team, color: AppColors.textDim, icon: Icons.groups_2_outlined),
          ],
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 0.72,
          child: GestureDetector(
            onTap: () => ImageViewer.open(context, _portraitUrls(d), titles: _portraitTitles(d, context.s)),
            child: Hero(
              tag: 'doll-${d.summary.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (d.portrait.any.isEmpty)
                      AppImage(d.summary.pic, alignment: Alignment.topCenter, decodeWidth: 200)
                    else
                      AppImage(
                        d.portrait.any,
                        alignment: Alignment.topCenter,
                        decodeWidth: 380,
                        placeholderColor: Colors.transparent,
                        showErrorIcon: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TitleBlock(detail: d),
        const SizedBox(height: 16),
        _DollInfoGrid(detail: d),
      ],
    );
  }
}

class _DollInfoGrid extends StatelessWidget {
  const _DollInfoGrid({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = detail;
    final app = AppScope.of(context);
    final weapon = app.data.weaponByName(d.summary.weapon);
    final items = <(String, String)>[
      (s.t('f_role'), d.summary.role),
      (s.t('f_rarity'), d.summary.rarity),
      (s.t('f_weapon'), d.summary.weapon),
      (s.t('f_model'), d.model),
      (s.t('f_attr'), d.summary.attr),
      (s.t('f_ammo'), d.ammoModel),
      (s.t('f_team'), d.summary.team),
    ];
    return InfoGrid(
      items: items,
      onTap: (i) {
        if (i == 2 && weapon != null) WeaponDetailPage.open(context, weapon.id);
      },
    );
  }
}

// ---------------------------------------------------------------- tabs

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.detail, required this.includeInfo});

  final DollDetail detail;
  final bool includeInfo;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = detail;
    final scale = AppScope.of(context).textScale;
    final portraits = _portraitUrls(d);
    final modeling = [d.modeling.mobile, d.modeling.pc].where((u) => u.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeInfo) ...[_DollInfoGrid(detail: d), const _Gap()],
        if (d.desc.isNotEmpty) ...[
          AppCard(
            child: Text(
              d.desc,
              style: TextStyle(fontSize: 14.5 * scale, height: 1.65, color: AppColors.text),
            ),
          ),
          const _Gap(),
        ],
        if (portraits.isNotEmpty) ...[
          SectionCard(
            title: s.t('portrait'),
            builder: (_) => ImageStrip(urls: portraits, titles: _portraitTitles(d, s), height: 240),
          ),
          const _Gap(),
        ],
        if (modeling.isNotEmpty) ...[
          SectionCard(
            title: s.t('modeling'),
            initiallyExpanded: false,
            builder: (_) => ImageStrip(urls: modeling, height: 240),
          ),
          const _Gap(),
        ],
        HtmlSection(title: s.t('other_info'), html: d.cv),
        const _Gap(),
        HtmlSection(title: s.t('base_stats'), html: colorizeAttrHtml(d.prop)),
        const _Gap(),
        SectionCard(
          title: s.t('skills'),
          isEmpty: d.skills.isEmpty,
          builder: (_) => NamedHtmlSwitcher(items: d.skills, iconCells: true),
        ),
        if (d.gifs.isNotEmpty) ...[
          const _Gap(),
          SectionCard(
            title: s.t('gifs'),
            initiallyExpanded: false,
            builder: (_) => ImageStrip(urls: d.gifs, height: 180, aspect: 1.5),
          ),
        ],
      ],
    );
  }
}

class _GrowthTab extends StatelessWidget {
  const _GrowthTab({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = detail;
    final weapon = AppScope.of(context).data.weaponByName(d.summary.weapon);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HtmlSection(title: s.t('battle_skill'), html: d.battleSkill),
        const _Gap(),
        SectionCard(
          title: s.t('talents'),
          isEmpty: d.talents.isEmpty,
          builder: (_) => NamedHtmlSwitcher(items: d.talents, iconCells: true),
        ),
        const _Gap(),
        HtmlSection(title: s.t('remoulding'), html: d.remoulding),
        const _Gap(),
        SectionCard(
          title: s.t('weapon_desc'),
          isEmpty: d.weaponDesc.trim().isEmpty,
          trailing: weapon == null
              ? null
              : TextButton.icon(
                  onPressed: () => WeaponDetailPage.open(context, weapon.id),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(s.t('view_weapon')),
                ),
          builder: (_) => HtmlContent(d.weaponDesc),
        ),
        const _Gap(),
        HtmlSection(title: s.t('development'), html: d.development),
      ],
    );
  }
}

class _ArchiveTab extends StatelessWidget {
  const _ArchiveTab({required this.detail});

  final DollDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HtmlSection(title: s.t('story'), html: d.story),
        const _Gap(),
        SectionCard(
          title: s.t('gifts'),
          isEmpty: d.gifts.isEmpty,
          builder: (_) => NamedHtmlSwitcher(items: d.gifts),
        ),
        const _Gap(),
        SectionCard(
          title: s.t('gallery'),
          isEmpty: d.gallery.isEmpty,
          builder: (_) => NamedHtmlSwitcher(items: d.gallery),
        ),
      ],
    );
  }
}

class _VoiceTab extends StatefulWidget {
  const _VoiceTab({required this.detail});

  final DollDetail detail;

  @override
  State<_VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<_VoiceTab> {
  int _group = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final d = widget.detail;
    final groups = <(String, List<Voice>)>[
      (s.t('voice_daily'), d.voices),
      (s.t('voice_battle'), d.battleVoices),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(message: s.t('no_data'), icon: Icons.mic_off_outlined),
      );
    }
    final g = _group.clamp(0, groups.length - 1).toInt();
    final voices = groups[g].$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < groups.length; i++)
                  ButtonSegment<int>(value: i, label: Text('${groups[i].$1} (${groups[i].$2.length})')),
              ],
              selected: {g},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                VoicePlayer.instance.stop();
                setState(() => _group = v.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.2),
                selectedForegroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final v in voices) ...[
          VoiceTile(voice: v),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
