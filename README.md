# USB Debugging

App Flutter cho Android 7.0+ (API 24), một màn hình tiếng Việt và các ô Cài đặt nhanh để bật/tắt **gỡ lỗi USB** và chuyển **DNS riêng tư ↔ Tự động** (Android 9+). Thêm nút **Dọn cache hàng loạt** qua Shizuku (Android 8+). Các ô chạy bằng Kotlin `TileService`, không cần mở Flutter hay giữ app chạy thường trực.

## Điều kiện

Android không cho app thông thường tự ghi thiết lập USB debugging. Bản này dùng quyền `android.permission.WRITE_SECURE_SETTINGS`, do người dùng cấp một lần qua ADB từ máy tính. Không cần root. Chỉ khai báo quyền trong manifest hoặc cấp quyền “Thay đổi cài đặt hệ thống” là chưa đủ.

ADB (Android Debug Bridge) là công cụ máy tính giao tiếp với Android. Sau khi cấp quyền thành công, có thể rút cáp và dùng công tắc trên điện thoại. Quyền thường còn sau khi khởi động lại, nhưng gỡ/cài lại app hoặc thay đổi chính sách ROM có thể cần cấp lại.

## Cài trên Xiaomi không root

1. Cài APK từ `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` cho Xiaomi dùng Android 64 bit. Nếu máy dùng Android 32 bit, chọn `app-armeabi-v7a-release.apk`. Bản `app-release.apk` hỗ trợ tất cả kiến trúc nhưng dung lượng lớn hơn.
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
- Phần USB chỉ đổi `Settings.Global.ADB_ENABLED`. Không tắt/bật Wireless debugging hay công tắc tổng Tùy chọn nhà phát triển. Cần giữ công tắc tổng bật để bật lại USB debugging bằng app.
- Chỉ chấp nhận khóa gỡ lỗi từ máy tính tin cậy. Quyền WRITE_SECURE_SETTINGS có phạm vi rộng; app sử dụng nó cho USB debugging và chế độ DNS riêng tư.
- Không có quyền mạng trong manifest bản release, tài khoản, quảng cáo hoặc thu thập dữ liệu. Bản debug có quyền mạng cho công cụ Flutter.
- Bản release hiện ký bằng khóa debug mặc định để cài thử cá nhân. Trước khi phân phối chính thức cần cấu hình khóa ký riêng.

Thu hồi quyền (bật lại USB debugging bằng Cài đặt và kết nối máy tính trước):

```powershell
.\adb.exe shell pm revoke dev.usbtoggle.app_usb android.permission.WRITE_SECURE_SETTINGS
```

## Chuyển nhanh DNS riêng tư (từ Android 9)

1. Cài đè APK mới, giữ lại quyền ADB đã cấp. Không cần root hay thêm quyền mới.
2. Cấu hình tên máy chủ một lần trong **Cài đặt kết nối → DNS riêng tư → Tên máy chủ nhà cung cấp DNS riêng tư**. App đọc lại tên máy chủ đang lưu trong Android, không tự chọn nhà cung cấp. Nút **Cài đặt DNS** mở trang cài đặt kết nối của hệ thống.
3. Trong app, công tắc **DNS riêng tư** bật là dùng tên máy chủ đã cấu hình; tắt là chuyển về **Tự động**. Tên máy chủ vẫn được giữ lại để bật lại nhanh. Khi chưa có tên máy chủ, công tắc không cho bật và hiển thị hướng dẫn cấu hình.
4. Thêm ô **DNS riêng tư** từ nút **Thêm ô DNS riêng tư**, hoặc **Trung tâm điều khiển → Sửa** trên Xiaomi/Android 12. Chạm ô để chuyển hai chiều. Máy khóa cần mở khóa trước; thiếu quyền hoặc tên máy chủ thì ô mở app.

App chỉ ghi `private_dns_mode` (`opportunistic` ↔ `hostname`), không ghi hoặc xóa `private_dns_specifier`. Nếu DNS đang ở chế độ **Tắt** từ Cài đặt Android, app hiển thị đúng trạng thái đó; lần bật tiếp theo chuyển sang máy chủ riêng tư, lần tắt sau đó về Tự động.

Trạng thái trong app/ô phản ánh cấu hình, không xác nhận kết nối DNS đã thành công. Tên máy chủ không hoạt động hoặc mạng chặn DNS-over-TLS có thể khiến mạng không phân giải được tên miền; chuyển về Tự động để khôi phục việc phân giải qua mạng. Android 7/8 vẫn dùng được phần USB, không có ô DNS.

