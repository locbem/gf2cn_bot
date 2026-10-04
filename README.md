# GF2 Wiki (少前2：追放) – app xem wiki offline, tiếng Trung + tiếng Việt

Ứng dụng **Flutter native** (Android + Windows, không dùng WebView) hiển thị dữ liệu
từ wiki chính thức <https://gf2-bbs.exiliumgf.com/wiki/category>, phân mục giống hệt wiki:

| Mục | Tab (lấy từ danh mục wiki) |
|---|---|
| **游戏图鉴 – Đồ giám** | 人形介绍 Nhân vật · 武器介绍 Vũ khí (có lọc thuộc tính / lớp / đội / loại / độ hiếm + tìm kiếm) |
| **世界设定 – Thế giới** | 追放剧情 Cốt truyện · 其他设定 Thiết lập khác |
| **其他资讯 – Tư liệu** | PV nhân vật · PV phiên bản · Radio · Hình nền |

## Bắt đầu nhanh

```powershell
flutter create --platforms=android,windows --org com.locbem --project-name gf2_wiki .
dart run tool/patch_platforms.dart
flutter pub get
flutter run -d windows
```

- Chưa có Flutter? → [docs/INSTALL_FLUTTER.md](docs/INSTALL_FLUTTER.md)

## API wiki

Tất cả là `POST https://gf2-bbs-api.exiliumgf.com<path>` với body JSON:

| Path | Body | Trả về |
|---|---|---|
| `/wiki/category` | `{}` | danh mục: type 1 (世界设定), 2 (其他资讯), 3 (游戏图鉴 + bộ lọc) |
| `/wiki/handbook` | `{type: 1\|2, hero_param, weapon_param}` | danh sách nhân vật / vũ khí |
| `/wiki/hero_detail` | `{id}` | chi tiết nhân vật |
| `/wiki/weapon_detail` | `{id}` | chi tiết vũ khí |
| `/wiki/information` | `{type: 1\|2, cid}` | danh sách bài viết của một tab |
| `/wiki/info_detail` | `{id, type}` | chi tiết bài (chương `catalog` + `catalog_desc`) |

Dữ liệu thuộc về Sunborn / 散爆网络. Đây là dự án phi lợi nhuận.
