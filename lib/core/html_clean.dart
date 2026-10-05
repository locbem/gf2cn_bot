import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Làm sạch HTML lấy từ wiki (vốn copy từ Word, rất nhiều style rác)
/// để: (1) file JSON gọn, dễ dịch; (2) render native mượt hơn.
///
/// Giữ lại: cấu trúc (p, table, h1..., img, iframe, a), màu chữ nổi bật,
/// căn lề, đậm/nghiêng. Bỏ: font, kích thước, mso-*, width/height, class...
class HtmlCleaner {
  HtmlCleaner._();

  static const Set<String> _keepStyle = {
    'color',
    'text-align',
    'font-weight',
    'font-style',
    'text-decoration',
  };

  static const Set<String> _dropTags = {
    'colgroup',
    'col',
    'script',
    'style',
    'meta',
    'link',
    'title',
    'xml',
    'button',
    'input',
    'form',
  };

  static const Set<String> _unwrapIfBare = {'span', 'font', 'div'};

  static final RegExp _multiNewline = RegExp(r'\n{2,}');
  static final RegExp _splitTags = RegExp(r'</(strong|b|em|i|u)>(\s*)<\1>');
  static final RegExp _numberOnly = RegExp(r'[^0-9.]');

  /// Trả về HTML đã làm sạch, hoặc chuỗi rỗng nếu không còn nội dung.
  static String clean(Object? input) {
    if (input is! String) return '';
    // `<strong>生</strong><strong>命：</strong>` → `<strong>生命：</strong>` để chữ liền một cụm.
    final src = input.trim().replaceAllMapped(_splitTags, (m) => m.group(2)!);
    if (src.isEmpty) return '';
    // Nội dung thuần text (không có thẻ) thì giữ nguyên, chỉ đổi xuống dòng.
    if (!src.contains('<')) {
      return src
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .map((l) => '<p>${_escape(l.trim())}</p>')
          .join('\n');
    }
    final fragment = html_parser.parseFragment(src);
    final container = dom.Element.tag('div');
    for (final node in fragment.nodes.toList()) {
      container.append(node);
    }
    _walk(container);
    final out = container.innerHtml.replaceAll(_multiNewline, '\n').trim();
    return _hasMeaningfulContent(container) ? out : '';
  }

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static void _walk(dom.Node node) {
    for (final child in node.nodes.toList()) {
      if (child is dom.Comment) {
        child.remove();
        continue;
      }
      if (child is! dom.Element) continue;
      final tag = (child.localName ?? '').toLowerCase();
      if (_dropTags.contains(tag) || tag.contains(':')) {
        // Thẻ Office kiểu <o:p> – giữ lại chữ bên trong nếu có.
        if (tag.contains(':') && child.text.trim().isNotEmpty) {
          _walk(child);
          _unwrap(child);
        } else {
          child.remove();
        }
        continue;
      }
      _cleanAttributes(child, tag);
      _walk(child);
      if (_unwrapIfBare.contains(tag) && child.attributes.isEmpty) {
        // div chứa block con thì giữ để không gộp dòng; span/font thì bỏ.
        if (tag != 'div' || !_hasBlockChild(child)) {
          if (tag == 'div') {
            _replaceWithParagraph(child);
          } else {
            _unwrap(child);
          }
        }
        continue;
      }
      if ((tag == 'p' || tag == 'div' || tag == 'h1' || tag == 'h2' || tag == 'h3') &&
          !_hasMeaningfulContent(child)) {
        child.remove();
      }
    }
  }

  static bool _hasBlockChild(dom.Element el) {
    for (final c in el.children) {
      final t = (c.localName ?? '').toLowerCase();
      if (const {'p', 'div', 'table', 'h1', 'h2', 'h3', 'h4', 'ul', 'ol', 'hr', 'blockquote'}
          .contains(t)) {
        return true;
      }
    }
    return false;
  }

  static void _replaceWithParagraph(dom.Element div) {
    final p = dom.Element.tag('p');
    for (final n in div.nodes.toList()) {
      p.append(n);
    }
    div.replaceWith(p);
    if (!_hasMeaningfulContent(p)) p.remove();
  }

  static void _unwrap(dom.Element el) {
    final parent = el.parentNode;
    if (parent == null) {
      el.remove();
      return;
    }
    for (final n in el.nodes.toList()) {
      parent.insertBefore(n, el);
    }
    el.remove();
  }

  /// Có chữ (khác khoảng trắng/&nbsp;) hoặc có media/table/hr.
  static bool _hasMeaningfulContent(dom.Element el) {
    if (el.text.replaceAll('\u00a0', ' ').trim().isNotEmpty) return true;
    return _hasMedia(el);
  }

  static bool _hasMedia(dom.Element el) {
    for (final c in el.children) {
      final t = (c.localName ?? '').toLowerCase();
      if (t == 'img' || t == 'iframe' || t == 'video' || t == 'table' || t == 'hr') {
        return true;
      }
      if (_hasMedia(c)) return true;
    }
    return false;
  }

