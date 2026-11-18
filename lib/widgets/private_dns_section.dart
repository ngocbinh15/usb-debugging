import 'package:flutter/material.dart';

class PrivateDnsSection extends StatelessWidget {
  const PrivateDnsSection({
    super.key,
    required this.supported,
    required this.mode,
    required this.hostname,
    required this.busy,
    required this.hasPermission,
    required this.statusKnown,
    required this.onChanged,
    required this.onAddTile,
    required this.onOpenSettings,
  });

  final bool supported;
  final String? mode;
  final String hostname;
  final bool busy;
  final bool hasPermission;
  final bool statusKnown;
  final ValueChanged<bool> onChanged;
  final VoidCallback onAddTile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (supported) ...[
        Card(
          child: SwitchListTile.adaptive(
            key: const ValueKey('privateDns'),
            title: const Text('DNS riêng tư'),
            subtitle: Text(
              '${switch (mode) {
                'hostname' => 'Máy chủ riêng tư',
                'off' => 'Đang tắt trong hệ thống',
                null => 'Chưa đọc được trạng thái',
                _ => 'Tự động',
              }}\n${hostname.isEmpty ? 'Chọn tên máy chủ trong Cài đặt DNS trước.' : hostname}',
            ),
            value: mode == 'hostname',
            onChanged:
                busy ||
                    !hasPermission ||
                    mode == null ||
                    (mode != 'hostname' && hostname.isEmpty)
                ? null
                : onChanged,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddTile,
          icon: const Icon(Icons.dns_outlined),
          label: const Text('Thêm ô DNS riêng tư'),
        ),
        TextButton(onPressed: onOpenSettings, child: const Text('Cài đặt DNS')),
        const Text(
          'Bật: dùng tên máy chủ đã cấu hình. Tắt: chuyển về Tự động. '
          'Đổi tên máy chủ tại Cài đặt kết nối → DNS riêng tư. '
          'Máy chủ không truy cập được có thể khiến mạng không phân giải được tên miền.',
        ),
        const SizedBox(height: 24),
      ] else if (!busy && statusKnown) ...[
        const Text('DNS riêng tư yêu cầu Android 9 trở lên.'),
        const SizedBox(height: 24),
      ],
    ],
  );
}
