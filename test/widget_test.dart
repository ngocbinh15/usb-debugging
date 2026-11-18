import 'package:app_usb/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.usbtoggle/usb_debugging');
  late bool enabled;
  late bool permission;
  late bool failRead;
  late bool failWrite;
  late bool dnsSupported;
  late bool failDnsWrite;
  late String dnsMode;
  late String dnsHostname;
  late List<MethodCall> calls;

  setUp(() {
    enabled = false;
    permission = false;
    failRead = false;
    failWrite = false;
    dnsSupported = true;
    failDnsWrite = false;
    dnsMode = 'opportunistic';
    dnsHostname = 'dns.example.com';
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.usbtoggle/cache_cleaner'),
          (_) async => {'running': false, 'granted': false, 'supported': true},
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getStatus':
              if (failRead) {
                throw PlatformException(
                  code: 'READ_FAILED',
                  message: 'Không đọc được trạng thái.',
                );
              }
              return {
                'enabled': enabled,
                'hasPermission': permission,
                'dnsSupported': dnsSupported,
                'dnsMode': dnsMode,
                'dnsHostname': dnsHostname,
              };
            case 'setEnabled':
              if (failWrite) {
                permission = false;
                throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Cần cấp lại quyền ADB.',
                );
              }
              enabled = call.arguments as bool;
              return {'enabled': enabled, 'hasPermission': permission};
            case 'addTile':
            case 'addDnsTile':
              return 'manual';
            case 'setDnsPrivate':
              if (failDnsWrite) {
                permission = false;
                throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Cần cấp lại quyền ADB.',
                );
              }
              dnsMode = call.arguments == true ? 'hostname' : 'opportunistic';
              return null;
            case 'openDeveloperSettings':
            case 'openDnsSettings':
              return null;
            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.usbtoggle/cache_cleaner'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows setup and prevents toggling without permission', (
    tester,
  ) async {
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập lần đầu · Không cần root'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    expect(find.textContaining('adb shell pm grant'), findsOneWidget);
  });

  testWidgets('toggles both ways using the Android result', (tester) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
  });

  testWidgets('handles revoked permission without showing a false success', (
    tester,
  ) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    failWrite = true;
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(find.text('Cần cấp lại quyền ADB.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
  });

  testWidgets('reloads status after returning from settings', (tester) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
  });

  testWidgets('reports read failure and lets user retry', (tester) async {
    failRead = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.text('Không đọc được trạng thái.'), findsOneWidget);
    failRead = false;
    permission = true;
    await tester.tap(find.byTooltip('Đọc lại trạng thái'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Switch>(find.byType(Switch).first).onChanged,
      isNotNull,
    );
  });

  testWidgets('supports manual tile setup on older Android', (tester) async {
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm vào Cài đặt nhanh'));
    await tester.tap(find.text('Thêm vào Cài đặt nhanh'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'addTile'), isTrue);
    expect(find.textContaining('biểu tượng bút chì'), findsOneWidget);
  });

  testWidgets('fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Finder dnsSwitch() => find.descendant(
    of: find.byKey(const ValueKey('privateDns')),
    matching: find.byType(Switch),
  );

  testWidgets('switches automatic DNS to saved hostname and back', (
    tester,
  ) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('dns.example.com'), findsWidgets);
    expect(tester.widget<Switch>(dnsSwitch()).value, isFalse);
    await tester.ensureVisible(dnsSwitch());
    await tester.tap(dnsSwitch());
    await tester.pumpAndSettle();
    expect(dnsMode, 'hostname');
    expect(dnsHostname, 'dns.example.com');
    expect(tester.widget<Switch>(dnsSwitch()).value, isTrue);
    await tester.tap(dnsSwitch());
    await tester.pumpAndSettle();
    expect(dnsMode, 'opportunistic');
    expect(dnsHostname, 'dns.example.com');
    expect(enabled, isFalse);
  });

  testWidgets('disables DNS switch without permission', (tester) async {
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(dnsSwitch()).onChanged, isNull);
  });

  testWidgets('asks to configure a hostname before enabling private DNS', (
    tester,
  ) async {
    permission = true;
    dnsHostname = '';
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(dnsSwitch()).onChanged, isNull);
    await tester.ensureVisible(find.text('Cài đặt DNS'));
    await tester.tap(find.text('Cài đặt DNS'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'openDnsSettings'), isTrue);
  });

  testWidgets('does not offer DNS tile before Android 9', (tester) async {
    dnsSupported = false;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.text('Thêm ô DNS riêng tư'), findsNothing);
    expect(
      find.text('DNS riêng tư yêu cầu Android 9 trở lên.'),
      findsOneWidget,
    );
  });

  testWidgets('handles revoked permission during DNS changes', (tester) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    failDnsWrite = true;
    await tester.ensureVisible(dnsSwitch());
    await tester.tap(dnsSwitch());
    await tester.pumpAndSettle();
    expect(dnsMode, 'opportunistic');
    expect(tester.widget<Switch>(dnsSwitch()).value, isFalse);
    expect(tester.widget<Switch>(dnsSwitch()).onChanged, isNull);
    expect(find.text('Cần cấp lại quyền ADB.'), findsOneWidget);
  });

  testWidgets('reports externally disabled DNS and reloads on resume', (
    tester,
  ) async {
    permission = true;
    dnsMode = 'off';
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang tắt trong hệ thống'), findsOneWidget);
    dnsMode = 'hostname';
    dnsHostname = 'other.example.com';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(dnsSwitch()).value, isTrue);
    expect(find.textContaining('other.example.com'), findsWidgets);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
  });

  testWidgets('requests a separate DNS Quick Settings tile', (tester) async {
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm ô DNS riêng tư'));
    await tester.tap(find.text('Thêm ô DNS riêng tư'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'addDnsTile'), isTrue);
    expect(find.textContaining('kéo ô DNS riêng tư lên'), findsOneWidget);
  });

  testWidgets('clears stale DNS state when a refresh fails', (tester) async {
    permission = true;
    dnsMode = 'hostname';
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(dnsSwitch()).value, isTrue);
    failRead = true;
    await tester.tap(find.byTooltip('Đọc lại trạng thái'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(dnsSwitch()).value, isFalse);
    expect(tester.widget<Switch>(dnsSwitch()).onChanged, isNull);
    expect(find.textContaining('Chưa đọc được trạng thái'), findsWidgets);
  });
}
