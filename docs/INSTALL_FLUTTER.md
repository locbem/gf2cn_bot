# Cài Flutter trên Windows để build GF2 Wiki

> Nếu bạn **không muốn cài gì**, chỉ cần push code lên GitHub: workflow
> `.github/workflows/build.yml` sẽ tự build APK + bản Windows (xem cuối file).

## 1. Cài các công cụ cần thiết

| Công cụ | Dùng để | Tải ở đâu |
|---|---|---|
| **Git for Windows** | tải code, push lên GitHub | https://git-scm.com/download/win |
| **Flutter SDK** (stable) | build app | https://docs.flutter.dev/get-started/install/windows |
| **Visual Studio 2022 Community** – workload *Desktop development with C++* | build bản Windows (.exe) | https://visualstudio.microsoft.com/downloads/ |
| **Android Studio** | build APK Android | https://developer.android.com/studio |

### Flutter SDK

1. Tải file zip Flutter **stable** mới nhất cho Windows ở trang cài đặt chính thức.
2. Giải nén vào một thư mục **không có dấu cách / không cần quyền admin**, ví dụ `C:\src\flutter`
   (đừng để trong `C:\Program Files`).
3. Thêm `C:\src\flutter\bin` vào biến môi trường **Path**:
   - Start → gõ *"environment variables"* → *Edit environment variables for your account*
   - Chọn `Path` → *Edit* → *New* → dán `C:\src\flutter\bin` → OK.
4. Mở **PowerShell mới** và kiểm tra:

   ```powershell
   flutter --version
   flutter doctor
   ```

### Bật Developer Mode của Windows

Plugin Flutter cần quyền tạo symlink:

```powershell
start ms-settings:developers
```

Bật **Developer Mode**.

### Visual Studio (cho bản Windows)

Khi cài Visual Studio 2022 Community, tick workload **"Desktop development with C++"**
(giữ các thành phần mặc định). *Lưu ý: đây là Visual Studio, không phải VS Code.*

### Android Studio (cho bản Android)

1. Cài Android Studio, mở lên lần đầu và để nó tải Android SDK.
2. Vào **More Actions → SDK Manager → SDK Tools**, tick **Android SDK Command-line Tools** → Apply.
3. Chấp nhận giấy phép:

   ```powershell
   flutter doctor --android-licenses
   ```

Chạy lại `flutter doctor` – các mục *Flutter*, *Windows Version*, *Android toolchain*,
*Visual Studio* cần có dấu ✓ (mục Chrome/Web không cần).

## 2. Lấy code và tạo thư mục nền tảng

```powershell
cd C:\src
git clone https://github.com/locbem/gf2cn_bot.git gf2_wiki
cd gf2_wiki

# Tạo thư mục android/ và windows/ (chỉ cần làm 1 lần)
flutter create --platforms=android,windows --org com.locbem --project-name gf2_wiki .
dart run tool/patch_platforms.dart

flutter pub get
```

`patch_platforms.dart` thêm quyền Internet cho Android, đặt tên/icon app,
màu nền khởi động, tiêu đề cửa sổ Windows.

## 3. Chạy thử

```powershell
flutter run -d windows        # chạy bản Windows
flutter devices               # xem điện thoại Android đang cắm (bật USB debugging)
flutter run -d <id-thiết-bị>  # chạy trên điện thoại
```

Trong lúc chạy, nhấn `r` để hot reload, `q` để thoát.

## 4. Build bản phát hành

```powershell
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk  (copy vào điện thoại để cài)

flutter build windows --release
# → build\windows\x64\runner\Release\   (nén cả thư mục này để chia sẻ; chạy gf2_wiki.exe)
```

## 5. Không muốn cài? Dùng GitHub Actions

1. Push code lên GitHub (nhánh `main`).
2. Vào tab **Actions** của repo → workflow **Build GF2 Wiki** sẽ tự chạy
   (hoặc bấm **Run workflow**).
3. Chạy xong (~10 phút), mở lần chạy đó → mục **Artifacts** có
   `gf2-wiki-android` (APK) và `gf2-wiki-windows` (thư mục exe) để tải về.

## Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `flutter` is not recognized | Chưa thêm `flutter\bin` vào Path, hoặc chưa mở PowerShell mới. |
| `Building with plugins requires symlink support` | Bật Developer Mode (bước trên). |
| `Unable to find suitable Visual Studio toolchain` | Cài workload *Desktop development with C++*. |
| `Android license status unknown` | Chạy `flutter doctor --android-licenses`, nhấn `y`. |
| Gradle tải lâu lần đầu | Bình thường, lần đầu build APK mất 5–10 phút. |
| Lỗi phụ thuộc khi `pub get` | Chạy `flutter upgrade` rồi `flutter pub upgrade`. |
