import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cache_cleaner_card.dart';
import '../widgets/adb_setup_section.dart';
import '../widgets/private_dns_section.dart';
import '../widgets/usb_debugging_section.dart';

class UsbDebuggingPage extends StatefulWidget {
  const UsbDebuggingPage({super.key});

  @override
  State<UsbDebuggingPage> createState() => _UsbDebuggingPageState();
}

class _UsbDebuggingPageState extends State<UsbDebuggingPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.usbtoggle/usb_debugging');
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
                  UsbDebuggingSection(
                    enabled: _enabled,
                    busy: _busy,
                    hasPermission: _hasPermission,
                    onChanged: (value) => _changeSetting('setEnabled', value),
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
                  PrivateDnsSection(
                    supported: _dnsSupported,
                    mode: _dnsMode,
                    hostname: _dnsHostname,
                    busy: _busy,
                    hasPermission: _hasPermission,
                    statusKnown: _enabled != null,
                    onChanged: (value) =>
                        _changeSetting('setDnsPrivate', value),
                    onAddTile: () => _addTile(privateDns: true),
                    onOpenSettings: () => _openSettings(privateDns: true),
                  ),
                  if (!_hasPermission)
                    AdbSetupSection(onCommandCopied: _message),
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
