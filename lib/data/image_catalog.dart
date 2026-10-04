import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../core/json_merge.dart';
import 'dataset.dart';

/// Các gói tải offline.
enum OfflinePack {
  /// Ảnh đại diện nhân vật/vũ khí + ảnh bìa bài viết (~200 MB).
  basic,

  /// Ảnh tĩnh còn lại trong nội dung:立绘, kỹ năng, truyện, hình nền… (~2,4 GB).
  images,

  /// Ảnh động GIF (~800 MB).
  gifs,

  /// File lồng tiếng .wav (~1,5 GB).
  voices,
}

extension OfflinePackX on OfflinePack {
  /// Dung lượng ước tính (đo mẫu trên wiki 10/2026).
  String get estimate => switch (this) {
        OfflinePack.basic => '~200 MB',
        OfflinePack.images => '~2,4 GB',
        OfflinePack.gifs => '~800 MB',
        OfflinePack.voices => '~1,5 GB',
      };

  bool get isAudio => this == OfflinePack.voices;
}

class OfflineSets {
  const OfflineSets(this.urls);

  final Map<OfflinePack, List<String>> urls;

  List<String> of(OfflinePack pack) => urls[pack] ?? const [];
}

/// Quét dữ liệu đã tải để lấy danh sách URL ảnh / ảnh động / lồng tiếng (chạy trong isolate).
class OfflineCatalog {
  OfflineCatalog._();

  static final RegExp _imgUrl = RegExp(
    r'''https?://[^\s"'<>\\]+?\.(?:png|jpe?g|gif|webp)(?:\?[^\s"'<>\\]*)?''',
    caseSensitive: false,
  );
  static final RegExp _audioUrl = RegExp(
    r'''https?://[^\s"'<>\\]+?\.(?:wav|mp3|ogg|m4a)(?:\?[^\s"'<>\\]*)?''',
    caseSensitive: false,
  );

  static Future<OfflineSets> collect(String zhDir) => Isolate.run(() => _collect(zhDir));

  static bool _isGif(String url) => (Uri.tryParse(url)?.path ?? url).toLowerCase().endsWith('.gif');

  static OfflineSets _collect(String zhDir) {
    final basic = <String>{};
    dynamic read(String rel) {
      final f = File(p.join(zhDir, rel));
      if (!f.existsSync()) return null;
      try {
        return jsonDecode(f.readAsStringSync());
      } catch (_) {
        return null;
      }
    }

    for (final e in jMapList(jMap(read(DatasetFiles.dolls))['items'])) {
      basic.add(jStr(e['pic']));
    }
    for (final e in jMapList(jMap(read(DatasetFiles.weapons))['items'])) {
      basic.add(jStr(e['pic']));
    }
    for (final e in jMapList(jMap(read(DatasetFiles.world))['items'])) {
      basic.add(jStr(e['cover']));
    }
    for (final e in jMapList(jMap(read(DatasetFiles.media))['items'])) {
      basic.add(jStr(e['cover']));
    }
    basic.removeWhere((u) => u.isEmpty);

    final images = <String>{};
    final gifs = <String>{};
    final voices = <String>{};
    final dir = Directory(zhDir);
    if (dir.existsSync()) {
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final text = f.readAsStringSync();
        for (final m in _imgUrl.allMatches(text)) {
          final u = m.group(0)!;
          if (basic.contains(u)) continue;
          (_isGif(u) ? gifs : images).add(u);
        }
        for (final m in _audioUrl.allMatches(text)) {
          voices.add(m.group(0)!);
        }
      }
    }
    return OfflineSets({
      OfflinePack.basic: basic.toList(),
      OfflinePack.images: images.toList(),
      OfflinePack.gifs: gifs.toList(),
      OfflinePack.voices: voices.toList(),
    });
  }
}
