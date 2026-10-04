import '../data/game_dict.dart';

/// Chuỗi giao diện (UI) cho 2 ngôn ngữ: [vi, zh].
///
/// Bản tiếng Việt có thể được ghi đè từ file `ui.json` trong repo bản dịch
/// (key → chuỗi), không cần build lại app. Tạo file mẫu bằng:
///   dart run tool/gf2data.dart ui-template data/vi/ui.json
class UiStrings {
  UiStrings._();

  static const Map<String, List<String>> table = {
    // ---- chung
    'app_title': ['GF2 Wiki', '少前2 Wiki'],
    'sec_handbook': ['Wiki Game', '游戏图鉴'],
    'sec_world': ['Thiết lập Thế giới', '世界设定'],
    'sec_news': ['Thông tin khác', '其他资讯'],
    // Nhãn ngắn cho thanh điều hướng (không tra từ điển).
    'nav_handbook': ['Wiki Game', '图鉴'],
    'nav_world': ['Thế giới', '世界'],
    'nav_news': ['Thông tin', '资讯'],
    'settings': ['Cài đặt', '设置'],
    'search': ['Tìm kiếm', '搜索'],
    'search_hint': ['Tìm nhân vật, vũ khí, bài viết…', '搜索人形、武器、文章…'],
    'search_dolls_hint': ['Tìm nhân vật…', '搜索人形…'],
    'search_weapons_hint': ['Tìm vũ khí…', '搜索武器…'],
    'all': ['Tất cả', '全部'],
    'clear_filters': ['Xoá lọc', '清除筛选'],
    'no_results': ['Không có kết quả', '没有结果'],
    'no_data': ['Chưa có dữ liệu', '暂无数据'],
    'in_progress': ['Đang cập nhật', '施工中'],
    'retry': ['Thử lại', '重试'],
    'close': ['Đóng', '关闭'],
    'cancel': ['Huỷ', '取消'],
    'save': ['Lưu', '保存'],
    'confirm': ['Đồng ý', '确定'],
    'loading': ['Đang tải…', '加载中…'],
    'error_load': ['Không tải được dữ liệu', '数据加载失败'],
    'count_items': ['{n} mục', '{n} 项'],
    'chapters_count': ['{n} chương', '{n} 章'],
    'results_dolls': ['Nhân vật', '人形'],
    'results_weapons': ['Vũ khí', '武器'],
    'results_world': ['Thiết lập thế giới', '世界设定'],
    'results_media': ['Tư liệu', '资讯'],
    'switch_lang_tooltip': ['Đổi ngôn ngữ', '切换语言'],

    // ---- chi tiết nhân vật
    'tab_profile': ['Hồ sơ', '人形资料'],
    'tab_growth': ['Bồi dưỡng', '人形养成'],
    'tab_archive': ['Tư liệu', '人形档案'],
    'tab_voice': ['Lồng tiếng', '人形语音'],
    'f_role': ['Nghề nghiệp', '职业'],
    'f_rarity': ['Độ hiếm', '稀有度'],
    'f_weapon': ['Vũ khí ấn ký', '烙印编号'],
    'f_model': ['Mẫu thân thể', '素体型号'],
    'f_attr': ['Thuộc tính dị vị', '异位属性'],
    'f_ammo': ['Loại vũ khí', '武器类型'],
    'f_team': ['Affiliation', '小队归属'],
    'description': ['Giới thiệu', '简介'],
    'portrait': ['Hình minh hoạ', '立绘'],
    'modeling': ['Mô hình', '建模'],
    'skins': ['Trang phục', '皮肤'],
    'gifs': ['Ảnh động', '动图'],
    'other_info': ['Thông tin khác', '其他信息'],
    'base_stats': ['Chỉ số cơ bản (Lv.60)', '基础属性统计（60级）'],
    'skills': ['Kỹ năng', '技能'],
    'battle_skill': ['Neural Fortification', '云图强固'],
    'talents': ['Neural Helix', '心智螺旋'],
    'remoulding': ['Mimic Atlas', '拟态图谱'],
    'weapon_desc': ['Vũ khí ấn ký', '烙印武器'],
    'development': ['Hướng dẫn', '攻略集锦'],
    'story': ['Câu chuyện', '角色故事'],
    'gifts': ['Quà tặng', '好感度礼物'],
    'gallery': ['Album', '图册'],
    'voice_daily': ['Thoại cá nhân', '个性语音'],
    'voice_battle': ['Thoại chiến đấu', '战斗语音'],
    'voice_error': ['Không phát được âm thanh', '音频播放失败'],
    'view_weapon': ['Xem vũ khí', '查看武器'],

    // ---- vũ khí
    'w_attributes': ['Thuộc tính', '属性'],
    'w_tuning': ['Calibration', '调校'],
    'w_type': ['Loại', '类型'],
    'w_rarity': ['Độ hiếm', '稀有度'],
    'w_owner': ['Nhân vật', '所属人形'],

    // ---- bài viết / cốt truyện
    'toc': ['Mục lục', '目录'],
    'prev_chapter': ['Chương trước', '上一章'],
    'next_chapter': ['Chương sau', '下一章'],
    'continue_reading': ['Đọc tiếp: {name}', '继续阅读：{name}'],
    'watch_video': ['Xem video', '播放视频'],
    'open_link': ['Mở liên kết', '打开链接'],

    // ---- thiết lập lần đầu
    'setup_title': ['Thiết lập lần đầu', '首次设置'],
    'setup_welcome': [
      'Ứng dụng sẽ tải dữ liệu gốc từ wiki chính thức (khoảng 50 MB) và bản dịch tiếng Việt từ GitHub.',
      '应用将从官方Wiki下载原始数据（约50MB），并从GitHub下载越南语翻译。'
    ],
    'setup_lang': ['Ngôn ngữ', '语言'],
    'setup_step_wiki': ['Tải dữ liệu gốc từ wiki', '从Wiki下载原始数据'],
    'setup_step_vi': ['Tải bản dịch tiếng Việt', '下载越南语翻译'],
    'setup_step_offline': ['Tải để xem offline (tuỳ chọn)', '离线下载（可选）'],
    'setup_start': ['Bắt đầu', '开始'],
    'stage_category': ['Danh mục', '目录'],
    'stage_dolls': ['Nhân vật', '人形'],
    'stage_weapons': ['Vũ khí', '武器'],
    'stage_world': ['Thiết lập thế giới', '世界设定'],
    'stage_media': ['Tư liệu khác', '其他资讯'],
    'stage_saving': ['Đang lưu', '保存中'],
    'stage_done': ['Hoàn tất', '完成'],
    'vi_skipped': ['Chưa có bản dịch – tạm hiển thị tiếng Trung', '暂无翻译，将显示中文'],
    'img_skip': ['Để sau', '稍后'],
    'setup_failed': ['Tải dữ liệu thất bại', '下载失败'],
    'need_internet': ['Lần chạy đầu tiên cần kết nối Internet.', '首次运行需要联网。'],
    'partial_failures': ['{n} mục tải lỗi đã được bỏ qua', '{n}项下载失败，已跳过'],

    // ---- tải offline
    'offline_title': ['Tải để xem offline', '离线下载'],
    'offline_hint': [
      'Ảnh, ảnh động và lồng tiếng đã xem/nghe luôn được tự lưu lại. Có thể chọn thêm các gói dưới đây để tải trước toàn bộ:',
      '浏览过的图片、动图和语音会自动保存。也可以选择以下内容预先全部下载：'
    ],
    'pack_basic': ['Ảnh cơ bản', '基础图片'],
    'pack_basic_desc': ['Ảnh đại diện nhân vật, vũ khí, ảnh bìa bài viết', '人形/武器头像、文章封面'],
    'pack_images': ['Ảnh chi tiết', '详情图片'],
    'pack_images_desc': ['Hình minh hoạ, kỹ năng, quà tặng, truyện, hình nền…', '立绘、技能、礼物、剧情、壁纸等'],
    'pack_gifs': ['Ảnh động (GIF)', '动图'],
    'pack_gifs_desc': ['Ảnh động kỹ năng của nhân vật', '人形技能动图'],
    'pack_voices': ['Lồng tiếng', '语音'],
    'pack_voices_desc': ['Toàn bộ thoại cá nhân & thoại chiến đấu', '全部个性语音与战斗语音'],
    'pack_files': ['{n} file · {size}', '{n} 个文件 · {size}'],
    'pack_saved': ['Đã lưu {d}/{t}', '已保存 {d}/{t}'],
    'download_selected': ['Tải mục đã chọn', '下载所选'],
    'enter_app': ['Vào app', '进入应用'],
    'downloading_pack': ['Đang tải {pack}: {d}/{t}', '正在下载{pack}：{d}/{t}'],
    'offline_done': ['Đã tải xong các mục đã chọn', '所选内容已下载完成'],
    'offline_status': ['Đã lưu {n} file · {size}', '已缓存 {n} 个文件 · {size}'],
    'clear_offline': ['Xoá dữ liệu offline', '清除离线数据'],
    'clear_offline_confirm': ['Xoá toàn bộ ảnh và lồng tiếng đã lưu trên máy?', '确定清除本地全部图片与语音缓存？'],

    // ---- video
    'video_loading': ['Đang lấy luồng video…', '正在获取视频…'],
    'video_error': ['Không phát được video trong app.', '无法在应用内播放视频。'],
    'open_bilibili': ['Mở trên Bilibili', '在哔哩哔哩打开'],
    'play_video': ['Xem video', '播放视频'],

    // ---- cài đặt
    'language': ['Ngôn ngữ', '语言'],
    'lang_vi': ['Tiếng Việt', '越南语'],
    'lang_zh': ['Tiếng Trung', '中文'],
    'translation': ['Bản dịch tiếng Việt (GitHub)', '越南语翻译（GitHub）'],
    'repo': ['Repo', '仓库'],
    'branch': ['Nhánh', '分支'],
    'folder': ['Thư mục', '目录'],
    'edit_source': ['Đổi nguồn bản dịch', '修改翻译来源'],
    'check_update': ['Kiểm tra bản dịch mới', '检查翻译更新'],
    'translation_version': ['Phiên bản: {v}', '版本：{v}'],
    'translation_none': ['Chưa có bản dịch trên máy', '本地暂无翻译'],
    'translation_updated': ['Đã cập nhật bản dịch ({n} file)', '翻译已更新（{n}个文件）'],
    'translation_latest': ['Bản dịch đã là mới nhất', '翻译已是最新'],
    'translation_error': ['Lỗi tải bản dịch: {e}', '翻译下载失败：{e}'],
    'syncing': ['Đang đồng bộ…', '同步中…'],
    'wiki_data': ['Dữ liệu gốc (wiki)', '原始数据（Wiki）'],
    'wiki_updated_at': ['Cập nhật lúc {t}', '更新于 {t}'],
    'wiki_counts': ['{d} nhân vật · {w} vũ khí · {s} bài · {m} tư liệu', '{d}人形 · {w}武器 · {s}篇设定 · {m}条资讯'],
    'refresh_wiki': ['Tải lại từ wiki', '从Wiki重新下载'],
    'refresh_wiki_confirm': ['Tải lại toàn bộ dữ liệu gốc từ wiki (~50 MB)?', '从Wiki重新下载全部原始数据（约50MB）？'],
    'pause': ['Tạm dừng', '暂停'],
    'resume': ['Tiếp tục', '继续'],
    'display': ['Hiển thị', '显示'],
    'text_size': ['Cỡ chữ nội dung', '正文字号'],
    'data_folder': ['Thư mục dữ liệu', '数据目录'],
    'open_folder': ['Mở thư mục', '打开目录'],
    'about': ['Giới thiệu', '关于'],
    'about_text': [
      'Dữ liệu lấy từ wiki chính thức 《少女前线2：追放》 (gf2-bbs.exiliumgf.com). Ứng dụng phi lợi nhuận do người hâm mộ thực hiện.',
      '数据来源：《少女前线2：追放》官方Wiki（gf2-bbs.exiliumgf.com）。本应用为粉丝制作的非盈利项目。'
    ],
    'repo_hint': ['vd: locbem/gf2cn_bot', '例：locbem/gf2cn_bot'],
    'translation_updated_snack': ['Đã cập nhật bản dịch mới', '已更新翻译'],
  };

  static List<String> get keys => table.keys.toList();
}

/// Truy xuất chuỗi theo ngôn ngữ hiện tại.
///
/// Tiếng Việt: ui.json (nếu có)  >  game_dict.json (tra theo nhãn tiếng Trung
/// tương ứng, vd 云图强固, 异位属性)  >  bản dịch có sẵn trong bảng trên.
class S {
  const S(this.lang, [this.overrides = const {}, this.dict]);

  final String lang;
  final Map<String, String> overrides;
  final GameDict? dict;

  bool get isVi => lang == 'vi';

  String t(String key, [Map<String, Object?> args = const {}]) {
    String? text;
    if (isVi) {
      final o = overrides[key];
      if (o != null && o.trim().isNotEmpty) text = o;
      if (text == null && dict != null) {
        final e = UiStrings.table[key];
        if (e != null && !e[1].contains('{')) text = dict!.label(e[1]);
      }
    }
    if (text == null) {
      final e = UiStrings.table[key];
      text = e == null ? key : (isVi ? e[0] : e[1]);
    }
    if (args.isEmpty) return text;
    var out = text;
    args.forEach((k, v) => out = out.replaceAll('{$k}', '${v ?? ''}'));
    return out;
  }
}
