import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';

class NetException implements Exception {
  NetException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// HTTP client nhỏ gọn có retry + timeout. Không phụ thuộc Flutter
/// nên dùng được cả trong isolate nền và tool dòng lệnh.
class Net {
  Net({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> wikiHeaders = {
    'User-Agent': AppConfig.userAgent,
    'Referer': '${AppConfig.wikiSiteBase}/',
    'Origin': AppConfig.wikiSiteBase,
    'Accept': 'application/json, text/plain, */*',
  };

  static const Map<String, String> mediaHeaders = {
    'User-Agent': AppConfig.userAgent,
    'Referer': '${AppConfig.wikiSiteBase}/',
  };

  Future<T> _retry<T>(Future<T> Function() fn, {int attempts = 3}) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        if (i < attempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 700 * (i + 1) * (i + 1)));
        }
      }
    }
    if (lastError is NetException) throw lastError;
    throw NetException(lastError.toString());
  }

  /// POST JSON tới API wiki, trả về trường `data` khi `Code == 0`.
  Future<Map<String, dynamic>> postWiki(String path, [Map<String, dynamic>? body]) {
    return _retry(() async {
      final res = await _client
          .post(
            Uri.parse('${AppConfig.wikiApiBase}$path'),
            headers: {...wikiHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) {
        throw NetException('HTTP ${res.statusCode} ($path)');
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) throw NetException('Phản hồi không hợp lệ ($path)');
      final code = decoded['Code'];
      if (code != 0 && code != '0') {
        throw NetException('API lỗi $code: ${decoded['Message']} ($path)');
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    });
  }

  /// GET một file (ảnh/âm thanh/JSON) dạng bytes.
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 90),
    int attempts = 3,
  }) {
    return _retry(() async {
      final res = await _client
          .get(Uri.parse(url), headers: headers ?? mediaHeaders)
          .timeout(timeout);
      if (res.statusCode != 200) {
        throw NetException('HTTP ${res.statusCode}: $url');
      }
      return res.bodyBytes;
    }, attempts: attempts);
  }

  Future<dynamic> getJson(String url, {int attempts = 2}) async {
    final bytes = await getBytes(
      url,
      headers: const {'User-Agent': AppConfig.userAgent, 'Cache-Control': 'no-cache'},
      timeout: const Duration(seconds: 40),
      attempts: attempts,
    );
    return jsonDecode(utf8.decode(bytes));
  }

  void close() => _client.close();
}
