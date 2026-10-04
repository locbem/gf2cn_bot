import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../core/file_cache.dart';
import '../data/game_dict.dart';
import '../data/repository.dart';
import '../data/translation_sync.dart';
import '../l10n/strings.dart';
import 'offline_downloader.dart';

enum SyncStatus { idle, running, ok, error }

/// Trạng thái toàn cục của app: ngôn ngữ, dữ liệu, đồng bộ bản dịch, cài đặt.
class AppController extends ChangeNotifier {
  late SharedPreferences _prefs;
  late String rootDir;
  late WikiRepository data;
  late OfflineDownloader offline;

  String lang = 'vi';
  double textScale = 1.0;
  String githubRepo = AppConfig.defaultGithubRepo;
  String githubBranch = AppConfig.defaultGithubBranch;
  String githubPath = AppConfig.defaultGithubPath;

  /// Tăng mỗi khi dữ liệu được nạp lại (để các màn hình chi tiết tải lại).
  int dataVersion = 0;

  SyncStatus viStatus = SyncStatus.idle;
  String? viMessage;

  String get dataRoot => p.join(rootDir, 'data');
  String get zhDir => p.join(dataRoot, 'zh');
  String get viDir => p.join(dataRoot, 'vi');

  S get s => S(lang, data.uiOverrides, data.dict);

  /// Từ điển thuật ngữ: ưu tiên bản tải từ GitHub (data/vi/game_dict.json),
  /// nếu chưa có thì dùng bản đóng gói sẵn trong app (assets/game_dict.json).
  Future<GameDict?> _loadDict() async {
    try {
      final f = File(p.join(viDir, 'game_dict.json'));
      if (await f.exists()) {
        final d = GameDict.tryParse(jsonDecode(await f.readAsString()));
        if (d != null && !d.isEmpty) return d;
      }
    } catch (_) {}
    try {
      return GameDict.tryParse(jsonDecode(await rootBundle.loadString('assets/game_dict.json')));
    } catch (_) {
      return null;
    }
  }

  Future<WikiRepository> _loadRepo() async =>
      WikiRepository.load(dataRoot: dataRoot, lang: lang, dict: lang == 'vi' ? await _loadDict() : null);

  bool get setupDone => (_prefs.getBool('setup_done') ?? false) && data.hasData;

  GithubSource get source =>
      GithubSource(repo: githubRepo, branch: githubBranch, path: githubPath);

  DateTime? get lastViCheck {
    final ms = _prefs.getInt('vi_last_check');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final support = await getApplicationSupportDirectory();
    rootDir = p.join(support.path, 'gf2wiki');
    await Directory(rootDir).create(recursive: true);

    lang = _prefs.getString('lang') ?? 'vi';
    textScale = _prefs.getDouble('text_scale') ?? 1.0;
    githubRepo = _prefs.getString('gh_repo') ?? AppConfig.defaultGithubRepo;
    githubBranch = _prefs.getString('gh_branch') ?? AppConfig.defaultGithubBranch;
    githubPath = _prefs.getString('gh_path') ?? AppConfig.defaultGithubPath;

    await Future.wait([
      imageFiles.init(p.join(rootDir, 'images')),
      audioFiles.init(p.join(rootDir, 'audio')),
    ]);
    offline = OfflineDownloader(zhDir: zhDir, prefs: _prefs);
    data = await _loadRepo();
  }

  /// Sau khi vào app: tự kiểm tra bản dịch mới + tiếp tục tải ảnh (nếu có).
  void startBackgroundTasks({VoidCallback? onTranslationUpdated}) {
    offline.resumeIfNeeded();
    unawaited(syncTranslations().then((r) {
      if (r != null && r.updated) onTranslationUpdated?.call();
    }));
  }

  Future<void> reloadData() async {
    data = await _loadRepo();
    dataVersion++;
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    if (value == lang) return;
    lang = value;
    await _prefs.setString('lang', value);
    await reloadData();
  }

  void setTextScale(double value) {
    textScale = value;
    _prefs.setDouble('text_scale', value);
    notifyListeners();
  }

  Future<void> setSource({required String repo, required String branch, required String path}) async {
    githubRepo = GithubSource.normalizeRepo(repo);
    githubBranch = branch.trim().isEmpty ? AppConfig.defaultGithubBranch : branch.trim();
    githubPath = path.trim();
    await _prefs.setString('gh_repo', githubRepo);
    await _prefs.setString('gh_branch', githubBranch);
    await _prefs.setString('gh_path', githubPath);
    notifyListeners();
  }

  /// Chương đang đọc dở của một bài (null nếu chưa đọc).
  int? readingChapter(int storyId) => _prefs.getInt('read_$storyId');

  void setReadingChapter(int storyId, int chapter) {
    _prefs.setInt('read_$storyId', chapter);
  }

  Future<void> markSetupDone() async {
    await _prefs.setBool('setup_done', true);
    notifyListeners();
  }

  /// Đồng bộ bản dịch tiếng Việt từ GitHub.
  /// [force] = true: bỏ qua giới hạn thời gian và ném lỗi ra ngoài.
  Future<SyncResult?> syncTranslations({bool force = false}) async {
    if (viStatus == SyncStatus.running) return null;
    final last = lastViCheck;
    if (!force && last != null && DateTime.now().difference(last) < AppConfig.translationCheckInterval) {
      return null;
    }
    viStatus = SyncStatus.running;
    viMessage = null;
    notifyListeners();
    final sync = TranslationSync(localDir: viDir);
    try {
      final r = await sync.sync(source);
      await _prefs.setInt('vi_last_check', DateTime.now().millisecondsSinceEpoch);
      viStatus = SyncStatus.ok;
      viMessage = r.updated
          ? s.t('translation_updated', {'n': r.downloaded})
          : s.t('translation_latest');
      if (r.updated) {
        await reloadData();
      } else {
        notifyListeners();
      }
      return r;
    } catch (e) {
      viStatus = SyncStatus.error;
      viMessage = s.t('translation_error', {'e': e});
      notifyListeners();
      if (force) rethrow;
      return null;
    } finally {
      sync.close();
    }
  }
}

/// Đưa [AppController] xuống cây widget.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  /// Lấy controller và đăng ký rebuild khi thay đổi.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Lấy controller không đăng ký rebuild (dùng trong callback).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContextX on BuildContext {
  AppController get app => AppScope.of(this);
  S get s => AppScope.of(this).s;
}
