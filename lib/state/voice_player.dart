import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../core/file_cache.dart';

/// Trình phát lồng tiếng dùng chung (chỉ phát 1 câu thoại một lúc).
/// File âm thanh được tải về bộ đệm trước khi phát → nghe lại không tốn mạng.
class VoicePlayer extends ChangeNotifier {
  VoicePlayer._() {
    _sub = _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      if (state == PlayerState.completed && _loading == null) _current = null;
      notifyListeners();
    });
  }

  static final VoicePlayer instance = VoicePlayer._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  String? _current;
  String? _loading;
  bool _playing = false;

  bool isPlaying(String url) => _playing && _current == url;
  bool isLoading(String url) => _loading == url;

  /// Phát/dừng câu thoại. Trả về false nếu không phát được.
  Future<bool> toggle(String url) async {
    if (url.isEmpty) return false;
    if (_current == url && (_playing || _loading == url)) {
      await stop();
      return true;
    }
    _current = url;
    _loading = url;
    notifyListeners();
    try {
      await _player.stop();
      final file = await audioFiles.ensure(url);
      if (_current != url) return true; // người dùng đã chọn câu khác
      if (file != null) {
        await _player.play(DeviceFileSource(file.path));
      } else {
        await _player.play(UrlSource(url));
      }
      return true;
    } catch (_) {
      if (_current == url) _current = null;
      return false;
    } finally {
      if (_loading == url) _loading = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _current = null;
    _loading = null;
    _playing = false;
    notifyListeners();
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
