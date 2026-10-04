import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/file_cache.dart';
import '../data/image_catalog.dart';

/// Tải hàng loạt để xem offline: ảnh cơ bản, ảnh chi tiết, ảnh động, lồng tiếng.
/// Người dùng chọn gói nào cần tải; chạy nền, tạm dừng/tiếp tục được.
/// (Ngoài ra mọi ảnh/voice đã xem/nghe đều tự được lưu lại.)
class OfflineDownloader extends ChangeNotifier {
  OfflineDownloader({required this.zhDir, required SharedPreferences prefs}) : _prefs = prefs;

  static const String _prefKey = 'offline_packs';

  final String zhDir;
  final SharedPreferences _prefs;

  bool running = false;
  bool preparing = false;
  OfflinePack? current;
  int done = 0;
  int total = 0;
  int failed = 0;

  /// Thống kê theo gói: đã lưu / tổng.
  final Map<OfflinePack, int> packDone = {};
  final Map<OfflinePack, int> packTotal = {};

  int _runId = 0;
  Timer? _notifyTimer;
  OfflineSets? _sets;

  static FileCache cacheFor(OfflinePack pack) => pack.isAudio ? audioFiles : imageFiles;

  /// Các gói người dùng đã chọn tải.
  Set<OfflinePack> get selected {
    final names = _prefs.getStringList(_prefKey) ?? const [];
    return {
      for (final n in names)
        for (final p in OfflinePack.values)
          if (p.name == n) p,
    };
  }

  Future<void> _saveSelected(Set<OfflinePack> packs) =>
      _prefs.setStringList(_prefKey, [for (final p in OfflinePack.values) if (packs.contains(p)) p.name]);

  bool get isComplete => total > 0 && !running && done >= total;
  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0).toDouble();

  Future<OfflineSets> catalog({bool refresh = false}) async {
    if (_sets == null || refresh) _sets = await OfflineCatalog.collect(zhDir);
    return _sets!;
  }

  /// Gọi khi dữ liệu wiki thay đổi.
  void invalidateCatalog() => _sets = null;

  /// Cập nhật thống kê đã lưu / tổng cho từng gói (không tải gì).
  Future<void> refreshCounts() async {
    final sets = await catalog();
    for (final p in OfflinePack.values) {
      final list = sets.of(p);
      final cache = cacheFor(p);
      packTotal[p] = list.length;
      packDone[p] = list.where(cache.has).length;
    }
    notifyListeners();
  }

  /// Bắt đầu tải các gói [packs] (lưu lại lựa chọn). Truyền tập rỗng = không tải.
  Future<void> start(Set<OfflinePack> packs) async {
    await _saveSelected(packs);
    final runId = ++_runId;
    if (packs.isEmpty) {
      running = false;
      preparing = false;
      notifyListeners();
      return;
    }
    running = true;
    preparing = true;
    failed = 0;
    notifyListeners();

    final sets = await catalog();
    if (runId != _runId) return;

    // Tổng quan + danh sách cần tải theo thứ tự gói.
    final order = [for (final p in OfflinePack.values) if (packs.contains(p)) p];
    final pending = <(OfflinePack, String)>[];
    total = 0;
    done = 0;
    for (final p in order) {
      final list = sets.of(p);
      final cache = cacheFor(p);
      var have = 0;
      for (final u in list) {
        if (cache.has(u)) {
          have++;
        } else {
          pending.add((p, u));
        }
      }
      packTotal[p] = list.length;
      packDone[p] = have;
      total += list.length;
      done += have;
    }
    preparing = false;
    notifyListeners();

    var next = 0;
    Future<void> worker() async {
      while (runId == _runId) {
        final i = next++;
        if (i >= pending.length) return;
        final (pack, url) = pending[i];
        current = pack;
        final file = await cacheFor(pack).ensure(url);
        if (runId != _runId) return;
        if (file == null) {
          failed++;
        } else {
          done++;
          packDone[pack] = (packDone[pack] ?? 0) + 1;
        }
        _scheduleNotify();
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    if (runId == _runId) {
      running = false;
      current = null;
      _notifyTimer?.cancel();
      notifyListeners();
    }
  }

  /// Tiếp tục tải các gói đã chọn (gọi khi mở app).
  void resumeIfNeeded() {
    final packs = selected;
    if (packs.isNotEmpty && !running) unawaited(start(packs));
  }

  void pause() {
    _runId++;
    running = false;
    preparing = false;
    current = null;
    _notifyTimer?.cancel();
    notifyListeners();
  }

  /// Bỏ chọn tất cả (dừng tải nền khi mở app).
  Future<void> clearSelection() async {
    pause();
    await _saveSelected(const {});
  }

  void _scheduleNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 350), notifyListeners);
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
