import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'cached_image.dart';

/// Xem ảnh toàn màn hình: vuốt qua lại, chụm/nhấp đúp để phóng to.
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.urls, this.initialIndex = 0, this.titles});

  final List<String> urls;
  final int initialIndex;
  final List<String>? titles;

  static Future<void> open(BuildContext context, List<String> urls,
      {int index = 0, List<String>? titles}) {
    final list = urls.where((u) => u.isNotEmpty).toList();
    if (list.isEmpty) return Future.value();
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => ImageViewer(
        urls: list,
        initialIndex: index.clamp(0, list.length - 1).toInt(),
        titles: titles,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.urls.length - 1).toInt();
    _page.animateToPage(next, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.titles != null && _index < widget.titles!.length ? widget.titles![_index] : '';
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: _page,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _ZoomableImage(
                  url: widget.urls[i],
                  onZoomChanged: (z) {
                    if (z != _zoomed) setState(() => _zoomed = z);
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (widget.urls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_index + 1} / ${widget.urls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _tween;
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_tween != null) _tc.value = _tween!.value;
    });
    _tc.addListener(() => widget.onZoomChanged(_tc.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final zoomed = _tc.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 target;
    if (zoomed) {
      target = Matrix4.identity();
    } else {
      final pos = _doubleTap?.localPosition ?? Offset.zero;
      const scale = 2.5;
      target = Matrix4.identity()
        ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
        ..scale(scale);
    }
    _tween = Matrix4Tween(begin: _tc.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTap = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
          child: AppImage(
            widget.url,
            fit: BoxFit.contain,
            decodeWidth: width * 2,
            placeholderColor: Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Dải ảnh ngang (立绘, skin...) – chạm để xem toàn màn hình.
class ImageStrip extends StatelessWidget {
  const ImageStrip({super.key, required this.urls, this.titles, this.height = 220, this.aspect = 0.62});

  final List<String> urls;
  final List<String>? titles;
  final double height;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final list = urls.where((u) => u.isNotEmpty).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final w = height * aspect;
          final title = titles != null && i < titles!.length ? titles![i] : '';
          return SizedBox(
            width: w,
            child: Material(
              color: AppColors.cardHigh,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ImageViewer.open(context, list, index: i, titles: titles),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(list[i], fit: BoxFit.cover, alignment: Alignment.topCenter, decodeWidth: w),
                    if (title.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
