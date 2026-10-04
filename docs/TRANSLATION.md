# Dịch dữ liệu sang tiếng Việt

App đọc dữ liệu theo 2 lớp:

1. **Bản gốc tiếng Trung** – app tự tải từ wiki lần đầu mở (lưu trên máy).
2. **Bản dịch tiếng Việt** – app tải từ GitHub:
   `https://raw.githubusercontent.com/locbem/gf2cn_bot/main/data/vi/…`
   (đổi được trong *Cài đặt → Bản dịch tiếng Việt*).

Khi chọn tiếng Việt, app **gộp** bản dịch lên bản gốc: chỗ nào đã dịch thì hiện
tiếng Việt, chỗ nào chưa dịch (thiếu file, thiếu trường, chuỗi rỗng) thì tự hiện
tiếng Trung. Vì vậy bạn có thể **dịch dần từng phần**, push lúc nào cũng được.

## Từ điển thuật ngữ `game_dict.json` (xương sống bản tiếng Việt)

File `data/vi/game_dict.json` dịch tự động các phần "khung" của app khi chọn
tiếng Việt – **không cần dịch tay từng file**:

| Phần | Bảng trong từ điển |
|---|---|
| Tên mục, tab (游戏图鉴, 人形介绍…) | `CATEGORY_VI` |
| Bộ lọc & lựa chọn (thuộc tính, nghề nghiệp, đội, loại, độ hiếm) | `*_ID_MAP` (theo id), `ATTR_MAP`, `ROLE_MAP`… |
| Tên nhân vật, vũ khí, trang phục | `CHAR_NAME`, `WEAPON_NAME`, `COSTUME_NAME` |
| Đội, nghề nghiệp, thuộc tính, độ hiếm, loại vũ khí của nhân vật | `TEAM_MAP`, `ROLE_MAP`, `ATTR_MAP`, `RARITY_MAP`, `WEAPON_TYPE_MAP` |
| Tiêu đề bài, PV, radio, tên chương (上篇/下篇) | `STORY_TITLE_MAP`, `SKILL_TERM_MAP` |
| Nhãn trong bảng HTML (攻击：, 显像形态, 胚胎…) và tên người nói trong truyện | `STAT_LABELS`, `REMOULD_*`, `CHAR_NAME`… |
| Tên kỹ năng / khoá (固键1, 好感度共键…), tiêu đề mục trong trang nhân vật (心智螺旋…) | `TERM_MAP`, `SKILL_TERM_MAP` |

Quy tắc:

- Chỉ dịch khi **khớp nguyên cụm** (ô bảng, tên, tiêu đề). Không thay chữ giữa
  câu để tránh câu lai Trung–Việt; câu văn dài vẫn dịch trong các file `data/vi`.
- Tên ghép có dấu `·` (vd `寇尔芙·镜刻`) không có trong từ điển thì dịch từng phần.
- `【X】PV` → `PV <X>`, `…第35期` → `… - Số 35` tự suy ra từ tên đã có.
- Ưu tiên: **file trong data/vi** > **từ điển** > tiếng Trung. File `data/vi` chép
  nguyên từ `data/zh` (chưa sửa) không che bản dịch của từ điển.
- Sửa từ điển → push lên GitHub → app tự tải bản mới (không cần build lại).
  Bản trong `assets/` chỉ là dự phòng cho lần mở đầu tiên khi chưa có mạng.
- Liệt kê tên/tiêu đề chưa có trong từ điển (sau khi `scrape`):

  ```powershell
  dart run tool/gf2data.dart dict-missing
  ```

  Lệnh in ra JSON đúng cấu trúc từ điển với giá trị trống – điền bản dịch rồi gộp vào file.

