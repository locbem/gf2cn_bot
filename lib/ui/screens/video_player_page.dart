import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/bilibili.dart';
import '../../state/app_controller.dart';
import '../links.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/video_card.dart';

/// Phát PV ngay trong app bằng trình phát native (media_kit / libmpv),
/// không dùng WebView. Video phát trực tiếp (stream), không lưu xuống máy.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.src, this.title = ''});

  /// Link player nhúng của Bilibili (src của iframe).
  final String src;
  final String title;

  static Future<void> open(BuildContext context, String src, {String title = ''}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VideoPlayerPage(src: src, title: title)),
      );

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<String>? _errorSub;
  BiliStream? _stream;
  int _urlIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _errorSub = _player.stream.error.listen(_onPlayerError);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stream = await BilibiliResolver.resolve(widget.src);
      if (!mounted) return;
      _stream = stream;
      _urlIndex = 0;
      await _openCurrent();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openCurrent() async {
    final s = _stream;
    if (s == null) return;
    await _player.open(Media(s.urls[_urlIndex], httpHeaders: s.headers));
  }

  /// Lỗi khi phát (CDN chặn/hết hạn…): thử link dự phòng, hết thì báo lỗi.
  void _onPlayerError(String message) {
    final s = _stream;
    if (!mounted || s == null || _loading) return;
    if (_urlIndex + 1 < s.urls.length) {
      _urlIndex++;
      _openCurrent();
    } else {
      setState(() => _error = message);
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final title = (_stream?.title.isNotEmpty ?? false) ? _stream!.title : widget.title;
    final external = VideoCard.watchUrl(widget.src);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.t('open_bilibili'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openExternal(context, external),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // Khung 16:9 vừa với màn hình (dọc lẫn ngang).
            var w = c.maxWidth;
            var h = w * 9 / 16;
            if (h > c.maxHeight - 80) {
              h = c.maxHeight - 80;
              if (h < 100) h = c.maxHeight * 0.8;
              w = h * 16 / 9;
            }
            return Column(
              children: [
                const Spacer(),
                Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: _error != null
                        ? _ErrorBox(
                            message: _error!,
                            onRetry: _load,
                            onExternal: () => openExternal(context, external),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Video(controller: _controller),
                              if (_loading)
                                ColoredBox(
                                  color: Colors.black,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(s.t('video_loading'), style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_stream != null && _stream!.quality.isNotEmpty)
                  Tag(_stream!.quality, color: AppColors.textDim, icon: Icons.hd_outlined),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry, required this.onExternal});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onExternal;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.textDim, size: 36),
              const SizedBox(height: 10),
              Text(s.t('video_error'), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(s.t('retry')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExternal,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(s.t('open_bilibili')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
