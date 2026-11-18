import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cache_cleaner_card.dart';

void main() => runApp(const UsbDebuggingApp());

class UsbDebuggingApp extends StatelessWidget {
  const UsbDebuggingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'USB Debugging',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00796b)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff00796b),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const UsbDebuggingPage(),
  );
}

class UsbDebuggingPage extends StatefulWidget {
  const UsbDebuggingPage({super.key});

  @override
  State<UsbDebuggingPage> createState() => _UsbDebuggingPageState();
}

class _UsbDebuggingPageState extends State<UsbDebuggingPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.usbtoggle/usb_debugging');
  static const _grantCommand =
      'adb shell pm grant dev.usbtoggle.app_usb '
      'android.permission.WRITE_SECURE_SETTINGS';
  bool? _enabled;
  bool _hasPermission = false;
  bool _busy = true;
  String? _error;
  bool _dnsSupported = false;
  String? _dnsMode;
  String _dnsHostname = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _readStatus() async {
    final status = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    if (status == null) throw PlatformException(code: 'EMPTY_STATUS');
    if (!mounted) return;
    setState(() {
      _enabled = status['enabled'] as bool;
      _hasPermission = status['hasPermission'] as bool;
      _dnsSupported = status['dnsSupported'] as bool;
      _dnsMode = status['dnsMode'] as String;
      _dnsHostname = status['dnsHostname'] as String;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _readStatus();
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _enabled = null;
          _dnsMode = null;
          _hasPermission = false;
          _error = error.message ?? 'Không đọc được trạng thái USB debugging.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeSetting(String method, bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _channel.invokeMethod<void>(method, enabled);
      await _readStatus();
    } on PlatformException catch (error) {
      // Re-read permissions because they may have been revoked outside the app.
      try {
        await _readStatus();
      } on PlatformException {
        if (mounted) {
          setState(() {
            _enabled = null;
            _dnsMode = null;
            _hasPermission = false;
          });
        }
      }
      if (mounted) {
        setState(
          () => _error = error.message ?? 'Không thay đổi được cài đặt.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addTile({bool privateDns = false}) async {
    final label = privateDns ? 'DNS riêng tư' : 'USB debugging';
    try {
      final result = await _channel.invokeMethod<String>(
        privateDns ? 'addDnsTile' : 'addTile',
      );
      _message(switch (result) {
        'added' => 'Đã thêm ô $label vào Cài đặt nhanh.',
        'alreadyAdded' => 'Ô $label đã có trong Cài đặt nhanh.',
        'notAdded' => 'Chưa thêm ô. Bạn có thể thêm thủ công bằng nút Sửa.',
        'manual' =>
          'Kéo bảng Cài đặt nhanh xuống → Sửa (biểu tượng bút chì) '
              '→ kéo ô $label lên.',
        _ =>
          'Không thêm được ô tự động. Hãy thêm bằng nút Sửa trong Cài đặt nhanh.',
      });
    } on PlatformException catch (error) {
      _message(error.message ?? 'Không thêm được ô Cài đặt nhanh.');
    }
  }

  Future<void> _openSettings({bool privateDns = false}) async {
    try {
      await _channel.invokeMethod<void>(
        privateDns ? 'openDnsSettings' : 'openDeveloperSettings',
      );
    } on PlatformException catch (error) {
      _message(error.message ?? 'Không mở được Cài đặt hệ thống.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Debugging'),
        actions: [
          IconButton(
            tooltip: 'Đọc lại trạng thái',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
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
                    _enabled == null
                        ? (_busy
                              ? 'Đang đọc trạng thái…'
                              : 'Chưa đọc được trạng thái')
                        : (_enabled! ? 'Đang bật' : 'Đang tắt'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: SwitchListTile.adaptive(
                      title: const Text('USB debugging'),
                      subtitle: Text(
                        _hasPermission
                            ? 'Cho phép kết nối gỡ lỗi qua cáp USB'
                            : 'Cần cấp quyền ADB một lần để dùng công tắc',
                      ),
                      value: _enabled ?? false,
                      onChanged: _busy || !_hasPermission || _enabled == null
                          ? null
                          : (value) => _changeSetting('setEnabled', value),
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.error),
                        semanticsLabel: 'Lỗi: $_error',
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addTile,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm vào Cài đặt nhanh'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sau khi thêm, kéo từ mép trên màn hình xuống để bật/tắt '
                    'bằng ô USB debugging. Khi máy đang khóa, cần mở khóa trước.',
                  ),
                  const SizedBox(height: 24),
                  if (_dnsSupported) ...[
                    Card(
                      child: SwitchListTile.adaptive(
                        key: const ValueKey('privateDns'),
                        title: const Text('DNS riêng tư'),
                        subtitle: Text(
                          '${switch (_dnsMode) {
                            'hostname' => 'Máy chủ riêng tư',
                            'off' => 'Đang tắt trong hệ thống',
                            null => 'Chưa đọc được trạng thái',
                            _ => 'Tự động',
                          }}\n${_dnsHostname.isEmpty ? 'Chọn tên máy chủ trong Cài đặt DNS trước.' : _dnsHostname}',
                        ),
                        value: _dnsMode == 'hostname',
                        onChanged:
                            _busy ||
                                !_hasPermission ||
                                _dnsMode == null ||
                                (_dnsMode != 'hostname' && _dnsHostname.isEmpty)
                            ? null
                            : (value) => _changeSetting('setDnsPrivate', value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _addTile(privateDns: true),
                      icon: const Icon(Icons.dns_outlined),
                      label: const Text('Thêm ô DNS riêng tư'),
                    ),
                    TextButton(
                      onPressed: () => _openSettings(privateDns: true),
                      child: const Text('Cài đặt DNS'),
                    ),
                    const Text(
                      'Bật: dùng tên máy chủ đã cấu hình. Tắt: chuyển về Tự động. '
                      'Đổi tên máy chủ tại Cài đặt kết nối → DNS riêng tư. '
                      'Máy chủ không truy cập được có thể khiến mạng không phân giải được tên miền.',
                    ),
                    const SizedBox(height: 24),
                  ] else if (!_busy && _enabled != null) ...[
                    const Text('DNS riêng tư yêu cầu Android 9 trở lên.'),
                    const SizedBox(height: 24),
                  ],
                  if (!_hasPermission) ...[
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
                        await Clipboard.setData(
                          const ClipboardData(text: _grantCommand),
                        );
                        _message('Đã sao chép lệnh cấp quyền.');
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
                  const CacheCleanerCard(),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Tùy chọn nhà phát triển'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tắt USB debugging sẽ ngắt phiên ADB qua USB, kể cả phiên chạy '
                    'Flutter từ máy tính. Chỉ cho phép gỡ lỗi với máy tính bạn tin cậy. '
                    'App không thay đổi gỡ lỗi không dây.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
