import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../core/json_files.dart';
import '../core/json_merge.dart';
import '../core/net.dart';
import 'dataset.dart';
import 'normalize.dart';
import 'wiki_api.dart';

/// Các giai đoạn tải dữ liệu.
enum ScrapeStage { category, dolls, weapons, world, media, saving, done, error }

class ScrapeProgress {
  const ScrapeProgress(this.stage, this.done, this.total, [this.message]);

  final ScrapeStage stage;
  final int done;
  final int total;
  final String? message;

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0).toDouble();

  Map<String, Object?> toMap() => {
        'stage': stage.index,
        'done': done,
        'total': total,
        'message': message,
      };

  static ScrapeProgress fromMap(Map<dynamic, dynamic> m) => ScrapeProgress(
        ScrapeStage.values[(m['stage'] as int).clamp(0, ScrapeStage.values.length - 1).toInt()],
        m['done'] as int? ?? 0,
        m['total'] as int? ?? 0,
        m['message'] as String?,
      );
}

class ScrapeSummary {
  ScrapeSummary({
    required this.dolls,
    required this.weapons,
    required this.world,
    required this.media,
    required this.failures,
  });

  final int dolls;
  final int weapons;
  final int world;
  final int media;
  final List<String> failures;

  @override
  String toString() =>
      'dolls=$dolls weapons=$weapons world=$world media=$media failures=${failures.length}';
}

/// Chạy [fn] cho từng phần tử với tối đa [concurrency] tác vụ song song.
Future<List<R>> pooledMap<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item) fn, {
  void Function(int done)? onEach,
}) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  var done = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i]);
      done++;
      onEach?.call(done);
    }
  }

  final workers = math.max(1, math.min(concurrency, items.length));
  await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  return [for (final r in results) r as R];
}

/// Tải toàn bộ wiki (tiếng Trung) và ghi ra [outDir] theo format chuẩn.
///
/// Thuần Dart (không dùng Flutter) → chạy được trong isolate nền của app
/// lẫn tool dòng lệnh `dart run tool/gf2data.dart scrape`.
class WikiScraper {
  WikiScraper({required this.outDir, Net? net, this.concurrency = 5})
      : _net = net ?? Net();

  final String outDir;
  final int concurrency;
  final Net _net;

  Future<ScrapeSummary> run({void Function(ScrapeProgress p)? onProgress}) async {
    void report(ScrapeStage s, int d, int t, [String? m]) =>
        onProgress?.call(ScrapeProgress(s, d, t, m));

    final api = WikiApi(_net);
    final failures = <String>[];
    final tmpDir = '$outDir.tmp';
    final tmp = Directory(tmpDir);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    tmp.createSync(recursive: true);

    try {
      // 1. Danh mục
      report(ScrapeStage.category, 0, 1);
      final category = Normalizer.category(await api.category());
      await writeJsonFile(p.join(tmpDir, DatasetFiles.category), category);
      report(ScrapeStage.category, 1, 1);

      // 2. Nhân vật
      report(ScrapeStage.dolls, 0, 1);
      final dollList = await api.handbook(1);
      final dolls = await pooledMap<Map<String, dynamic>, Map<String, dynamic>>(
        dollList,
        concurrency,
        (item) async {
          final id = jInt(item['hero_id']);
          Map<String, dynamic>? det;
          try {
            det = await api.heroDetail(id);
          } catch (e) {
            failures.add('doll $id: $e');
          }
          final d = Normalizer.doll(item, det);
          await writeJsonFile(p.join(tmpDir, DatasetFiles.doll(id)), d);
          return Normalizer.dollIndexEntry(d);
        },
        onEach: (n) => report(ScrapeStage.dolls, n, dollList.length),
      );
      await writeJsonFile(p.join(tmpDir, DatasetFiles.dolls), {'items': dolls});

      // 3. Vũ khí
      report(ScrapeStage.weapons, 0, 1);
      final weaponList = await api.handbook(2);
      final weapons = await pooledMap<Map<String, dynamic>, Map<String, dynamic>>(
        weaponList,
        concurrency + 2,
        (item) async {
          final id = jInt(item['weapon_id']);
          Map<String, dynamic>? det;
          try {
            det = await api.weaponDetail(id);
          } catch (e) {
            failures.add('weapon $id: $e');
          }
          return Normalizer.weapon(item, det);
        },
        onEach: (n) => report(ScrapeStage.weapons, n, weaponList.length),
      );
      await writeJsonFile(p.join(tmpDir, DatasetFiles.weapons), {'items': weapons});

      final sections = jMapList(category['sections']);
      List<int> cidsOf(String key) {
        for (final s in sections) {
          if (s['key'] == key) return [for (final t in jMapList(s['tabs'])) jInt(t['cid'])];
        }
        return const [];
      }

      // 4. Thiết lập thế giới (type = 1)
      report(ScrapeStage.world, 0, 1);
      final worldRefs = <(int cid, Map<String, dynamic> item)>[];
      for (final cid in cidsOf('world')) {
        for (final it in await api.information(1, cid)) {
          worldRefs.add((cid, it));
        }
      }
      final worldIndex = await pooledMap<(int, Map<String, dynamic>), Map<String, dynamic>>(
        worldRefs,
        concurrency,
        (ref) async {
          final (cid, item) = ref;
          final id = jInt(item['id']);
          Map<String, dynamic>? det;
          try {
            det = await api.infoDetail(id, 1);
          } catch (e) {
            failures.add('world $id: $e');
          }
          final w = Normalizer.world(item, det, cid);
          await writeJsonFile(p.join(tmpDir, DatasetFiles.worldItem(id)), w);
          return Normalizer.worldIndexEntry(w);
        },
        onEach: (n) => report(ScrapeStage.world, n, worldRefs.length),
      );
      await writeJsonFile(p.join(tmpDir, DatasetFiles.world), {'items': worldIndex});

      // 5. Tư liệu khác (type = 2) – danh sách đã chứa đầy đủ nội dung
      final mediaCids = cidsOf('news');
      final media = <Map<String, dynamic>>[];
      for (var i = 0; i < mediaCids.length; i++) {
        report(ScrapeStage.media, i, mediaCids.length);
        for (final it in await api.information(2, mediaCids[i])) {
          media.add(Normalizer.media(it, mediaCids[i]));
        }
      }
      report(ScrapeStage.media, mediaCids.length, mediaCids.length);
      await writeJsonFile(p.join(tmpDir, DatasetFiles.media), {'items': media});

      // 6. Manifest + thay thế thư mục cũ
      report(ScrapeStage.saving, 0, 1);
      await writeManifest(tmpDir, lang: 'zh', extra: {
        'source': 'https://gf2-bbs.exiliumgf.com/wiki/category',
        'counts': {
          'dolls': dolls.length,
          'weapons': weapons.length,
          'world': worldIndex.length,
          'media': media.length,
        },
      });
      final out = Directory(outDir);
      if (out.existsSync()) out.deleteSync(recursive: true);
      tmp.renameSync(outDir);
      report(ScrapeStage.saving, 1, 1);

      return ScrapeSummary(
        dolls: dolls.length,
        weapons: weapons.length,
        world: worldIndex.length,
        media: media.length,
        failures: failures,
      );
    } catch (e) {
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } catch (_) {}
      rethrow;
    } finally {
      _net.close();
    }
  }
}