  static void _cleanAttributes(dom.Element el, String tag) {
    final old = Map<Object, String>.from(el.attributes);
    el.attributes.clear();
    old.forEach((key, value) {
      final name = key.toString().toLowerCase();
      final v = value.trim();
      switch (name) {
        case 'style':
          var s = _cleanStyle(v);
          // Ảnh căn giữa kiểu "display:block; margin: auto" → giữ lại việc căn giữa.
          final lv = v.toLowerCase().replaceAll(' ', '');
          if (tag == 'img' && lv.contains('margin-left:auto') && lv.contains('margin-right:auto')) {
            s = [if (s.isNotEmpty) s, 'display: block', 'margin: 0 auto'].join('; ');
          }
          if (s.isNotEmpty) el.attributes['style'] = s;
        case 'src':
          if (const {'img', 'iframe', 'video', 'source', 'audio', 'embed'}.contains(tag) &&
              v.isNotEmpty) {
            el.attributes['src'] = absoluteUrl(v);
          }
        case 'href':
          if (tag == 'a' && v.isNotEmpty) el.attributes['href'] = absoluteUrl(v);
        case 'colspan':
        case 'rowspan':
          if (v.isNotEmpty && v != '1') el.attributes[name] = v;
        case 'width':
        case 'height':
          if (tag == 'img') el.attributes[name] = v;
        case 'border':
          if (tag == 'table' && v.isNotEmpty && v != '0') el.attributes['border'] = '1';
        case 'alt':
          if (tag == 'img' && v.isNotEmpty) el.attributes['alt'] = v;
        default:
          break;
      }
    });
    if (tag == 'img') _fixImageSize(el);
  }

  /// Ảnh nhỏ (icon) giữ kích thước để hiển thị inline; ảnh lớn bỏ
  /// kích thước để tự co theo màn hình.
  static void _fixImageSize(dom.Element img) {
    final w = double.tryParse((img.attributes['width'] ?? '').replaceAll(_numberOnly, ''));
    final h = double.tryParse((img.attributes['height'] ?? '').replaceAll(_numberOnly, ''));
    img.attributes.remove('width');
    img.attributes.remove('height');
    if (w == null) return;
    if (w <= 48 && (h == null || h <= 48)) {
      // Icon nằm trong dòng chữ: giữ kích thước cố định.
      img.attributes['width'] = w.round().toString();
      if (h != null) img.attributes['height'] = h.round().toString();
    } else if (w <= 160) {
      // Ảnh vừa (quà tặng, icon kỹ năng...): cho phép co lại trong ô bảng hẹp.
      final st = img.attributes['style'];
      img.attributes['style'] = [
        if (st != null && st.isNotEmpty) st,
        'max-width: ${w.round()}px',
      ].join('; ');
    }
  }

  static String _cleanStyle(String style) {
    final out = <String>[];
    for (final decl in style.split(';')) {
      final idx = decl.indexOf(':');
      if (idx <= 0) continue;
      final prop = decl.substring(0, idx).trim().toLowerCase();
      var val = decl.substring(idx + 1).replaceAll('!important', '').trim();
      if (val.isEmpty || !_keepStyle.contains(prop)) continue;
      final lv = val.toLowerCase();
      switch (prop) {
        case 'color':
          final c = _parseColor(lv);
          if (c == null) continue;
          // Bỏ trắng (mặc định của theme tối) và màu quá tối (không đọc được).
          if (_luminance(c) > 0.92 || _luminance(c) < 0.10) continue;
          val = _hex(c);
        case 'text-align':
          if (lv != 'center' && lv != 'right') continue;
          val = lv;
        case 'font-weight':
          if (lv == 'normal' || lv == '400' || lv == 'inherit') continue;
          val = 'bold';
        case 'font-style':
          if (lv != 'italic') continue;
          val = lv;
        case 'text-decoration':
          if (!lv.contains('underline') && !lv.contains('line-through')) continue;
          val = lv.contains('underline') ? 'underline' : 'line-through';
      }
      out.add('$prop: $val');
    }
    return out.join('; ');
  }

  static List<int>? _parseColor(String v) {
    if (v.startsWith('#')) {
      var hex = v.substring(1);
      if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
      if (hex.length != 6) return null;
      final n = int.tryParse(hex, radix: 16);
      if (n == null) return null;
      return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
    }
    final m = RegExp(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(v);
    if (m != null) {
      return [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)];
    }
    const named = {
      'white': [255, 255, 255],
      'black': [0, 0, 0],
      'red': [255, 0, 0],
      'orange': [255, 165, 0],
      'yellow': [255, 255, 0],
      'gold': [255, 215, 0],
      'green': [0, 128, 0],
      'blue': [0, 0, 255],
      'purple': [128, 0, 128],
      'gray': [128, 128, 128],
      'grey': [128, 128, 128],
      'windowtext': [0, 0, 0],
    };
    return named[v];
  }

  static double _luminance(List<int> c) =>
      (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255.0;

  static String _hex(List<int> c) =>
      '#${c.map((x) => x.clamp(0, 255).toInt().toRadixString(16).padLeft(2, '0')).join()}';

  /// Chuẩn hoá URL: `//host/x` → `https://host/x`, `http://` → `https://`.
  static String absoluteUrl(String url) {
    var u = url.trim().replaceAll('&amp;', '&');
    if (u.startsWith('//')) u = 'https:$u';
    if (u.startsWith('http://')) u = 'https://${u.substring(7)}';
    if (u.startsWith('/') && !u.startsWith('//')) u = 'https://gf2-bbs.exiliumgf.com$u';
    return u;
  }
}
