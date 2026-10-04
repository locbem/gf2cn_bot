import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/html_content.dart';

/// Trình đọc bài "Thiết lập thế giới": mục lục, chuyển chương, nhớ chỗ đang đọc.
class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({super.key, required this.id});

  final int id;

  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StoryReaderPage(id: id)));

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  Future<WorldDetail?>? _future;
  int _version = -1;
  int? _chapter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (app.dataVersion != _version) {
      _version = app.dataVersion;
      _future = app.data.worldDetail(widget.id);
      _chapter ??= app.readingChapter(widget.id) ?? 0;
    }
  }

  void _goTo(int index, int total) {
    final i = index.clamp(0, total - 1).toInt();
    if (i == _chapter) return;
    setState(() => _chapter = i);
    AppScope.read(context).setReadingChapter(widget.id, i);
  }

  Future<void> _showToc(WorldDetail d) async {
    final s = context.s;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(s.t('toc'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: _TocList(
                chapters: d.chapters,
                current: _chapter ?? 0,
                controller: controller,
                onTap: (i) => Navigator.of(context).pop(i),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _goTo(picked, d.chapters.length);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final summary = app.data.worldById(widget.id);
    return FutureBuilder<WorldDetail?>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) {
          return Scaffold(
            appBar: AppBar(title: Text(summary?.title ?? '')),
            body: snap.connectionState == ConnectionState.done
                ? EmptyState(message: s.t('error_load'), icon: Icons.error_outline)
                : const LoadingState(),
          );
        }
        if (d.chapters.isEmpty) {
          return Scaffold(appBar: AppBar(title: Text(d.title)), body: EmptyState(message: s.t('no_data')));
        }
        final total = d.chapters.length;
        final index = (_chapter ?? 0).clamp(0, total - 1).toInt();
        final wide = isWide(context);

        final reader = _ChapterView(
          key: ValueKey('chapter-$index-${app.dataVersion}'),
          story: d,
          index: index,
          onNext: index < total - 1 ? () => _goTo(index + 1, total) : null,
        );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goTo(index - 1, total),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => _goTo(index + 1, total),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                title: Text(d.title, overflow: TextOverflow.ellipsis),
                actions: [
                  if (!wide && total > 1)
                    IconButton(
                      tooltip: s.t('toc'),
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      onPressed: () => _showToc(d),
                    ),
                  const LangToggleButton(),
                  const SizedBox(width: 8),
                ],
              ),
              body: wide && total > 1
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: ColoredBox(
                            color: AppColors.surface,
                            child: _TocList(
                              chapters: d.chapters,
                              current: index,
                              onTap: (i) => _goTo(i, total),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: reader),
                      ],
                    )
                  : reader,
              bottomNavigationBar: total > 1
                  ? _ChapterNav(
                      index: index,
                      total: total,
                      onPrev: index > 0 ? () => _goTo(index - 1, total) : null,
                      onNext: index < total - 1 ? () => _goTo(index + 1, total) : null,
                      onToc: wide ? null : () => _showToc(d),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({super.key, required this.story, required this.index, this.onNext});

  final WorldDetail story;
  final int index;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double width) {
    final s = context.s;
    final ch = story.chapters[index];
    final showPartTitles = ch.parts.length > 1;
    const maxContent = 820.0;
    final basePad = width > 900 ? 40.0 : 18.0;
    final hPad = width - 2 * basePad > maxContent ? (width - maxContent) / 2 : basePad;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(story.title, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 4),
                Text(ch.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Container(width: 40, height: 3, color: AppColors.accent),
              ],
            ),
          ),
        ),
        for (final part in ch.parts) ...[
          if (showPartTitles || (part.name.isNotEmpty && part.name != ch.name))
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 10),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tag(part.name, color: AppColors.accentSoft),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: HtmlContent(
              part.html,
              renderMode: RenderMode.sliverList,
              buildAsync: false,
              baseFontSize: 15.5,
              lineHeight: 1.75,
            ),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 40),
          sliver: SliverToBoxAdapter(
            child: onNext == null
                ? const SizedBox.shrink()
                : Center(
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text('${s.t('next_chapter')}: ${story.chapters[index + 1].name}'),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ChapterNav extends StatelessWidget {
  const _ChapterNav({required this.index, required this.total, this.onPrev, this.onNext, this.onToc});

  final int index;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToc;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(s.t('prev_chapter')),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onToc,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        '${index + 1} / $total',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDim),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onNext,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(s.t('next_chapter')), const Icon(Icons.chevron_right_rounded)],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocList extends StatelessWidget {
  const _TocList({required this.chapters, required this.current, required this.onTap, this.controller});

  final List<WorldChapter> chapters;
  final int current;
  final ValueChanged<int> onTap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final active = i == current;
        return ListTile(
          dense: true,
          selected: active,
          selectedColor: AppColors.accent,
          selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
          leading: SizedBox(
            width: 28,
            child: Text(
              '${i + 1}',
              textAlign: TextAlign.right,
              style: TextStyle(color: active ? AppColors.accent : AppColors.textFaint, fontSize: 12.5),
            ),
          ),
          title: Text(
            chapters[i].name,
            style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 14),
          ),
          onTap: () => onTap(i),
        );
      },
    );
  }
}
