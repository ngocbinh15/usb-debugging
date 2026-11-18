import 'package:app_usb/main.dart';
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
  late List<MethodCall> calls;

  setUp(() {
    enabled = false;
    permission = false;
    failRead = false;
    failWrite = false;
    calls = [];
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
              return {'enabled': enabled, 'hasPermission': permission};
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
              return 'manual';
            case 'openDeveloperSettings':
              return null;
            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows setup and prevents toggling without permission', (
    tester,
  ) async {
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập lần đầu · Không cần root'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.textContaining('adb shell pm grant'), findsOneWidget);
  });

  testWidgets('toggles both ways using the Android result', (tester) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
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
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(find.text('Cần cấp lại quyền ADB.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('reloads status after returning from settings', (tester) async {
    permission = true;
    await tester.pumpWidget(const UsbDebuggingApp());
    await tester.pumpAndSettle();
    enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
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
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
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
}
