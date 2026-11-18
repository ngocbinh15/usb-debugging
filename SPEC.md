# USB Debugging — Android

Một app Flutter nhỏ, giao diện tiếng Việt, chỉ bật/tắt USB debugging và cung cấp ô Cài đặt nhanh. Android tối thiểu 7.0 (API 24).

## Hành vi

- Đọc trạng thái thật từ Android; không lưu trạng thái giả trong Flutter.
- App và TileService dùng chung bộ điều khiển Kotlin qua Settings.Global.ADB_ENABLED.
- Chỉ ghi sau khi người dùng chủ động bấm và có WRITE_SECURE_SETTINGS; không tự bật khi mở app hay khởi động máy.
- Chưa có quyền: vô hiệu hóa công tắc, hướng dẫn lệnh ADB, ô nhanh mở app để hướng dẫn.
- Ô nhanh yêu cầu mở khóa trước khi đổi trạng thái; theo dõi thay đổi khi hiển thị.
- Android 13 trở lên: nút yêu cầu thêm ô bằng API hệ thống. Bản cũ hướng dẫn thêm bằng trình sửa ô.
- Chỉ thay đổi USB debugging; không đổi Wireless debugging hay công tắc tổng Tùy chọn nhà phát triển.

## Phạm vi và cấu trúc

`lib/main.dart`: màn hình và MethodChannel. `android/app/src/main/`: controller, activity, tile, manifest, icon, chuỗi giao diện. `test/widget_test.dart`: kiểm thử giao diện, lỗi quyền, lỗi đọc và quay lại app. `README.md`: cài đặt, Xiaomi, cấp/thu hồi quyền, kiểm thử trên máy.

Không tài khoản, mạng, quảng cáo, root, Shizuku hay dịch vụ chạy thường trực. Không thêm dependency runtime ngoài Flutter.

## Thứ tự và kiểm tra

1. Viết và chạy test giao diện trước, sau đó triển khai màn hình + MethodChannel.
2. Triển khai controller + ô Android, khai báo quyền và service có BIND_QUICK_SETTINGS_TILE.
3. `dart format lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
4. Kiểm tra trên Android nếu có thiết bị; ghi rõ những phần chưa xác minh.

Theo Dart formatter và Kotlin thông thường; giữ xử lý lỗi tại ranh giới Android/Flutter. Ví dụ: `Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1`.

Xiaomi không root là máy đích. Người dùng có thể cấp quyền ADB một lần qua máy tính; ROM có thể hạn chế thêm. Không tự cấp quyền hay thay đổi thiết lập trên thiết bị thật đang kết nối.
