import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

import '../../state/app_controller.dart';
import '../links.dart';
import '../theme.dart';
import 'cached_image.dart';
import 'image_viewer.dart';
import 'video_card.dart';

/// WidgetFactory dùng bộ đệm ảnh offline của app thay cho NetworkImage.
class _OfflineWidgetFactory extends WidgetFactory {
  @override
  ImageProvider? imageProviderFromNetwork(String url) {
    if (url.isEmpty) return null;
    return appImageProvider(url, decodeWidth: 1600);
  }
}

/// Hiển thị nội dung HTML của wiki bằng widget native (không dùng WebView).
class HtmlContent extends StatelessWidget {
  const HtmlContent(
    this.html, {
    super.key,
    this.renderMode = RenderMode.column,
    this.videoCover = '',
    this.baseFontSize = 15,
    this.lineHeight = 1.6,
    this.buildAsync,
  });

  final String html;
  final RenderMode renderMode;

  /// Ảnh bìa dùng cho thẻ video (iframe bilibili).
  final String videoCover;
  final double baseFontSize;
  final double lineHeight;

  /// null = để thư viện tự quyết (nội dung dài sẽ dựng bất đồng bộ).
  /// Với [RenderMode.sliverList] nên đặt false.
  final bool? buildAsync;

  static const String _lineColor = '#3A424F';

  static dom.Element? _ancestor(dom.Element el, String tag) {
    var e = el.parent;
    while (e != null) {
      if (e.localName == tag) return e;
      e = e.parent;
    }
    return null;
  }

  static Map<String, String>? _styles(dom.Element element) {
    switch (element.localName) {
      case 'table':
        final bordered = element.attributes['border'] == '1';
        return {
          'border-collapse': 'collapse',
          if (bordered) 'border': '1px solid $_lineColor',
          'margin': '0.2em 0 0.8em 0',
        };
      case 'td':
      case 'th':
        final table = _ancestor(element, 'table');
        final bordered = table?.attributes['border'] == '1';
        return {
          'padding': '6px 8px',
          'vertical-align': 'middle',
          if (bordered) 'border': '1px solid $_lineColor',
        };
      case 'p':
        final inCell = _ancestor(element, 'td') != null;
        return {'margin': inCell ? '0.15em 0' : '0 0 0.7em 0'};
      case 'h1':
        return {'font-size': '1.3em', 'margin': '0.3em 0 0.5em 0'};
      case 'h2':
        return {'font-size': '1.15em', 'margin': '0.3em 0 0.4em 0'};
      case 'h3':
      case 'h4':
        return {'font-size': '1.05em', 'margin': '0.3em 0'};
      case 'a':
        return {'color': '#F26C1C', 'text-decoration': 'none'};
      case 'hr':
        return {'margin': '0.5em 0'};
      case 'sub':
      case 'sup':
        // Icon nhỏ được bọc trong <sub>: căn giữa dòng thay vì hạ xuống.
        return {'vertical-align': 'middle', 'font-size': '1em'};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return renderMode == RenderMode.sliverList
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }
    final scale = AppScope.of(context).textScale;
    return HtmlWidget(
      html,
      renderMode: renderMode,
      buildAsync: buildAsync,
      textStyle: TextStyle(
        fontSize: baseFontSize * scale,
        height: lineHeight,
        color: AppColors.text,
      ),
      factoryBuilder: () => _OfflineWidgetFactory(),
      customStylesBuilder: _styles,
      customWidgetBuilder: (element) {
        if (element.localName == 'iframe') {
          return VideoCard(src: element.attributes['src'] ?? '', cover: videoCover);
        }
        return null;
      },
      onTapUrl: (url) {
        openLink(context, url);
        return true;
      },
      onTapImage: (meta) {
        final urls = [for (final s in meta.sources) s.url].where((u) => u.isNotEmpty).toList();
        if (urls.isNotEmpty) ImageViewer.open(context, [urls.first]);
      },
      onErrorBuilder: (context, element, error) => const SizedBox.shrink(),
      onLoadingBuilder: (context, element, progress) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
