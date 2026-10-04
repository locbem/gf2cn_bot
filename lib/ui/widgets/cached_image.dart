import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/file_cache.dart';
import '../theme.dart';

/// ImageProvider đọc ảnh từ bộ đệm trên đĩa; nếu chưa có thì tải về,
/// lưu lại rồi mới giải mã → lần sau mở offline được, không tải lại.
@immutable
class CachedNetImage extends ImageProvider<CachedNetImage> {
  const CachedNetImage(this.url);

  final String url;

  @override
  Future<CachedNetImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CachedNetImage>(this);

  @override
  ImageStreamCompleter loadImage(CachedNetImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('URL', key.url),
      ],
    );
  }

  Future<ui.Codec> _load(CachedNetImage key, ImageDecoderCallback decode) async {
    try {
      final file = await imageFiles.ensure(key.url);
      if (file == null) throw StateError('Không tải được ảnh: ${key.url}');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('Ảnh rỗng: ${key.url}');
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (e) {
      // Cho phép thử lại ở lần hiển thị sau.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is CachedNetImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedNetImage("$url")';
}

/// Tạo provider có giới hạn kích thước giải mã (tiết kiệm RAM, cuộn mượt).
ImageProvider appImageProvider(String url, {int? decodeWidth}) {
  final base = CachedNetImage(url);
  if (decodeWidth == null || decodeWidth <= 0) return base;
  return ResizeImage(base, width: decodeWidth, policy: ResizeImagePolicy.fit, allowUpscaling: false);
}

/// Ảnh có placeholder, fade-in, xử lý lỗi, dùng bộ đệm offline.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.decodeWidth,
    this.borderRadius,
    this.placeholderColor = AppColors.cardHigh,
    this.showErrorIcon = true,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  /// Chiều rộng logic để giải mã ảnh (sẽ nhân với devicePixelRatio).
  final double? decodeWidth;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final bool showErrorIcon;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (url.isEmpty) {
      child = _placeholder(icon: showErrorIcon ? Icons.image_not_supported_outlined : null);
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final dw = decodeWidth == null ? null : (decodeWidth! * dpr).round();
      child = Image(
        image: appImageProvider(url, decodeWidth: dw),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: ColoredBox(color: placeholderColor)),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stack) =>
            _placeholder(icon: showErrorIcon ? Icons.broken_image_outlined : null),
      );
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder({IconData? icon}) => Container(
        width: width,
        height: height,
        color: placeholderColor,
        alignment: Alignment.center,
        child: icon == null ? null : Icon(icon, color: AppColors.textFaint, size: 22),
      );
}
