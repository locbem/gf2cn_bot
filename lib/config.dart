/// Cấu hình chung của app.
///
/// Sửa [AppConfig.defaultGithubRepo] nếu bạn đổi repo chứa bản dịch.
/// Người dùng cũng có thể đổi repo ngay trong màn hình Cài đặt.
class AppConfig {
  AppConfig._();

  static const String appName = 'GF2 Wiki';

  /// API gốc của wiki chính thức (tiếng Trung).
  static const String wikiApiBase = 'https://gf2-bbs-api.exiliumgf.com';
  static const String wikiSiteBase = 'https://gf2-bbs.exiliumgf.com';

  /// Repo GitHub chứa bản dịch tiếng Việt (dạng `user/repo`).
  static const String defaultGithubRepo = 'locbem/gf2cn_bot';
  static const String defaultGithubBranch = 'main';

  /// Thư mục trong repo chứa dữ liệu tiếng Việt.
  static const String defaultGithubPath = 'data/vi';

  /// Phiên bản cấu trúc JSON. Tăng khi đổi format dữ liệu.
  static const int dataSchema = 1;

  /// Khoảng thời gian tối thiểu giữa 2 lần tự kiểm tra bản dịch mới.
  static const Duration translationCheckInterval = Duration(hours: 3);

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0 Safari/537.36';
}
