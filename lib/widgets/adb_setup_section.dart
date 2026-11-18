import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdbSetupSection extends StatelessWidget {
  const AdbSetupSection({super.key, required this.onCommandCopied});

  final ValueChanged<String> onCommandCopied;

  static const _grantCommand =
      'adb shell pm grant dev.usbtoggle.app_usb '
      'android.permission.WRITE_SECURE_SETTINGS';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Thiết lập lần đầu · Không cần root',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'ADB là công cụ kết nối máy tính với Android. '
          'Cài Android SDK Platform-Tools trên máy tính, rồi:\n\n'
          '1. Trên Xiaomi: Cài đặt → Giới thiệu điện thoại → '
          'chạm nhiều lần vào phiên bản MIUI/OS để bật chế độ nhà phát triển.\n\n'
          '2. Mở Cài đặt bổ sung → Tùy chọn nhà phát triển → '
          'bật USB debugging (Gỡ lỗi USB).\n\n'
          '3. Cắm cáp USB truyền dữ liệu vào máy tính, chấp nhận '
          'hộp thoại cho phép gỡ lỗi trên điện thoại.\n\n'
          '4. Mở terminal tại thư mục Platform-Tools, chạy lệnh dưới đây '
          '(PowerShell dùng .\\adb.exe thay cho adb).',
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: SelectableText(_grantCommand),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: _grantCommand));
            onCommandCopied('Đã sao chép lệnh cấp quyền.');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Sao chép lệnh'),
        ),
        const Text(
          'Nếu Xiaomi báo lỗi cấp quyền, một số bản MIUI/HyperOS cần bật '
          'thêm “USB debugging (Security settings)” trong Tùy chọn nhà phát triển. '
          'Tùy ROM, mục này có thể yêu cầu tài khoản Xiaomi. '
          'Sau khi chạy lệnh, nhấn nút đọc lại trạng thái ở phía trên.',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
