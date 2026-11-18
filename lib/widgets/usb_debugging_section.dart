import 'package:flutter/material.dart';

class UsbDebuggingSection extends StatelessWidget {
  const UsbDebuggingSection({
    super.key,
    required this.enabled,
    required this.busy,
    required this.hasPermission,
    required this.onChanged,
  });

  final bool? enabled;
  final bool busy;
  final bool hasPermission;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.usb_rounded, size: 80, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          'Gỡ lỗi USB',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          enabled == null
              ? (busy ? 'Đang đọc trạng thái…' : 'Chưa đọc được trạng thái')
              : (enabled! ? 'Đang bật' : 'Đang tắt'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: SwitchListTile.adaptive(
            title: const Text('USB debugging'),
            subtitle: Text(
              hasPermission
                  ? 'Cho phép kết nối gỡ lỗi qua cáp USB'
                  : 'Cần cấp quyền ADB một lần để dùng công tắc',
            ),
            value: enabled ?? false,
            onChanged: busy || !hasPermission || enabled == null
                ? null
                : onChanged,
          ),
        ),
      ],
    );
  }
}
