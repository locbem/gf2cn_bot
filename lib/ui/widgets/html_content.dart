import 'dart:math' as math;

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
///
/// Bảng "dàn trang" của wiki (không viền: ô icon + ô chữ + ô ảnh...) vốn thiết kế
/// cho màn hình rộng; trên điện thoại sẽ được xếp lại theo chiều dọc. Bảng chỉ gồm
/// các ô "ảnh + tên" (vd quà tặng) được dựng thành lưới đều nhau.
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

  /// Bề rộng màn hình dưới mức này thì xếp lại bảng dàn trang theo chiều dọc.
  static const double narrowWidth = 600;

  /// Link "xem đồ giám" đặt ngay sau tên vũ khí → xuống dòng riêng.
  static final RegExp _viewLink = RegExp(r'\s*(<a [^>]*>(?:<[^>]+>)*\s*(?:查看武器图鉴|Xem đồ giám vũ khí))');

  /// Chuỗi dài khoảng trắng / &nbsp; (wiki dùng để căn chữ) → một khoảng trắng.
  static final RegExp _spaceRun = RegExp(r'(?:&nbsp;|\xa0|[ \t]){3,}');

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

  /// Dựng lại nội dung HTML con (ô bảng) với cùng cỡ chữ.
  Widget _child(String html) => HtmlContent(
        html,
        videoCover: videoCover,
        baseFontSize: baseFontSize,
        lineHeight: lineHeight,
      );

  Widget? _adaptTable(dom.Element table, bool narrow) {
    // Chỉ xử lý bảng ngoài cùng, không viền (bảng dữ liệu có viền giữ nguyên).
    if (table.attributes['border'] == '1' || _ancestor(table, 'table') != null) return null;
    final rows = _TableParts.rows(table);
    if (rows.isEmpty) return null;
    final items = _TableParts.gridItems(rows);
    if (items != null) return _ItemGrid(items: items);
    final multiColumn = rows.any((r) => r.where(_TableParts.hasContent).length >= 2);
    if (!multiColumn) return null;
    final side = _TableParts.sideImage(rows);
    // Màn hình rộng: chỉ dựng lại bảng có ảnh lớn chiếm nhiều hàng (ảnh phạm vi kỹ năng,
    // ảnh vũ khí) để ảnh luôn cùng một cỡ; bảng khác giữ nguyên.
    if (!narrow && side == null) return null;
    return _StackedTable(rows: rows, render: _child, side: side, narrow: narrow);
  }

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return renderMode == RenderMode.sliverList
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }
    final scale = AppScope.of(context).textScale;
    final narrow = MediaQuery.sizeOf(context).width < narrowWidth;
    return HtmlWidget(
      html.replaceAll(_spaceRun, ' ').replaceAllMapped(_viewLink, (m) => '<br>${m.group(1)}'),
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
        switch (element.localName) {
          case 'iframe':
            return VideoCard(src: element.attributes['src'] ?? '', cover: videoCover);
          case 'table':
            return _adaptTable(element, narrow);
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

/// Một ô "ảnh + tên" trong bảng lưới (quà tặng...).
class _GridItem {
  const _GridItem(this.src, this.label);
  final String src;
  final String label;
}

/// Tách bảng HTML thành hàng/ô và nhận diện kiểu bảng.
class _TableParts {
  _TableParts._();

  static final RegExp _maxWidth = RegExp(r'max-width:\s*(\d+)');
  static final RegExp _emptyBlock =
      RegExp(r'<(p|div|span)[^>]*>(?:\s|&nbsp;|\xa0|<br\s*/?>)*</\1>', caseSensitive: false);
  static final RegExp _edgeBreaks = RegExp(r'^(?:\s|<br\s*/?>)+|(?:\s|<br\s*/?>)+$', caseSensitive: false);

  static String norm(String s) => s.replaceAll('\xa0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Các hàng của chính bảng này (bỏ qua hàng của bảng lồng bên trong).
  static List<List<dom.Element>> rows(dom.Element table) {
    final out = <List<dom.Element>>[];
    for (final tr in table.querySelectorAll('tr')) {
      if (HtmlContent._ancestor(tr, 'table') != table) continue;
      out.add([
        for (final c in tr.children)
          if (c.localName == 'td' || c.localName == 'th') c,
      ]);
    }
    return out;
  }

  static bool hasContent(dom.Element cell) =>
      norm(cell.text).isNotEmpty || cell.querySelector('img, iframe, video, table, hr') != null;

  /// Bảng mà mọi ô có nội dung đều là "1 ảnh + tên ngắn" → danh sách mục, ngược lại null.
  static List<_GridItem>? gridItems(List<List<dom.Element>> rows) {
    final items = <_GridItem>[];
    for (final row in rows) {
      for (final cell in row) {
        if (!hasContent(cell)) continue;
        final imgs = cell.querySelectorAll('img');
        final text = norm(cell.text);
        if (imgs.length != 1 || text.isEmpty || text.length > 24) return null;
        if (cell.querySelector('table') != null) return null;
        final src = imgs.first.attributes['src'] ?? '';
        if (src.isEmpty) return null;
        items.add(_GridItem(src, text));
      }
    }
    return items.length >= 3 ? items : null;
  }

  /// Ô chỉ có một ảnh nhỏ (icon kỹ năng, icon khoá...) → url ảnh, ngược lại null.
  static String? iconOnly(dom.Element cell) {
    if (norm(cell.text).isNotEmpty) return null;
    final imgs = cell.querySelectorAll('img');
    if (imgs.length != 1) return null;
    final img = imgs.first;
    final src = img.attributes['src'] ?? '';
    if (src.isEmpty) return null;
    final w = double.tryParse(img.attributes['width'] ?? '') ??
        double.tryParse(_maxWidth.firstMatch(img.attributes['style'] ?? '')?.group(1) ?? '');
    if (w == null || w > 160) return null;
    return src;
  }

  /// Ô ảnh lớn chiếm nhiều hàng (rowspan) → ô đó, ngược lại null.
  static dom.Element? sideImage(List<List<dom.Element>> rows) {
    for (final row in rows) {
      for (final cell in row) {
        final span = int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1;
        if (span < 2 || norm(cell.text).isNotEmpty) continue;
        if (cell.querySelectorAll('img').length != 1 || iconOnly(cell) != null) continue;
        return cell;
      }
    }
    return null;
  }

  static String imageSrc(dom.Element cell) => cell.querySelector('img')?.attributes['src'] ?? '';

  /// HTML của một ô, giữ lại style (căn lề, màu) của ô.
  static String cellHtml(dom.Element cell) {
    final style = cell.attributes['style'];
    // Bỏ đoạn rỗng / <br> thừa (wiki dùng để tạo khoảng cách) → không còn khoảng trống lớn.
    final inner = cell.innerHtml.replaceAll(_emptyBlock, '').replaceAll(_edgeBreaks, '').trim();
    return (style == null || style.isEmpty) ? inner : '<div style="$style">$inner</div>';
  }
}

/// Lưới "ảnh + tên" đều nhau, tên tối đa 2 dòng (thay cho bảng quà tặng của wiki).
class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items});

  final List<_GridItem> items;

  @override
  Widget build(BuildContext context) {
    final scale = AppScope.of(context).textScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        const gap = 8.0;
        final columns = math.max(3, (width / 96).floor());
        final itemWidth = math.max(48.0, (width - gap * (columns - 1)) / columns);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: gap,
            runSpacing: 14,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => ImageViewer.open(context, [item.src]),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Image(
                            image: appImageProvider(item.src, decodeWidth: 192),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5 * scale, height: 1.3, color: AppColors.text),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bảng dàn trang xếp dọc cho màn hình hẹp: ô icon + ô chữ đầu tiên của mỗi hàng
/// đặt cạnh nhau, các ô còn lại xếp lần lượt bên dưới.
class _StackedTable extends StatelessWidget {
  const _StackedTable({required this.rows, required this.render, this.side, this.narrow = true});

  final List<List<dom.Element>> rows;
  final Widget Function(String html) render;

  /// Ô ảnh lớn (ảnh phạm vi kỹ năng / ảnh vũ khí), luôn hiển thị cùng một cỡ.
  final dom.Element? side;
  final bool narrow;

  static const double sideWidth = 220;

  Widget _sideImage(BuildContext context, String src) => GestureDetector(
        onTap: () => ImageViewer.open(context, [src]),
        child: SizedBox(
          width: sideWidth,
          child: Image(
            image: appImageProvider(src, decodeWidth: 660),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final sideCell = side;
    var sideLeft = false;
    for (final row in rows) {
      final all = row.where(_TableParts.hasContent).toList();
      if (sideCell != null && all.contains(sideCell)) {
        sideLeft = all.first == sideCell;
        if (narrow) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(child: _sideImage(context, _TableParts.imageSrc(sideCell))),
          ));
        }
      }
      final cells = all.where((c) => c != sideCell).toList();
      var i = 0;
      if (cells.length >= 2) {
        final icon = _TableParts.iconOnly(cells[0]);
        if (icon != null) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Image(
                    image: appImageProvider(icon, decodeWidth: 168),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: render(_TableParts.cellHtml(cells[1]))),
              ],
            ),
          ));
          i = 2;
        }
      }
      for (; i < cells.length; i++) {
        children.add(render(_TableParts.cellHtml(cells[i])));
      }
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (narrow || sideCell == null) return column;
    final image = _sideImage(context, _TableParts.imageSrc(sideCell));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sideLeft) ...[image, const SizedBox(width: 16)],
        Expanded(child: column),
        if (!sideLeft) ...[const SizedBox(width: 16), image],
      ],
    );
  }
}
