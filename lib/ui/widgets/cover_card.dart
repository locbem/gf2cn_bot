import 'package:flutter/material.dart';

import '../theme.dart';
import 'cached_image.dart';

/// Thẻ có ảnh bìa 16:9 + tiêu đề (dùng cho cốt truyện, PV, hình nền...).
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.title,
    required this.cover,
    required this.onTap,
    this.subtitle = '',
    this.icon = Icons.article_outlined,
    this.overlayIcon,
  });

  final String title;
  final String cover;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;
  final IconData? overlayIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover.isNotEmpty)
                    AppImage(cover, decodeWidth: 480)
                  else
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A1A12), AppColors.cardHigh],
                        ),
                      ),
                      child: Icon(icon, size: 42, color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  if (overlayIcon != null)
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(overlayIcon, color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới thẻ bìa co giãn theo bề rộng màn hình (dạng sliver).
class CoverGrid extends StatelessWidget {
  const CoverGrid({super.key, required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final w = constraints.crossAxisExtent;
      final cols = w >= 1300 ? 4 : (w >= 900 ? 3 : (w >= 560 ? 2 : 1));
      if (cols == 1) {
        return SliverList.separated(
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
        );
      }
      return SliverMasonryLikeGrid(cols: cols, itemCount: itemCount, itemBuilder: itemBuilder);
    });
  }
}

/// Lưới nhiều cột đơn giản: mỗi hàng là một Row, dựng lười theo hàng.
class SliverMasonryLikeGrid extends StatelessWidget {
  const SliverMasonryLikeGrid({super.key, required this.cols, required this.itemCount, required this.itemBuilder});

  final int cols;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = (itemCount / cols).ceil();
    return SliverList.separated(
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, r) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < cols; c++) ...[
            if (c > 0) const SizedBox(width: 14),
            Expanded(
              child: r * cols + c < itemCount ? itemBuilder(context, r * cols + c) : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
