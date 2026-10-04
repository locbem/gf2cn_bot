// Chỉnh các file nền tảng sau khi chạy `flutter create`:
//   flutter create --platforms=android,windows --org com.locbem --project-name gf2_wiki .
//   dart run tool/patch_platforms.dart
//
// - Android: quyền INTERNET, tên app, cho phép http, màn hình khởi động tối, icon.
// - Windows: tiêu đề cửa sổ, kích thước mặc định, icon.
// Chạy nhiều lần không sao (idempotent).

import 'dart:io';

const appTitle = 'GF2 Wiki';
const bgColor = '#FF0E1014';

void main() {
  var changed = 0;
  changed += _patchAndroidManifest();
  changed += _patchLaunchBackground('android/app/src/main/res/drawable/launch_background.xml');
  changed += _patchLaunchBackground('android/app/src/main/res/drawable-v21/launch_background.xml');
  changed += _copyAndroidIcons();
  changed += _patchWindows();
  changed += _syncDictAsset();
  stdout.writeln('patch_platforms: $changed thay đổi.');
}

/// Đóng gói bản từ điển mới nhất (data/vi/game_dict.json) vào app làm bản dự phòng.
int _syncDictAsset() {
  final src = File('data/vi/game_dict.json');
  final dst = File('assets/game_dict.json');
  if (!src.existsSync()) return 0;
  if (dst.existsSync() && dst.readAsStringSync() == src.readAsStringSync()) return 0;
  dst.parent.createSync(recursive: true);
  src.copySync(dst.path);
  stdout.writeln('  ✓ assets/game_dict.json ← data/vi/game_dict.json');
  return 1;
}

int _patchAndroidManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stdout.writeln('  (bỏ qua Android – chưa có thư mục android/)');
    return 0;
  }
  var s = f.readAsStringSync();
  final orig = s;
  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirstMapped(
      RegExp(r'<manifest[^>]*>'),
      (m) => '${m[0]}\n    <uses-permission android:name="android.permission.INTERNET"/>',
    );
  }
  s = s.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$appTitle"');
  if (!s.contains('usesCleartextTraffic')) {
    s = s.replaceFirst('<application', '<application\n        android:usesCleartextTraffic="true"');
  }
  if (!s.contains('android:scheme="https"')) {
    const intent = '''
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>''';
    if (s.contains('<queries>')) {
      s = s.replaceFirst('<queries>', '<queries>$intent');
    } else {
      s = s.replaceFirst('</manifest>', '    <queries>$intent\n    </queries>\n</manifest>');
    }
  }
  if (s != orig) {
    f.writeAsStringSync(s);
    stdout.writeln('  ✓ AndroidManifest.xml');
    return 1;
  }
  return 0;
}

int _patchLaunchBackground(String path) {
  final f = File(path);
  if (!f.existsSync()) return 0;
  const content = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Nền màn hình khởi động (tối, trùng màu app) -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <color android:color="$bgColor" />
    </item>
</layer-list>
''';
  if (f.readAsStringSync() == content) return 0;
  f.writeAsStringSync(content);
  stdout.writeln('  ✓ $path');
  return 1;
}

int _copyAndroidIcons() {
  final src = Directory('assets_src/icon/android');
  final res = Directory('android/app/src/main/res');
  if (!src.existsSync() || !res.existsSync()) return 0;
  var n = 0;
  for (final dir in src.listSync().whereType<Directory>()) {
    final name = dir.uri.pathSegments.where((e) => e.isNotEmpty).last;
    final icon = File('${dir.path}/ic_launcher.png');
    if (!icon.existsSync()) continue;
    final target = File('${res.path}/$name/ic_launcher.png');
    target.parent.createSync(recursive: true);
    icon.copySync(target.path);
    n++;
  }
  if (n > 0) stdout.writeln('  ✓ Android icon ($n kích thước)');
  return n > 0 ? 1 : 0;
}

int _patchWindows() {
  final main = File('windows/runner/main.cpp');
  if (!main.existsSync()) {
    stdout.writeln('  (bỏ qua Windows – chưa có thư mục windows/)');
    return 0;
  }
  var n = 0;
  var s = main.readAsStringSync();
  final orig = s;
  s = s.replaceAll('L"gf2_wiki"', 'L"$appTitle"');
  s = s.replaceAll(RegExp(r'Win32Window::Size size\(\s*1280\s*,\s*720\s*\)'), 'Win32Window::Size size(1280, 820)');
  if (s != orig) {
    main.writeAsStringSync(s);
    stdout.writeln('  ✓ windows/runner/main.cpp');
    n++;
  }
  final rc = File('windows/runner/Runner.rc');
  if (rc.existsSync()) {
    final r = rc.readAsStringSync();
    final r2 = r
        .replaceAll('VALUE "FileDescription", "gf2_wiki"', 'VALUE "FileDescription", "$appTitle"')
        .replaceAll('VALUE "ProductName", "gf2_wiki"', 'VALUE "ProductName", "$appTitle"');
    if (r2 != r) {
      rc.writeAsStringSync(r2);
      n++;
    }
  }
  final ico = File('assets_src/icon/app_icon.ico');
  final target = File('windows/runner/resources/app_icon.ico');
  if (ico.existsSync() && target.parent.existsSync()) {
    ico.copySync(target.path);
    stdout.writeln('  ✓ Windows icon');
    n++;
  }
  return n;
}
