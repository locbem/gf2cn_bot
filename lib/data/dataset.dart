import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../config.dart';
import '../core/json_files.dart';
import '../core/json_merge.dart';
import 'normalize.dart';

/// Tên file trong một bộ dữ liệu (data/zh hoặc data/vi).
///
/// ```
/// manifest.json        phiên bản + md5 từng file (app dùng để cập nhật)
/// category.json        cây danh mục + bộ lọc (tên tab, tên bộ lọc...)
/// dolls.json           danh sách nhân vật (rút gọn, tự sinh từ dolls/*.json)
/// dolls/<id>.json      chi tiết 1 nhân vật
/// weapons.json         danh sách + chi tiết vũ khí
/// world.json           danh sách bài "Thiết lập thế giới" (tự sinh từ world/*.json)
/// world/<id>.json      nội dung 1 bài (chương/đoạn)
/// media.json           "Tư liệu khác": PV, radio, hình nền
/// ui.json              (tuỳ chọn, chỉ bản vi) ghi đè nhãn giao diện
/// ```
class DatasetFiles {
  DatasetFiles._();

  static const String manifest = 'manifest.json';
  static const String category = 'category.json';
  static const String dolls = 'dolls.json';
  static const String dollsDir = 'dolls';
  static const String weapons = 'weapons.json';
  static const String world = 'world.json';
  static const String worldDir = 'world';
  static const String media = 'media.json';
  static const String ui = 'ui.json';

  static String doll(int id) => '$dollsDir/$id.json';
  static String worldItem(int id) => '$worldDir/$id.json';
}

class PackResult {
  PackResult({required this.files, required this.errors, required this.version});
  final int files;
  final List<String> errors;
  final String version;
}

dynamic _readSync(File f) => jsonDecode(f.readAsStringSync());

List<File> _jsonFilesIn(Directory dir) {
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.json'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Sinh lại file danh sách (dolls.json, world.json) từ các file chi tiết,
/// rồi ghi manifest.json (md5 từng file). Dùng sau khi dịch xong.
Future<PackResult> packDataset(String dir, {required String lang}) async {
  final errors = <String>[];
  final root = Directory(dir);
  if (!root.existsSync()) {
    throw ArgumentError('Không tìm thấy thư mục $dir');
  }

  // ---- dolls.json
  final dollDetails = <Map<String, dynamic>>[];
  for (final f in _jsonFilesIn(Directory(p.join(dir, DatasetFiles.dollsDir)))) {
    try {
      dollDetails.add(jMap(_readSync(f)));
    } catch (e) {
      errors.add('${p.relative(f.path, from: dir)}: $e');
    }
  }
  if (dollDetails.isNotEmpty) {
    final order = _existingOrder(p.join(dir, DatasetFiles.dolls));
    dollDetails.sort((a, b) => _orderCompare(order, jInt(a['id']), jInt(b['id'])));
    await writeJsonFile(p.join(dir, DatasetFiles.dolls), {
      'items': [for (final d in dollDetails) Normalizer.dollIndexEntry(d)],
    });
  }

  // ---- world.json
  final worlds = <Map<String, dynamic>>[];
  for (final f in _jsonFilesIn(Directory(p.join(dir, DatasetFiles.worldDir)))) {
    try {
      worlds.add(jMap(_readSync(f)));
    } catch (e) {
      errors.add('${p.relative(f.path, from: dir)}: $e');
    }
  }
  if (worlds.isNotEmpty) {
    final order = _existingOrder(p.join(dir, DatasetFiles.world));
    worlds.sort((a, b) => _orderCompare(order, jInt(a['id']), jInt(b['id'])));
    await writeJsonFile(p.join(dir, DatasetFiles.world), {
      'items': [for (final w in worlds) Normalizer.worldIndexEntry(w)],
    });
  }

  final version = await writeManifest(dir, lang: lang, errors: errors);
  final manifest = jMap(_readSync(File(p.join(dir, DatasetFiles.manifest))));
  return PackResult(files: jMap(manifest['files']).length, errors: errors, version: version);
}

Map<int, int> _existingOrder(String indexPath) {
  final f = File(indexPath);
  if (!f.existsSync()) return const {};
  try {
    final items = jMapList(jMap(_readSync(f))['items']);
    return {for (var i = 0; i < items.length; i++) jInt(items[i]['id']): i};
  } catch (_) {
    return const {};
  }
}

int _orderCompare(Map<int, int> order, int a, int b) {
  final oa = order[a];
  final ob = order[b];
  if (oa != null && ob != null) return oa.compareTo(ob);
  if (oa != null) return -1;
  if (ob != null) return 1;
  return b.compareTo(a); // mới nhất (id lớn) lên trước
}

/// Ghi manifest.json: version (thời điểm), md5 + kích thước từng file.
Future<String> writeManifest(
  String dir, {
  required String lang,
  List<String>? errors,
  Map<String, dynamic>? extra,
}) async {
  final files = <String, String>{};
  final root = Directory(dir);
  final entries = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in entries) {
    final rel = p.relative(f.path, from: dir).replaceAll(r'\', '/');
    if (!rel.toLowerCase().endsWith('.json') || rel == DatasetFiles.manifest) continue;
    final bytes = f.readAsBytesSync();
    try {
      jsonDecode(utf8.decode(bytes));
    } catch (e) {
      errors?.add('$rel: JSON lỗi – $e');
      continue;
    }
    files[rel] = md5Hex(bytes);
  }
  final version = DateTime.now().toUtc().toIso8601String();
  await writeJsonFile(p.join(dir, DatasetFiles.manifest), {
    'schema': AppConfig.dataSchema,
    'lang': lang,
    'version': version,
    ...?extra,
    'files': files,
  });
  return version;
}
