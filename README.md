# USB Debugging

App Flutter cho Android 7.0+ (API 24), một màn hình tiếng Việt và một ô Cài đặt nhanh để bật/tắt **gỡ lỗi USB**. Ô nhanh chạy bằng Kotlin `TileService`, không cần mở Flutter hay giữ app chạy thường trực.

## Điều kiện

Android không cho app thông thường tự ghi thiết lập USB debugging. Bản này dùng quyền `android.permission.WRITE_SECURE_SETTINGS`, do người dùng cấp một lần qua ADB từ máy tính. Không cần root. Chỉ khai báo quyền trong manifest hoặc cấp quyền “Thay đổi cài đặt hệ thống” là chưa đủ.

ADB (Android Debug Bridge) là công cụ máy tính giao tiếp với Android. Sau khi cấp quyền thành công, có thể rút cáp và dùng công tắc trên điện thoại. Quyền thường còn sau khi khởi động lại, nhưng gỡ/cài lại app hoặc thay đổi chính sách ROM có thể cần cấp lại.

## Cài trên Xiaomi không root

1. Cài APK từ `build/app/outputs/flutter-apk/app-release.apk` (hoặc bản debug nếu tự build).
2. Vào **Cài đặt → Giới thiệu điện thoại**, chạm nhiều lần vào phiên bản MIUI/OS để bật Tùy chọn nhà phát triển. Tên mục có thể khác theo ROM.
3. Vào **Cài đặt bổ sung → Tùy chọn nhà phát triển**, bật công tắc tổng và **USB debugging / Gỡ lỗi USB**.
4. Tải và giải nén [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) trên máy tính. Nếu đã cài Android Studio, dùng `adb` trong thư mục SDK `platform-tools`.
5. Cắm cáp USB truyền dữ liệu. Mở khóa điện thoại và chấp nhận hộp thoại cho phép máy tính gỡ lỗi.
6. Mở PowerShell tại thư mục Platform-Tools:

```powershell
.\adb.exe devices
.\adb.exe shell pm grant dev.usbtoggle.app_usb android.permission.WRITE_SECURE_SETTINGS
```

Dòng thiết bị phải hiện `device`. `unauthorized` nghĩa là chưa chấp nhận hộp thoại trên điện thoại; danh sách trống thường do cáp, cổng hoặc driver USB.

Nếu `pm grant` báo `SecurityException`/`not allowed`, kiểm tra **USB debugging (Security settings) / Gỡ lỗi USB (Cài đặt bảo mật)** trong Tùy chọn nhà phát triển. Một số bản MIUI/HyperOS có mục này và có thể yêu cầu tài khoản Xiaomi. Không cần mở khóa bootloader. Nếu ROM vẫn chặn cấp quyền thì bản này không thể bật/tắt trực tiếp trên ROM đó.

7. Mở app, nhấn nút **Đọc lại trạng thái** ở góc phải. Công tắc chỉ hoạt động khi đã có quyền.
8. Nhấn **Thêm vào Cài đặt nhanh** và đồng ý với hộp thoại Android (Android 13+). Nếu không có hộp thoại hoặc ROM không hỗ trợ: mở bảng Cài đặt nhanh/Trung tâm điều khiển → **Sửa** → kéo ô **USB debugging** vào vùng hiển thị. Với kiểu Trung tâm điều khiển mới của Xiaomi, thường vuốt từ góc trên bên phải.

Ô có màu khi đang bật, không màu khi đang tắt. Chưa có quyền thì chạm ô sẽ mở hướng dẫn trong app. Khi điện thoại đang khóa, ô yêu cầu mở khóa trước khi thay đổi.

## Lưu ý sử dụng

- Tắt USB debugging sẽ ngắt kết nối ADB qua USB, kể cả `flutter run`. Đây là hành vi mong đợi. Sau khi cấp quyền, bật lại bằng ô nhanh không cần phiên ADB đang kết nối.
- App chỉ đổi `Settings.Global.ADB_ENABLED`. Không tắt/bật Wireless debugging hay công tắc tổng Tùy chọn nhà phát triển. Cần giữ công tắc tổng bật để bật lại USB debugging bằng app.
- Chỉ chấp nhận khóa gỡ lỗi từ máy tính tin cậy. Quyền WRITE_SECURE_SETTINGS có phạm vi rộng; mã app chỉ sử dụng nó cho USB debugging.
- Không có quyền mạng trong manifest bản release, tài khoản, quảng cáo hoặc thu thập dữ liệu. Bản debug có quyền mạng cho công cụ Flutter.
- Bản release hiện ký bằng khóa debug mặc định để cài thử cá nhân. Trước khi phân phối chính thức cần cấu hình khóa ký riêng.

Thu hồi quyền (bật lại USB debugging bằng Cài đặt và kết nối máy tính trước):

```powershell
.\adb.exe shell pm revoke dev.usbtoggle.app_usb android.permission.WRITE_SECURE_SETTINGS
```

## Phát triển

Dự án được tạo và kiểm tra bằng Flutter 3.41.6 / Dart 3.11.4. Android SDK theo cấu hình Flutter, minSdk 24; Android Studio dùng JDK 17 trở lên (máy phát triển hiện dùng JDK 21).

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

- `lib/main.dart`: giao diện, hướng dẫn và MethodChannel `dev.usbtoggle/usb_debugging`.
- `android/app/src/main/kotlin/dev/usbtoggle/app_usb/UsbDebugging.kt`: đọc trạng thái, kiểm tra quyền và ghi thiết lập dùng chung.
- `MainActivity.kt`: bridge Flutter/Android và yêu cầu thêm ô.
- `UsbDebuggingTileService.kt`: ô Cài đặt nhanh, mở khóa, theo dõi thay đổi khi ô hiển thị.
- `test/widget_test.dart`: kiểm thử Flutter với Android channel giả lập; không thay thế kiểm thử phần cứng/ROM.

## Kiểm tra trên máy thật

1. Khi chưa cấp quyền, công tắc bị khóa; chạm ô mở hướng dẫn, không làm app lỗi.
2. Cấp quyền, quay về app: đọc đúng trạng thái; bật và tắt bằng app.
3. Thêm ô, đóng app, bật/tắt từ bảng nhanh; kiểm tra lại trạng thái trong Tùy chọn nhà phát triển.
4. Đổi trạng thái trong Cài đặt, mở lại bảng nhanh: ô phản ánh đúng trạng thái.
5. Khóa màn hình, chạm ô: chỉ thay đổi sau khi mở khóa thành công.
6. Thu hồi quyền: app hiện hướng dẫn; ô không báo bật/tắt thành công giả.
7. Khởi động lại điện thoại rồi thử ô khi không nối máy tính.

Tài liệu nền tảng: [Quick Settings tiles](https://developer.android.com/develop/ui/views/quicksettings-tiles), [Settings.Global](https://developer.android.com/reference/android/provider/Settings.Global), [WRITE_SECURE_SETTINGS](https://developer.android.com/reference/android/Manifest.permission#WRITE_SECURE_SETTINGS), [ADB](https://developer.android.com/tools/adb).
