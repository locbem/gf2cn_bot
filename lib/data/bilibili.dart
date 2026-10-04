import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../core/net.dart';

/// Luồng video đã phân giải từ Bilibili (MP4 một file, phát trực tiếp – không lưu cache).
class BiliStream {
  const BiliStream({
    required this.urls,
    required this.title,
    required this.quality,
    required this.headers,
  });

  /// URL chính + các URL dự phòng (CDN khác).
  final List<String> urls;
  final String title;
  final String quality;
  final Map<String, String> headers;
}

/// Lấy link phát video từ link player nhúng của Bilibili
/// (`player.bilibili.com/player.html?bvid=...` trong nội dung wiki) bằng các
/// API công khai mà player HTML5 chính thức dùng (không cần đăng nhập):
///   1. /x/player/pagelist  → cid của video
///   2. /x/player/playurl (platform=html5) → file MP4 (720p/360p)
class BilibiliResolver {
  BilibiliResolver._();

  static const Map<String, String> headers = {
    'User-Agent': AppConfig.userAgent,
    'Referer': 'https://www.bilibili.com/',
    'Origin': 'https://www.bilibili.com',
  };

  static final RegExp _bvid = RegExp(r'(BV[0-9A-Za-z]{10})');
  static final RegExp _aid = RegExp(r'(?:[?&]aid=|/av)(\d+)');
  static final RegExp _page = RegExp(r'[?&]p(?:age)?=(\d+)');

  /// Có phải link video Bilibili không.
  static bool canHandle(String src) =>
      src.contains('bilibili') && (_bvid.hasMatch(src) || _aid.hasMatch(src));

  static Future<BiliStream> resolve(String src, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final bvid = _bvid.firstMatch(src)?.group(1);
      final aid = bvid == null ? _aid.firstMatch(src)?.group(1) : null;
      if (bvid == null && aid == null) throw NetException('Không nhận ra link Bilibili: $src');
      final idQuery = bvid != null ? 'bvid=$bvid' : 'aid=$aid';
      final page = int.tryParse(_page.firstMatch(src)?.group(1) ?? '') ?? 1;

      // 1. cid
      final pages = await _getData(c, 'https://api.bilibili.com/x/player/pagelist?$idQuery');
      if (pages is! List || pages.isEmpty) throw NetException('Video không còn tồn tại');
      final p = pages[(page - 1).clamp(0, pages.length - 1).toInt()] as Map;
      final cid = p['cid'];
      final title = '${p['part'] ?? ''}';

      // 2. link MP4
      final playId = bvid != null ? 'bvid=$bvid' : 'avid=$aid';
      final play = await _getData(
        c,
        'https://api.bilibili.com/x/player/playurl?$playId&cid=$cid'
        '&qn=80&fnval=1&fnver=0&fourk=0&platform=html5&high_quality=1',
      );
      if (play is! Map) throw NetException('Không lấy được link video');
      final durl = play['durl'];
      if (durl is! List || durl.isEmpty) throw NetException('Video không có luồng phát');
      final first = durl.first as Map;
      final urls = <String>[
        '${first['url']}',
        for (final b in (first['backup_url'] is List ? first['backup_url'] as List : const [])) '$b',
      ].where((u) => u.startsWith('http')).map((u) => u.replaceFirst('http://', 'https://')).toList();
      if (urls.isEmpty) throw NetException('Video không có luồng phát');

      var quality = '';
      final q = play['quality'];
      final acceptQ = play['accept_quality'];
      final acceptD = play['accept_description'];
      if (acceptQ is List && acceptD is List) {
        final i = acceptQ.indexOf(q);
        if (i >= 0 && i < acceptD.length) quality = '${acceptD[i]}';
      }
      return BiliStream(urls: urls, title: title, quality: quality, headers: headers);
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<dynamic> _getData(http.Client c, String url) async {
    final res = await c.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw NetException('Bilibili HTTP ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    if (j is! Map || (j['code'] != 0 && j['code'] != '0')) {
      throw NetException('Bilibili: ${j is Map ? j['message'] : 'phản hồi lạ'}');
    }
    return j['data'];
  }
}
