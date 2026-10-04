import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'json_files.dart';
import 'net.dart';

/// Bộ nhớ đệm file theo URL (ảnh, âm thanh) lưu vĩnh viễn trên đĩa.
/// - Tên file = md5(url) + đuôi file.
/// - Giới hạn số lượt tải song song.
/// - Gộp các yêu cầu trùng URL.
class FileCache {
  FileCache(this.label, {this.maxConcurrent = 8});

  final String label;
  final int maxConcurrent;

  Directory? _dir;
  final Set<String> _have = <String>{};
  final Map<String, Future<File?>> _inflight = {};
  final Map<String, String> _nameCache = {};
  final Net _net = Net();
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  bool get isReady => _dir != null;
  int get count => _have.length;
  String get path => _dir?.path ?? '';

  Future<void> init(String dirPath) async {
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    _have.clear();
    await for (final e in dir.list(followLinks: false)) {
      if (e is File) {
        final name = p.basename(e.path);
        if (name.endsWith('.part')) {
          try {
            await e.delete();
          } catch (_) {}
        } else {
          _have.add(name);
        }
      }
    }
    _dir = dir;
  }

  static String _extOf(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    for (final ext in const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.wav', '.mp3', '.ogg', '.m4a']) {
      if (path.endsWith(ext)) return ext;
    }
    return '';
  }

  String fileName(String url) => _nameCache.putIfAbsent(
        url,
        () => '${md5.convert(utf8.encode(url))}${_extOf(url)}',
      );

  File fileFor(String url) => File(p.join(_dir!.path, fileName(url)));

  bool has(String url) => _dir != null && _have.contains(fileName(url));

  File? localFile(String url) => has(url) ? fileFor(url) : null;

  /// Trả về file trên đĩa (tải về nếu chưa có). Null nếu tải lỗi.
  Future<File?> ensure(String url) {
    if (url.isEmpty || _dir == null) return Future<File?>.value(null);
    if (has(url)) return Future<File?>.value(fileFor(url));
    return _inflight.putIfAbsent(url, () async {
      try {
        return await _download(url);
      } finally {
        _inflight.remove(url);
      }
    });
  }

  Future<File?> _download(String url) async {
    await _acquire();
    try {
      final bytes = await _net.getBytes(url, attempts: 2);
      if (bytes.isEmpty) return null;
      final file = fileFor(url);
      await writeBytesAtomic(file.path, bytes);
      _have.add(fileName(url));
      return file;
    } catch (_) {
      return null;
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _active--;
    }
  }

  Future<int> diskUsage() async {
    final dir = _dir;
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> clear() async {
    final dir = _dir;
    if (dir == null) return;
    if (await dir.exists()) {
      await for (final e in dir.list(followLinks: false)) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
    _have.clear();
  }
}

/// Bộ đệm dùng chung cho cả app.
/// (Không đặt tên `imageCache` để tránh trùng với biến toàn cục của Flutter.)
final FileCache imageFiles = FileCache('images', maxConcurrent: 8);
final FileCache audioFiles = FileCache('audio', maxConcurrent: 3);
