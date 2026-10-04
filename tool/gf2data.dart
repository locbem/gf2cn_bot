// Công cụ dòng lệnh quản lý dữ liệu wiki & bản dịch.
//
// Cách dùng (chạy ở thư mục gốc project, sau khi `flutter pub get`):
//
//   dart run tool/gf2data.dart scrape [data/zh]
//       Tải toàn bộ wiki (tiếng Trung) về thư mục data/zh.
//
//   dart run tool/gf2data.dart init-vi [data/zh] [data/vi]
//       Chép các file CHƯA CÓ trong data/vi từ data/zh (để bắt đầu dịch,
//       hoặc thêm nhân vật/bài mới sau khi wiki cập nhật). Không ghi đè file đã dịch.
//
//   dart run tool/gf2data.dart pack [data/vi]
//       Sinh lại dolls.json / world.json từ file chi tiết + ghi manifest.json.
//       Chạy lệnh này mỗi lần dịch xong, trước khi commit & push lên GitHub.
//
//   dart run tool/gf2data.dart ui-template [data/vi/ui.json]
//       Tạo file ui.json chứa toàn bộ nhãn giao diện tiếng Việt để chỉnh sửa.
//
//   dart run tool/gf2data.dart status [data/zh] [data/vi]
//       Thống kê tiến độ dịch (số file đã khác bản gốc).
//
//   dart run tool/gf2data.dart dict-missing [data/zh] [data/vi/game_dict.json]
//       Liệt kê tên/tiêu đề chưa có trong từ điển game_dict.json.

import 'dart:convert';
import 'dart:io';

import 'package:gf2_wiki/core/json_files.dart';
import 'package:gf2_wiki/core/json_merge.dart';
import 'package:gf2_wiki/data/dataset.dart';
import 'package:gf2_wiki/data/game_dict.dart';
import 'package:gf2_wiki/data/scraper.dart';
import 'package:gf2_wiki/l10n/strings.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(64);
  }
  final cmd = args.first;
  final rest = args.skip(1).toList();
  try {
    switch (cmd) {
      case 'scrape':
        await _scrape(rest.isNotEmpty ? rest[0] : 'data/zh');
      case 'init-vi':
        await _initVi(rest.isNotEmpty ? rest[0] : 'data/zh', rest.length > 1 ? rest[1] : 'data/vi');
      case 'pack':
        await _pack(rest.isNotEmpty ? rest[0] : 'data/vi');
      case 'ui-template':
        await _uiTemplate(rest.isNotEmpty ? rest[0] : 'data/vi/ui.json');
      case 'status':
        _status(rest.isNotEmpty ? rest[0] : 'data/zh', rest.length > 1 ? rest[1] : 'data/vi');
      case 'dict-missing':
        _dictMissing(rest.isNotEmpty ? rest[0] : 'data/zh', rest.length > 1 ? rest[1] : 'data/vi/game_dict.json');
      default:
        _usage();
        exit(64);
    }
  } catch (e, st) {
    stderr.writeln('LỖI: $e');
    stderr.writeln(st);
    exit(1);
  }
}

void _usage() {
  stdout.writeln('''
GF2 Wiki – công cụ dữ liệu

  dart run tool/gf2data.dart scrape [data/zh]
  dart run tool/gf2data.dart init-vi [data/zh] [data/vi]
  dart run tool/gf2data.dart pack [data/vi]
  dart run tool/gf2data.dart ui-template [data/vi/ui.json]
  dart run tool/gf2data.dart status [data/zh] [data/vi]
  dart run tool/gf2data.dart dict-missing [data/zh] [data/vi/game_dict.json]
''');
}

