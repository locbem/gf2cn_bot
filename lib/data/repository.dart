import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../core/json_files.dart';
import '../core/json_merge.dart';
import 'dataset.dart';
import 'game_dict.dart';
import 'models.dart';

/// Đọc dữ liệu đã lưu trên máy và gộp bản dịch tiếng Việt (nếu chọn 'vi').
/// Mục nào chưa dịch sẽ tự động hiển thị tiếng Trung.
class WikiRepository {
  WikiRepository._(this.dataRoot, this.lang, this.dict);

  final String dataRoot;
  final String lang;

  /// Từ điển thuật ngữ (chỉ dùng khi lang = 'vi').
  final GameDict? dict;

  CategoryData category = CategoryData(const []);
  List<DollSummary> dolls = const [];
  List<Weapon> weapons = const [];
  List<WorldSummary> world = const [];
  List<MediaItem> media = const [];
  Map<String, String> uiOverrides = const {};
  Map<String, dynamic> zhManifest = const {};
  Map<String, dynamic> viManifest = const {};

  final Map<int, DollDetail> _dollCache = {};
  final Map<int, WorldDetail> _worldCache = {};
  late final Map<int, DollSummary> _dollById = {for (final d in dolls) d.id: d};
  late final Map<int, Weapon> _weaponById = {for (final w in weapons) w.id: w};

  bool get hasData => dolls.isNotEmpty || weapons.isNotEmpty || world.isNotEmpty;
  bool get hasVi => viManifest.isNotEmpty;

  String _dir(String l) => p.join(dataRoot, l);

  /// Đọc một file dữ liệu: zh → (vi) áp từ điển → gộp bản dịch data/vi.
  /// Chạy trong isolate riêng để không làm giật giao diện.
  Future<dynamic> _read(String rel) =>
      _readInIsolate(joinRel(_dir('zh'), rel), joinRel(_dir('vi'), rel), rel, lang, dict);

  // Hàm static: closure gửi sang isolate không giữ tham chiếu tới `this`.
  static Future<dynamic> _readInIsolate(String zhPath, String viPath, String rel, String lang, GameDict? dict) =>
      Isolate.run(() => loadMergedSync(zhPath: zhPath, viPath: viPath, rel: rel, lang: lang, dict: dict));

  /// Phiên bản đồng bộ (dùng trong isolate và trong test).
  static dynamic loadMergedSync({
    required String zhPath,
    required String viPath,
    required String rel,
    required String lang,
    GameDict? dict,
  }) {
    dynamic readSync(String path) {
      final f = File(path);
      if (!f.existsSync()) return null;
      try {
        return jsonDecode(f.readAsStringSync());
      } catch (_) {
        return null;
      }
    }

    final zh = readSync(zhPath);
    if (lang != 'vi') return zh;
    final vi = readSync(viPath);
    if (zh == null) return vi;
    final base = dict == null ? zh : dict.apply(rel, zh);
    return mergeTranslated(base, vi, zh);
  }

  static Future<WikiRepository> load({
    required String dataRoot,
    required String lang,
    GameDict? dict,
  }) async {
    final r = WikiRepository._(dataRoot, lang, lang == 'vi' ? dict : null);
    r.zhManifest = jMap(await readJsonFile(p.join(r._dir('zh'), DatasetFiles.manifest)));
    r.viManifest = jMap(await readJsonFile(p.join(r._dir('vi'), DatasetFiles.manifest)));

    final results = await Future.wait([
      r._read(DatasetFiles.category),
      r._read(DatasetFiles.dolls),
      r._read(DatasetFiles.weapons),
      r._read(DatasetFiles.world),
      r._read(DatasetFiles.media),
    ]);
    r.category = CategoryData.fromJson(jMap(results[0]));
    r.dolls = [for (final e in jMapList(jMap(results[1])['items'])) DollSummary.fromJson(e)];
    r.weapons = [for (final e in jMapList(jMap(results[2])['items'])) Weapon.fromJson(e)];
    r.world = [for (final e in jMapList(jMap(results[3])['items'])) WorldSummary.fromJson(e)];
    r.media = [for (final e in jMapList(jMap(results[4])['items'])) MediaItem.fromJson(e)];

    if (lang == 'vi') {
      final ui = jMap(await readJsonFile(p.join(r._dir('vi'), DatasetFiles.ui)));
      r.uiOverrides = {
        for (final e in ui.entries)
          if (e.value is String && (e.value as String).trim().isNotEmpty) e.key: e.value as String,
      };
    }
    return r;
  }

  DollSummary? dollById(int id) => _dollById[id];
  Weapon? weaponById(int id) => _weaponById[id];

  WorldSummary? worldById(int id) {
    for (final w in world) {
      if (w.id == id) return w;
    }
    return null;
  }

  MediaItem? mediaById(int id) {
    for (final m in media) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<WorldSummary> worldOf(int cid) => [for (final w in world) if (w.cid == cid) w];
  List<MediaItem> mediaOf(int cid) => [for (final m in media) if (m.cid == cid) m];

  /// Tìm vũ khí theo tên (để liên kết từ "Vũ khí ấn ký" của nhân vật).
  Weapon? weaponByName(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    for (final w in weapons) {
      if (w.name == n || w.nameZh == n) return w;
    }
    return null;
  }

  Future<DollDetail?> doll(int id) async {
    final cached = _dollCache[id];
    if (cached != null) return cached;
    final j = await _read(DatasetFiles.doll(id));
    if (j is! Map) return null;
    final d = DollDetail.fromJson(jMap(j));
    _dollCache[id] = d;
    return d;
  }

  Future<WorldDetail?> worldDetail(int id) async {
    final cached = _worldCache[id];
    if (cached != null) return cached;
    final j = await _read(DatasetFiles.worldItem(id));
    if (j is! Map) return null;
    final w = WorldDetail.fromJson(jMap(j));
    _worldCache[id] = w;
    return w;
  }

  String filterOptionName(String tabKey, String filterKey, int id) =>
      category.tab(tabKey)?.filter(filterKey)?.optionName(id) ?? '';
}