Tham chiếu AOSP: [Settings.Global và tên máy chủ được giữ khi đổi chế độ](https://android.googlesource.com/platform/frameworks/base/+/6d408b5bf20431ac41ed039f2ad192b150c02eff/core/java/android/provider/Settings.java), [các chế độ và giá trị mặc định của Private DNS](https://android.googlesource.com/platform/frameworks/libs/net/+/8ef52686483cdff0040d22753bb516e99a96a88d/common/framework/com/android/net/module/util/ConnectivitySettingsUtils.java).

## Phát triển

Android Build-Tools 36.1.0 được dùng để tránh lỗi AIDL sinh chú thích chứa đường dẫn Windows chưa escape (`illegal unicode escape`) ở các bản cũ.

Dự án được tạo và kiểm tra bằng Flutter 3.41.6 / Dart 3.11.4. Android SDK theo cấu hình Flutter, minSdk 24; Android Studio dùng JDK 17 trở lên (máy phát triển hiện dùng JDK 21).

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build apk --release --split-per-abi
flutter build apk --release --split-per-abi
```

- `lib/main.dart`: giao diện, hướng dẫn và MethodChannel `dev.usbtoggle/usb_debugging`.
- `android/app/src/main/kotlin/dev/usbtoggle/app_usb/UsbDebugging.kt`: đọc trạng thái, kiểm tra quyền và ghi thiết lập dùng chung.
- `MainActivity.kt`: bridge Flutter/Android và yêu cầu thêm ô.
- `UsbDebuggingTileService.kt`: ô Cài đặt nhanh, mở khóa, theo dõi thay đổi khi ô hiển thị.
- `PrivateDns.kt`, `PrivateDnsTileService.kt`: dùng chung điều khiển DNS giữa app và ô nhanh, giữ nguyên tên máy chủ, quan sát thay đổi chế độ và tên máy chủ.
- `test/widget_test.dart`: kiểm thử Flutter với Android channel giả lập; không thay thế kiểm thử phần cứng/ROM.
- `lib/cache_cleaner_card.dart`, `CacheCleaner.kt`, `CacheTrimService.kt`, `ICacheTrimmer.aidl`: giao diện và UserService Shizuku cho dọn cache; `test/cache_cleaner_test.dart` kiểm tra luồng quyền, lỗi, timeout và chống nhấn lặp.

## Dọn cache qua Shizuku

1. Cài [Shizuku chính thức](https://shizuku.rikka.app/download/) và mở app này. Với Android 11+, có thể khởi động bằng Gỡ lỗi không dây theo hướng dẫn của Shizuku; hoặc dùng lệnh ADB do chính Shizuku hiển thị khi nối máy tính.
2. Trong app USB Debugging, cuộn tới **Dọn cache**, nhấn **Kiểm tra Shizuku**, rồi **Cấp quyền Shizuku** và cho phép trong hộp thoại. Quyền WRITE_SECURE_SETTINGS trước đó không thay thế quyền Shizuku.
3. Nhấn **Dọn cache hàng loạt**. Chỉ thao tác này mới dọn; không tự dọn sau khi cấp quyền và không chạy định kỳ.

Tính năng gọi lệnh cố định `pm trim-caches 9223372036854775807 internal` trong UserService chạy dưới danh tính ADB/root của Shizuku. Nó yêu cầu Android dọn cache trên bộ nhớ trong ở mức tối đa hệ thống cho phép. Không dùng `pm clear` (lệnh xóa dữ liệu app), không xóa ảnh/tài liệu, không force-stop từng ứng dụng. Cache được dọn có thể phải tải lại; một số app giữ cache được bảo vệ hoặc tạo lại cache ngay.

Kết quả hiển thị mã lỗi hoặc kết quả yêu cầu và chênh lệch dung lượng trống ước tính. Không có số app “đã xóa sạch” vì Android không cung cấp bằng chứng đó qua lệnh này. Nếu hết thời gian chờ, hệ thống có thể vẫn tiếp tục xử lý yêu cầu đã nhận; không bấm liên tục.

Shizuku trên máy không root cần được khởi động lại sau khi reboot. Tắt gỡ lỗi hoặc chính sách nền của MIUI cũng có thể làm dịch vụ dừng; app sẽ yêu cầu kết nối lại. Phần USB/DNS vẫn hoạt động khi không có Shizuku.

Tham chiếu: [Shizuku API/UserService](https://github.com/RikkaApps/Shizuku-API), [mã nguồn lệnh Android 12](https://github.com/aosp-mirror/platform_frameworks_base/blob/android12-release/services/core/java/com/android/server/pm/PackageManagerShellCommand.java).

APK ARM64 nhỏ hơn nằm ở `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Máy Xiaomi M2007J20CG được nhận diện trong phiên phát triển dùng Android 12 / API 31 / ARM64, nên dùng bản này. Trên Android 12, thêm ô bằng nút **Sửa** trong bảng Cài đặt nhanh; hộp thoại thêm tự động chỉ có từ Android 13.

## Kết quả kiểm tra trong phiên phát triển

- Bản 1.2.0: `flutter analyze` không có vấn đề; 22/22 kiểm thử đạt. Đã thử thật trên máy ảo Android 16: khởi động Shizuku bằng ADB, cấp quyền qua hộp thoại, chạy UserService dọn cache thành công, hiển thị kết quả không khẳng định xóa sạch; dịch vụ dọn đã kết thúc sau khi chạy. Máy ảo không ghi nhận dung lượng trống tăng trong lần thử này. Chưa dọn cache trên Xiaomi thật.

- Bản 1.1.0: `flutter analyze` không có vấn đề; `flutter test` đạt 15/15, gồm đổi DNS hai chiều, giữ tên máy chủ, thiếu/thu hồi quyền, thiếu tên máy chủ, Android cũ, đọc lại thay đổi từ hệ thống và xóa trạng thái DNS cũ khi đọc lỗi.
- Đã kiểm tra test bắt được lỗi khi bỏ điều kiện kiểm tra quyền, sau đó khôi phục mã và chạy lại toàn bộ test thành công.
- Build debug, release và release tách ABI thành công; chữ ký APK ARM64 hợp lệ.
- Máy ảo Android 16: cài và mở APK release thành công; công tắc bị khóa khi chưa có quyền; nút thêm ô mở hộp thoại Android; chạm ô khi thiếu quyền mở app thành công.
- Sau khi cấp quyền trên máy ảo, công tắc khả dụng và đang bật. Chạm tắt làm ADB của máy ảo chuyển sang offline, khiến các bước tự động bật lại/kiểm tra ô tiếp theo không thực hiện được. Chưa xác minh đầy đủ bật/tắt hai chiều và khóa màn hình trên Android thực.
- Quyền WRITE_SECURE_SETTINGS đã được xác nhận `granted=true` trên Xiaomi thật. Các kết quả máy ảo nêu trên thuộc bản USB trước khi thêm DNS.
- Bản DNS 1.1.0 đã được cài và kiểm tra trên Xiaomi Android 12: chuyển hai chiều bằng công tắc Flutter và ô Cài đặt nhanh thành công; tên máy chủ được giữ nguyên, USB debugging giữ nguyên, DNS đã được trả về cấu hình ban đầu. Chưa thử ô DNS khi khóa màn hình hoặc trên Android 7/8/13 trở lên.

## Kiểm tra trên máy thật

1. Khi chưa cấp quyền, công tắc bị khóa; chạm ô mở hướng dẫn, không làm app lỗi.
2. Cấp quyền, quay về app: đọc đúng trạng thái; bật và tắt bằng app.
3. Thêm ô, đóng app, bật/tắt từ bảng nhanh; kiểm tra lại trạng thái trong Tùy chọn nhà phát triển.
4. Đổi trạng thái trong Cài đặt, mở lại bảng nhanh: ô phản ánh đúng trạng thái.
5. Khóa màn hình, chạm ô: chỉ thay đổi sau khi mở khóa thành công.
6. Thu hồi quyền: app hiện hướng dẫn; ô không báo bật/tắt thành công giả.
7. Khởi động lại điện thoại rồi thử ô khi không nối máy tính.

Tài liệu nền tảng: [Quick Settings tiles](https://developer.android.com/develop/ui/views/quicksettings-tiles), [Settings.Global](https://developer.android.com/reference/android/provider/Settings.Global), [WRITE_SECURE_SETTINGS](https://developer.android.com/reference/android/Manifest.permission#WRITE_SECURE_SETTINGS), [ADB](https://developer.android.com/tools/adb).