/// Liệt kê tên nhân vật / vũ khí / trang phục / đội / tiêu đề chưa có trong từ điển,
/// in ra dạng JSON để chép thẳng vào game_dict.json rồi điền bản dịch.
void _dictMissing(String zh, String dictPath) {
  final dict = GameDict.tryParse(jsonDecode(File(dictPath).readAsStringSync()));
  if (dict == null) throw ArgumentError('Không đọc được $dictPath');
  List<Map<String, dynamic>> items(String rel) {
    final f = File(p.join(zh, rel));
    if (!f.existsSync()) return const [];
    return jMapList(jMap(jsonDecode(f.readAsStringSync()))['items']);
  }

  final dolls = <Map<String, dynamic>>[];
  final dollDir = Directory(p.join(zh, DatasetFiles.dollsDir));
  if (dollDir.existsSync()) {
    for (final f in dollDir.listSync().whereType<File>()) {
      if (f.path.endsWith('.json')) dolls.add(jMap(jsonDecode(f.readAsStringSync())));
    }
  }
  final missing = dict.missing(
    dolls: dolls,
    weapons: items(DatasetFiles.weapons),
    world: items(DatasetFiles.world),
    media: items(DatasetFiles.media),
  );
  final out = <String, Map<String, String>>{
    for (final e in missing.entries)
      if (e.value.isNotEmpty) e.key: {for (final v in (e.value.toList()..sort())) v: ''},
  };
  final total = out.values.fold<int>(0, (a, m) => a + m.length);
  stdout.writeln('// $total mục chưa có trong ${p.basename(dictPath)} – điền bản dịch rồi gộp vào file từ điển:');
  stdout.writeln(prettyJson.convert(out));
}

Future<void> _scrape(String out) async {
  stdout.writeln('Đang tải wiki về "$out" ...');
  var lastLine = '';
  final summary = await WikiScraper(outDir: out).run(onProgress: (pr) {
    final line = '  ${pr.stage.name.padRight(9)} ${pr.done}/${pr.total}';
    if (line != lastLine) {
      stdout.write('\r$line      ');
      lastLine = line;
    }
  });
  stdout.writeln('\nXong: $summary');
  for (final f in summary.failures) {
    stdout.writeln('  ! $f');
  }
}

Future<void> _initVi(String zh, String vi) async {
  final src = Directory(zh);
  if (!src.existsSync()) throw ArgumentError('Không thấy $zh – hãy chạy "scrape" trước.');
  var copied = 0;
  for (final f in src.listSync(recursive: true).whereType<File>()) {
    final rel = p.relative(f.path, from: zh);
    if (!rel.endsWith('.json') || p.basename(rel) == DatasetFiles.manifest) continue;
    final target = File(p.join(vi, rel));
    if (target.existsSync()) continue;
    target.parent.createSync(recursive: true);
    f.copySync(target.path);
    copied++;
  }
  stdout.writeln('Đã chép $copied file mới sang $vi');
  await _pack(vi);
}

Future<void> _pack(String dir) async {
  final r = await packDataset(dir, lang: 'vi');
  stdout.writeln('Đã đóng gói $dir: ${r.files} file, version ${r.version}');
  if (r.errors.isNotEmpty) {
    stdout.writeln('Có ${r.errors.length} lỗi (file bị bỏ qua khỏi manifest):');
    for (final e in r.errors) {
      stdout.writeln('  ! $e');
    }
    exitCode = 2;
  }
}

Future<void> _uiTemplate(String out) async {
  final file = File(out);
  Map<String, dynamic> existing = {};
  if (file.existsSync()) {
    try {
      existing = Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
    } catch (_) {}
  }
  final data = <String, String>{
    for (final e in UiStrings.table.entries) e.key: (existing[e.key] as String?) ?? e.value[0],
  };
  await writeJsonFile(out, data);
  stdout.writeln('Đã ghi ${data.length} nhãn vào $out (giữ nguyên các nhãn đã sửa).');
}

void _status(String zh, String vi) {
  final zhDir = Directory(zh);
  if (!zhDir.existsSync()) throw ArgumentError('Không thấy $zh');
  var total = 0;
  var translated = 0;
  var missing = 0;
  final untranslated = <String>[];
  for (final f in zhDir.listSync(recursive: true).whereType<File>()) {
    final rel = p.relative(f.path, from: zh).replaceAll(r'\', '/');
    if (!rel.endsWith('.json') || rel == DatasetFiles.manifest) continue;
    total++;
    final v = File(p.join(vi, rel));
    if (!v.existsSync()) {
      missing++;
      continue;
    }
    if (v.readAsStringSync() != f.readAsStringSync()) {
      translated++;
    } else {
      untranslated.add(rel);
    }
  }
  stdout.writeln('Tổng: $total file | đã sửa/dịch: $translated | giống bản gốc: ${untranslated.length} | chưa có: $missing');
  if (untranslated.isNotEmpty && untranslated.length <= 40) {
    stdout.writeln('Chưa dịch:');
    for (final r in untranslated) {
      stdout.writeln('  - $r');
    }
  }
}
