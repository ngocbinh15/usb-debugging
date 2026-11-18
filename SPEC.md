# USB Debugging — Android

Một app Flutter nhỏ, giao diện tiếng Việt, bật/tắt USB debugging và chuyển DNS riêng tư bằng các ô Cài đặt nhanh; thêm nút dọn cache hàng loạt qua Shizuku. Android tối thiểu 7.0 (API 24); DNS riêng tư yêu cầu Android 9 (API 28), dọn cache yêu cầu Android 8 (API 26).

## Hành vi

- Đọc trạng thái thật từ Android; không lưu trạng thái giả trong Flutter.
- App và TileService dùng chung bộ điều khiển Kotlin qua Settings.Global.ADB_ENABLED.
- Chỉ ghi sau khi người dùng chủ động bấm và có WRITE_SECURE_SETTINGS; không tự bật khi mở app hay khởi động máy.
- Chưa có quyền: vô hiệu hóa công tắc, hướng dẫn lệnh ADB, ô nhanh mở app để hướng dẫn.
- Ô nhanh yêu cầu mở khóa trước khi đổi trạng thái; theo dõi thay đổi khi hiển thị.
- Android 13 trở lên: nút yêu cầu thêm ô bằng API hệ thống. Bản cũ hướng dẫn thêm bằng trình sửa ô.
- Chỉ thay đổi USB debugging; không đổi Wireless debugging hay công tắc tổng Tùy chọn nhà phát triển.
- DNS: chuyển `private_dns_mode` giữa `opportunistic` (Tự động) và `hostname` (máy chủ riêng tư đã cấu hình); giữ nguyên `private_dns_specifier`, không tự chọn nhà cung cấp.
- Tên máy chủ được cấu hình trong Cài đặt Android. Chưa có tên máy chủ: hướng dẫn cấu hình trước khi bật. Chế độ `off` từ hệ thống được hiển thị đúng, không gọi nhầm là Tự động.
- Dùng lại WRITE_SECURE_SETTINGS, không thêm quyền hoặc dependency. Ô DNS riêng chỉ có từ API 28, yêu cầu mở khóa và cập nhật khi thiết lập thay đổi.
- Hiển thị cấu hình DNS, không khẳng định kết nối tới máy chủ DNS đã thành công.

## Phạm vi và cấu trúc

`lib/main.dart`: điểm khởi chạy; `lib/app.dart`: cấu hình app. `lib/pages/usb_debugging_page.dart`: màn hình, trạng thái và MethodChannel USB/DNS. `lib/widgets/`: giao diện USB, DNS và hướng dẫn ADB; nhận trạng thái và callback từ màn hình. `lib/cache_cleaner_card.dart`: phần dọn cache Shizuku độc lập. `android/app/src/main/`: controller, activity, tile, manifest, icon, chuỗi giao diện. `test/widget_test.dart`: kiểm thử giao diện, lỗi quyền, lỗi đọc và quay lại app. `README.md`: cài đặt, Xiaomi, cấp/thu hồi quyền, kiểm thử trên máy.

Không tài khoản, quảng cáo hay dịch vụ chạy thường trực của app. USB/DNS không cần root hay Shizuku. Tính năng dọn cache dùng Shizuku API/provider 13.1.5 theo lựa chọn của người dùng, không cần root.

## Dọn cache hàng loạt

- Chỉ chạy khi bấm nút; không lập lịch và không tự dọn khi mở app, cấp quyền hay khởi động lại.
- Kiểm tra Shizuku đang chạy và được cấp quyền; hướng dẫn mở/cài Shizuku, xử lý từ chối quyền, ngắt kết nối, yêu cầu lặp và quá thời gian.
- Dùng UserService/AIDL theo API chính thức. Chỉ thực thi một lệnh cố định: `pm trim-caches 9223372036854775807 internal`. Không nhận lệnh shell từ Dart; không dùng `pm clear`, không truy cập/xóa thư mục dữ liệu, không chọn/xóa ảnh hoặc tài liệu.
- Yêu cầu Android dọn cache của các app trên bộ nhớ trong trong phạm vi hệ thống cho phép. Không hứa xóa sạch mọi cache, không coi mã thoát thành công là bằng chứng mọi file được xóa.
- Chênh lệch dung lượng trống được ghi là ước tính; app khác có thể tác động số đo. Khi timeout, báo chưa xác nhận được kết quả; thao tác đã gửi tới hệ thống có thể vẫn tiếp tục.
- Dọn trên luồng nền, giới hạn subprocess 60 giây và yêu cầu Shizuku 90 giây, giới hạn log trả về 4096 ký tự, đóng kết nối và dịch vụ sau khi xong.
- Điện thoại không root cần khởi động lại Shizuku sau khi reboot. Không thay đổi USB/DNS khi dọn cache.

## Thứ tự và kiểm tra

1. Viết và chạy test giao diện trước, sau đó triển khai màn hình + MethodChannel.
2. Triển khai controller + ô Android, khai báo quyền và service có BIND_QUICK_SETTINGS_TILE.
3. `dart format lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
4. Kiểm tra trên Android nếu có thiết bị; ghi rõ những phần chưa xác minh.

Theo Dart formatter và Kotlin thông thường; giữ xử lý lỗi tại ranh giới Android/Flutter. Ví dụ: `Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1`.

Xiaomi không root là máy đích. Người dùng có thể cấp quyền ADB một lần qua máy tính; ROM có thể hạn chế thêm. Không tự cấp quyền hay thay đổi thiết lập trên thiết bị thật đang kết nối.
