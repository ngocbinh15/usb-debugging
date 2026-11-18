import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CacheCleanerCard extends StatefulWidget {
  const CacheCleanerCard({super.key});

  @override
  State<CacheCleanerCard> createState() => _CacheCleanerCardState();
}

class _CacheCleanerCardState extends State<CacheCleanerCard>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.usbtoggle/cache_cleaner');
  bool _running = false;
  bool _granted = false;
  bool _supported = true;
  bool _busy = true;
  String? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _perform('getStatus');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _perform('getStatus');
  }

  Future<void> _readStatus() async {
    final status = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    if (status == null) throw PlatformException(code: 'EMPTY_STATUS');
    if (!mounted) return;
    setState(() {
      _running = status['running'] as bool;
      _granted = status['granted'] as bool;
      _supported = status['supported'] as bool;
    });
  }

  Future<void> _perform(String method) async {
    setState(() => _busy = true);
    try {
      if (method == 'clean') {
        setState(() => _result = null);
        final result = await _channel.invokeMapMethod<String, dynamic>('clean');
        if (result == null) throw PlatformException(code: 'EMPTY_RESULT');
        if (mounted) {
          setState(() {
            if (result['timedOut'] == true) {
              _result =
                  'Quá thời gian chờ. Chưa xác nhận được kết quả dọn cache; '
                  'không chạy lại ngay vì hệ thống có thể vẫn đang xử lý.';
            } else if (result['exitCode'] != 0) {
              _result =
                  'Android từ chối yêu cầu dọn cache: ${result['output']}';
            } else {
              final freed = result['freedBytes'] as int;
              _result =
                  'Android đã xử lý yêu cầu dọn cache. '
                  '${freed > 0 ? 'Dung lượng trống tăng khoảng ${(freed / 1048576).toStringAsFixed(1)} MB. ' : 'Chưa ghi nhận dung lượng trống tăng. '}'
                  'Hệ thống không xác nhận mọi cache đã được xóa. '
                  'Dung lượng có thể thay đổi do app khác đang chạy.';
            }
          });
        }
      } else if (method == 'requestPermission') {
        final granted = await _channel.invokeMethod<bool>(method);
        if (mounted) {
          setState(
            () => _result = granted == true
                ? 'Đã cấp quyền. Nhấn Dọn cache hàng loạt khi muốn dọn.'
                : 'Chưa được cấp quyền Shizuku.',
          );
        }
      } else if (method != 'getStatus') {
        await _channel.invokeMethod<void>(method);
      }
      await _readStatus();
    } on PlatformException catch (error) {
      try {
        await _readStatus();
      } on PlatformException {
        if (mounted) {
          setState(() {
            _running = false;
            _granted = false;
          });
        }
      }
      if (mounted) {
        setState(
          () => _result = error.message ?? 'Không kết nối được Shizuku.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dọn cache', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            !_supported
                ? 'Cần Android 8 trở lên.'
                : !_running
                ? 'Hãy mở Shizuku và khởi động dịch vụ trước.'
                : _granted
                ? 'Shizuku đã sẵn sàng.'
                : 'Cần cấp quyền Shizuku cho app.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Dọn cache hàng loạt trong bộ nhớ trong theo khả năng Android. '
            'Chỉ chạy khi bạn nhấn nút, không xóa dữ liệu hay đăng xuất app. '
            'App có thể phải tải lại nội dung đã lưu tạm.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || !_supported || !_running || !_granted
                ? null
                : () => _perform('clean'),
            child: const Text('Dọn cache hàng loạt'),
          ),
          if (_running && !_granted && _supported)
            OutlinedButton(
              onPressed: _busy ? null : () => _perform('requestPermission'),
              child: const Text('Cấp quyền Shizuku'),
            ),
          TextButton(
            onPressed: _busy ? null : () => _perform('openShizuku'),
            child: const Text('Mở / cài Shizuku'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _perform('getStatus'),
            child: const Text('Kiểm tra Shizuku'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_result != null)
            Text(_result!, key: const ValueKey('cacheResult')),
          const SizedBox(height: 8),
          const Text(
            'Sau khi khởi động lại điện thoại, cần khởi động lại Shizuku. '
            'Tắt gỡ lỗi hoặc chính sách MIUI cũng có thể làm dịch vụ dừng.',
          ),
        ],
      ),
    ),
  );
}
