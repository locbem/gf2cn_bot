# GF2 Wiki (少前2：追放) – app xem wiki offline, tiếng Trung + tiếng Việt

Ứng dụng **Flutter native** (Android + Windows, không dùng WebView) hiển thị dữ liệu
từ wiki chính thức <https://gf2-bbs.exiliumgf.com/wiki/category>, phân mục giống hệt wiki:

| Mục | Tab (lấy từ danh mục wiki) |
|---|---|
| **游戏图鉴 – Đồ giám** | 人形介绍 Nhân vật · 武器介绍 Vũ khí (có lọc thuộc tính / lớp / đội / loại / độ hiếm + tìm kiếm) |
| **世界设定 – Thế giới** | 追放剧情 Cốt truyện · 其他设定 Thiết lập khác (trình đọc theo chương, nhớ chỗ đọc) |
| **其他资讯 – Tư liệu** | PV nhân vật · PV phiên bản · Radio · Hình nền |

## Tính năng

- **Lần đầu mở app**: tự tải toàn bộ dữ liệu gốc từ API wiki (~50 MB, chạy trong
  isolate nền nên giao diện không giật), làm sạch HTML và lưu thành JSON trên máy.
- **2 ngôn ngữ**: chuyển nhanh VI ⇄ 中 ở góc trên. Bản tiếng Việt tải từ GitHub
  (`data/vi` trong repo này), phần chưa dịch tự hiện tiếng Trung.
- **Từ điển thuật ngữ** (`data/vi/game_dict.json`): tên nhân vật, vũ khí, trang phục,
  đội, bộ lọc, tiêu đề bài, nhãn trong bảng… tự hiện tiếng Việt theo từ điển.
- **Tải offline theo gói** (chọn được): ảnh cơ bản (~200 MB), ảnh chi tiết (~2,4 GB),
  ảnh động GIF (~800 MB), lồng tiếng (~1,5 GB). Chạy nền, tạm dừng được.
  Ảnh/GIF/voice nào đã xem, đã nghe đều tự lưu lại.
- Trang nhân vật giống wiki: Hồ sơ · Bồi dưỡng · Tư liệu · Lồng tiếng
  (phát voice), xem ảnh toàn màn hình (zoom, vuốt).
- **Xem PV ngay trong app** bằng trình phát native (media_kit/libmpv, có toàn màn hình),
  phát trực tiếp từ Bilibili, không lưu video xuống máy, không dùng WebView.
- Giao diện tối, bố cục tự đổi: điện thoại (thanh dưới) / Windows (thanh bên, 2 cột).
- Tìm kiếm toàn bộ, chỉnh cỡ chữ, cập nhật lại dữ liệu wiki, đổi nguồn bản dịch.

## Bắt đầu nhanh

```powershell
flutter create --platforms=android,windows --org com.locbem --project-name gf2_wiki .
dart run tool/patch_platforms.dart
flutter pub get
flutter run -d windows
```

- Chưa có Flutter? → [docs/INSTALL_FLUTTER.md](docs/INSTALL_FLUTTER.md)
  (hoặc chỉ cần push lên GitHub, Actions tự build APK + Windows).
- Dịch dữ liệu → [docs/TRANSLATION.md](docs/TRANSLATION.md)

## Cấu trúc project

```
lib/
  config.dart                 repo GitHub mặc định, URL API
  core/                       HTTP (retry), làm sạch HTML, gộp JSON, cache file
  data/
    wiki_api.dart             các endpoint wiki (POST /wiki/category, handbook, hero_detail…)
    normalize.dart            API thô → JSON chuẩn của app (= format bạn dịch)
    scraper.dart              tải toàn bộ wiki (thuần Dart, dùng chung cho app & tool)
    scrape_runner.dart        chạy scraper trong isolate nền
    translation_sync.dart     đồng bộ data/vi từ GitHub theo manifest (md5)
    repository.dart           đọc dữ liệu + gộp bản dịch
  state/                      AppController, tải ảnh hàng loạt, trình phát voice
  l10n/strings.dart           nhãn giao diện vi/zh (ghi đè được bằng data/vi/ui.json)
  ui/                         theme, màn hình, widget (HTML render native)
tool/
  gf2data.dart                scrape / init-vi / pack / status / ui-template
  patch_platforms.dart        chỉnh AndroidManifest, icon, tiêu đề cửa sổ
data/
  vi/                         bản dịch tiếng Việt (app tải từ đây)
  zh/                         (tuỳ chọn) bản gốc do lệnh scrape tạo, để đối chiếu khi dịch
.github/workflows/
  build.yml                   build APK + Windows
  pack-translation.yml        tự pack manifest khi data/vi thay đổi
```

## API wiki (đã khảo sát)

Tất cả là `POST https://gf2-bbs-api.exiliumgf.com<path>` với body JSON:

| Path | Body | Trả về |
|---|---|---|
| `/wiki/category` | `{}` | danh mục: type 1 (世界设定), 2 (其他资讯), 3 (游戏图鉴 + bộ lọc) |
| `/wiki/handbook` | `{type: 1\|2, hero_param, weapon_param}` | danh sách nhân vật / vũ khí |
| `/wiki/hero_detail` | `{id}` | chi tiết nhân vật |
| `/wiki/weapon_detail` | `{id}` | chi tiết vũ khí |
| `/wiki/information` | `{type: 1\|2, cid}` | danh sách bài viết của một tab |
| `/wiki/info_detail` | `{id, type}` | chi tiết bài (chương `catalog` + `catalog_desc`) |

Dữ liệu thuộc về Sunborn / 散爆网络. Đây là dự án phi lợi nhuận của người hâm mộ.
