import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/json_files.dart';
import '../core/json_merge.dart';
import '../core/net.dart';
import 'dataset.dart';

class GithubSource {
  const GithubSource({required this.repo, required this.branch, required this.path});

  final String repo; // user/repo
  final String branch;
  final String path; // thư mục trong repo, vd: data/vi

  bool get isValid => RegExp(r'^[\w.\-]+/[\w.\-]+$').hasMatch(repo);

  String get _cleanPath {
    final s = path.trim().replaceAll(r'\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
    return s.isEmpty ? '' : '$s/';
  }

  /// Các URL gốc theo thứ tự ưu tiên (raw GitHub, rồi CDN jsDelivr dự phòng).
  List<String> get baseUrls => [
        'https://raw.githubusercontent.com/$repo/$branch/$_cleanPath',
        'https://cdn.jsdelivr.net/gh/$repo@$branch/$_cleanPath',
      ];

  /// Chấp nhận: `user/repo`, `https://github.com/user/repo(.git)`, có/không dấu `/` cuối.
  static String normalizeRepo(String input) {
    var s = input.trim();
    s = s.replaceFirst(RegExp(r'^https?://(www\.)?github\.com/', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'\.git$'), '');
    s = s.replaceAll(RegExp(r'/+$'), '');
    final parts = s.split('/');
    if (parts.length >= 2) return '${parts[0]}/${parts[1]}';
    return s;
  }
}

class SyncResult {
  SyncResult({required this.updated, required this.version, this.downloaded = 0, this.message});

  final bool updated;
  final String version;
  final int downloaded;
  final String? message;
}

/// Đồng bộ thư mục dữ liệu tiếng Việt với repo GitHub theo manifest.json:
/// chỉ tải những file có md5 thay đổi, xoá file không còn trong manifest.
class TranslationSync {
  TranslationSync({required this.localDir, Net? net}) : _net = net ?? Net();

  final String localDir;
  final Net _net;

  Future<SyncResult> sync(
    GithubSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!source.isValid) {
      throw NetException('Repo GitHub không hợp lệ: "${source.repo}"');
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic>? remote;
    String? base;
    Object? lastError;
    for (final b in source.baseUrls) {
      try {
        final m = await _net.getJson('${b}manifest.json?t=$ts');
        if (m is Map) {
          remote = Map<String, dynamic>.from(m);
          base = b;
          break;
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (remote == null || base == null) {
      throw NetException('Không tải được manifest.json từ GitHub ($lastError)');
    }

    final remoteFiles = <String, String>{
      for (final e in jMap(remote['files']).entries)
        if (isSafeRelativePath(e.key)) e.key: jStr(e.value),
    };
    final version = jStr(remote['version']);

    final localManifest = jMap(await readJsonFile(p.join(localDir, DatasetFiles.manifest)));
    final localFiles = jMap(localManifest['files']);

    final toFetch = <String>[];
    for (final e in remoteFiles.entries) {
      final exists = File(joinRel(localDir, e.key)).existsSync();
      if (!exists || jStr(localFiles[e.key]) != e.value) toFetch.add(e.key);
    }

    if (toFetch.isEmpty && jStr(localManifest['version']) == version) {
      return SyncResult(updated: false, version: version);
    }

    await Directory(localDir).create(recursive: true);
    var done = 0;
    onProgress?.call(0, toFetch.length);
    for (final rel in toFetch) {
      final bytes = await _net.getBytes(
        '$base$rel?t=$ts',
        headers: const {'Cache-Control': 'no-cache'},
        timeout: const Duration(seconds: 60),
      );
      // Kiểm tra JSON hợp lệ trước khi ghi.
      jsonDecode(utf8.decode(bytes));
      await writeBytesAtomic(joinRel(localDir, rel), bytes);
      done++;
      onProgress?.call(done, toFetch.length);
    }

    // Xoá file cũ không còn trong manifest.
    final root = Directory(localDir);
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      final rel = p.relative(f.path, from: localDir).replaceAll(r'\', '/');
      if (rel == DatasetFiles.manifest) continue;
      if (!remoteFiles.containsKey(rel)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }

    // Lưu manifest (dùng md5 từ remote để lần sau so sánh).
    await writeJsonFile(p.join(localDir, DatasetFiles.manifest), {
      ...remote,
      'files': remoteFiles,
    });
    return SyncResult(updated: true, version: version, downloaded: toFetch.length);
  }

  void close() => _net.close();
}
