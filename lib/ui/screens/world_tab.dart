import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../widgets/common.dart';
import '../widgets/cover_card.dart';
import 'story_reader_page.dart';

/// Tab trong "Thiết lập thế giới" (追放剧情 / 其他设定): danh sách bài.
class WorldTab extends StatefulWidget {
  const WorldTab({super.key, required this.cid});

  final int cid;

  @override
  State<WorldTab> createState() => _WorldTabState();
}

class _WorldTabState extends State<WorldTab> {
  int get cid => widget.cid;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final items = app.data.worldOf(cid);
    if (items.isEmpty) return EmptyState(message: s.t('no_data'));
    return CustomScrollView(
      key: PageStorageKey<String>('world-$cid'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          sliver: CoverGrid(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final w = items[i];
              final read = app.readingChapter(w.id);
              var subtitle = s.t('chapters_count', {'n': w.chapters.length});
              if (read != null && read < w.chapters.length) {
                subtitle = '$subtitle  ·  ${s.t('continue_reading', {'name': w.chapters[read]})}';
              }
              return CoverCard(
                title: w.title,
                cover: w.cover,
                subtitle: subtitle,
                icon: Icons.auto_stories_outlined,
                onTap: () async {
                  await StoryReaderPage.open(context, w.id);
                  if (mounted) setState(() {}); // cập nhật "Đọc tiếp"
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
