import 'package:flutter/material.dart';

import '../../data/bilibili.dart';
import '../../state/app_controller.dart';
import '../links.dart';
import '../screens/video_player_page.dart';
import '../theme.dart';
import 'cached_image.dart';

/// Thẻ video thay cho iframe: hiện ảnh bìa, chạm để phát ngay trong app
/// (trình phát native, không WebView). Link không phải Bilibili thì mở ngoài.
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.src, this.cover = ''});

  final String src;
  final String cover;

  static final RegExp _bvid = RegExp(r'bvid=([A-Za-z0-9]+)');
  static final RegExp _aid = RegExp(r'aid=(\d+)');

  /// Đổi link player nhúng sang link trang video.
  static String watchUrl(String src) {
    final bv = _bvid.firstMatch(src)?.group(1);
    if (bv != null) return 'https://www.bilibili.com/video/$bv';
    final aid = _aid.firstMatch(src)?.group(1);
    if (aid != null && src.contains('bilibili')) return 'https://www.bilibili.com/video/av$aid';
    if (src.startsWith('//')) return 'https:$src';
    return src;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final url = watchUrl(src);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: url.isEmpty
              ? null
              : () => BilibiliResolver.canHandle(src)
                  ? VideoPlayerPage.open(context, src)
                  : openExternal(context, url),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover.isNotEmpty) AppImage(cover, decodeWidth: 720),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0xAA000000)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Row(
                    children: [
                      Icon(
                        BilibiliResolver.canHandle(src) ? Icons.smart_display_rounded : Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.t('watch_video'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
