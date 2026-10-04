import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../widgets/common.dart';
import '../widgets/cover_card.dart';
import 'media_detail_page.dart';

/// Tab trong "Tư liệu khác" (PV nhân vật, PV phiên bản, radio, hình nền).
class MediaTab extends StatelessWidget {
  const MediaTab({super.key, required this.cid});

  final int cid;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final items = app.data.mediaOf(cid);
    if (items.isEmpty) return EmptyState(message: s.t('no_data'));
    return CustomScrollView(
      key: PageStorageKey<String>('media-$cid'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          sliver: CoverGrid(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final isVideo = m.html.contains('<iframe');
              return CoverCard(
                title: m.title,
                cover: m.cover,
                icon: isVideo ? Icons.smart_display_outlined : Icons.photo_library_outlined,
                overlayIcon: isVideo ? Icons.play_arrow_rounded : null,
                onTap: () => MediaDetailPage.open(context, m.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