> Thuật ngữ theo bản quốc tế (đối chiếu [IOP Wiki](https://iopwiki.com/wiki/GFL2_Doll_Enhancement)):
> `云图强固` = **Neural Fortification** (cường hoá bằng bản sao, V1–V6),
> `心智螺旋` = **Neural Helix** (cây 13 nút, khoá Fixed Key). Hai mục này phải khác tên
> để trang nhân vật không bị trùng tiêu đề.

## Quy trình

```powershell
# 1. Tải bản gốc tiếng Trung về data/zh (cần Flutter, xem INSTALL_FLUTTER.md)
dart run tool/gf2data.dart scrape data/zh

# 2. Chép sang data/vi những file chưa có (không ghi đè file đã dịch)
dart run tool/gf2data.dart init-vi

# 3. Mở các file trong data/vi và dịch (VS Code / Notepad++ ...)

# 4. Đóng gói: sinh lại danh sách + manifest.json
dart run tool/gf2data.dart pack data/vi

# 5. Xem tiến độ
dart run tool/gf2data.dart status

# 6. Đẩy lên GitHub
git add data
git commit -m "Dịch nhân vật X"
git push
```

> Quên bước 4 cũng không sao: workflow `.github/workflows/pack-translation.yml`
> tự chạy `pack` mỗi khi bạn push thay đổi trong `data/vi` (kể cả sửa trực tiếp
> trên web GitHub) và commit lại manifest.

App tự kiểm tra bản dịch mới mỗi ~3 giờ khi mở, hoặc bấm
*Cài đặt → Kiểm tra bản dịch mới*. Chỉ những file có thay đổi (so md5 trong
`manifest.json`) mới được tải lại.

Khi wiki có nhân vật/bài mới: chạy lại bước 1 (`scrape`), rồi `init-vi` để chép
riêng các file mới sang `data/vi`. `git diff data/zh` cho biết bản gốc thay đổi gì.

## Cấu trúc thư mục dữ liệu

```
data/vi/
  manifest.json        ← KHÔNG sửa tay (do lệnh pack sinh ra)
  category.json        tên mục, tab, bộ lọc (thuộc tính, lớp, đội, loại vũ khí...)
  dolls.json           ← tự sinh từ dolls/*.json khi pack
  dolls/<id>.json      chi tiết 1 nhân vật
  weapons.json         toàn bộ vũ khí
  world.json           ← tự sinh từ world/*.json khi pack
  world/<id>.json      1 bài "Thiết lập thế giới" (cốt truyện theo chương)
  media.json           PV nhân vật, PV phiên bản, radio, hình nền
  ui.json              (tuỳ chọn) đổi nhãn giao diện, vd {"tab_growth": "Nuôi dưỡng"}
```

Tạo `ui.json` mẫu đầy đủ các nhãn: `dart run tool/gf2data.dart ui-template`.

## Nguyên tắc khi dịch

- **Chỉ dịch giá trị chữ**, giữ nguyên tên trường (`"name"`, `"html"`...),
  `id`, `cid`, đường dẫn ảnh (`https://…png`), số liệu.
- Có thể **xoá bớt** trường không cần dịch – app tự lấy từ bản gốc.
  Ví dụ một file nhân vật chỉ dịch tên và giới thiệu:

  ```json
  {
    "id": 1084,
    "name": "Colphne Doppelganger",
    "desc": "Sau khi nhận được thân thể “Doppelgänger” từ Sangvis…"
  }
  ```

- Danh sách **có `id`** (lồng tiếng `voices`, tuỳ chọn bộ lọc `options`…) được
  ghép theo `id` → có thể chỉ giữ những mục đã dịch.
- Danh sách **không có `id`** (kỹ năng `skills`, quà `gifts`, chương `chapters`,
  đoạn `parts`…) được ghép theo **vị trí** → hãy giữ **đủ số phần tử và đúng thứ
  tự**; mục chưa dịch để `""` hoặc giữ nguyên tiếng Trung.
- Trường `html`: giữ nguyên thẻ HTML (`<p>`, `<table>`, `<span style="color: …">`),
  chỉ dịch phần chữ giữa các thẻ.
- `dolls.json` và `world.json` được sinh lại khi `pack` → dịch trong file chi tiết
  (`dolls/<id>.json`, `world/<id>.json`) là đủ.

## Trường dữ liệu chính

### dolls/<id>.json

| Trường | Ý nghĩa (mục trên wiki) |
|---|---|
| `name`, `en_name`, `desc` | Tên, tên tiếng Anh, giới thiệu |
| `rarity`, `role`, `attr`, `team`, `weapon`, `model`, `ammo_model` | Độ hiếm, lớp, thuộc tính, đội, vũ khí ấn ký, mẫu thân thể, loại vũ khí |
| `cv` | 其他信息 (diễn viên lồng tiếng) |
| `prop` | 基础属性统计 (chỉ số Lv.60) |
| `skills[]` | 技能 – kỹ năng `{name, html}` |
| `battle_skill` | 云图强固 |
| `talents[]` | 心智螺旋 |
| `remoulding` | 拟态图谱 |
| `weapon_desc` | 烙印武器 |
| `development` | 攻略集锦 |
| `story` | 角色故事 |
| `gifts[]` | 好感度礼物 |
| `gallery[]` | 图册 |
| `voices[]`, `battle_voices[]` | 个性语音 / 战斗语音 `{id, title, text, url}` |
| `skins[]` | trang phục `{id, name, pc, mobile}` |

### weapons.json → `items[]`

`{id, name, pic, type, rarity, belong_hero, base_info (属性), character (调校)}`

### world/<id>.json

`{id, cid, title, cover, chapters: [{name, parts: [{name, html}]}]}`
(`cid` 1 = 追放剧情, 2 = 其他设定)

### media.json → `items[]`

`{id, cid, title, cover, html}`
(`cid` 1 = PV nhân vật, 2 = PV phiên bản, 3 = radio, 4 = hình nền)
