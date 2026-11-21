import 'dart:async';

import 'package:app_usb/cache_cleaner_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.usbtoggle/cache_cleaner');
  late bool running;
  late bool supported;
  late bool granted;
  late bool denied;
  late bool failClean;
  late String tileResult;
  late bool failAddTile;
  late List<String> calls;
  Completer<Map<String, Object>>? cleaning;

  setUp(() {
    running = false;
    supported = true;
    granted = false;
    denied = false;
    failClean = false;
    tileResult = 'manual';
    failAddTile = false;
    calls = [];
    cleaning = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'getStatus':
              return {
                'running': running,
                'granted': granted,
                'supported': supported,
              };
            case 'requestPermission':
              granted = !denied;
              return granted;
            case 'clean':
              if (failClean) {
                throw PlatformException(
                  code: 'SHIZUKU_ERROR',
                  message: 'Shizuku đã ngắt kết nối.',
                );
              }
              return cleaning == null
                  ? {
                      'exitCode': 0,
                      'output': '',
                      'freedBytes': 0,
                      'timedOut': false,
                    }
                  : await cleaning!.future;
            case 'openShizuku':
              return null;
            case 'addCacheTile':
              if (failAddTile) {
                throw PlatformException(
                  code: 'ANDROID_ERROR',
                  message: 'Không thêm được ô dọn cache.',
                );
              }
              return tileResult;
            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CacheCleanerCard())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('adds the cache tile without requesting permission or cleaning', (
    tester,
  ) async {
    tileResult = 'added';
    await open(tester);
    await tester.ensureVisible(find.text('Thêm ô Dọn cache'));
    await tester.tap(find.text('Thêm ô Dọn cache'));
    await tester.pumpAndSettle();
    expect(calls, contains('addCacheTile'));
    expect(calls, isNot(contains('clean')));
    expect(calls, isNot(contains('requestPermission')));
    expect(find.text('Đã thêm ô Dọn cache vào Cài đặt nhanh.'), findsOneWidget);
  });

  testWidgets('explains manual cache tile setup on older Android', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Thêm ô Dọn cache'));
    await tester.tap(find.text('Thêm ô Dọn cache'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kéo ô Dọn cache lên'), findsOneWidget);
    expect(calls, isNot(contains('clean')));
  });

  testWidgets('shows cache tile setup errors', (tester) async {
    failAddTile = true;
    await open(tester);
    await tester.ensureVisible(find.text('Thêm ô Dọn cache'));
    await tester.tap(find.text('Thêm ô Dọn cache'));
    await tester.pumpAndSettle();
    expect(find.text('Không thêm được ô dọn cache.'), findsOneWidget);
  });

  testWidgets('does not offer the cache tile before Android 8', (tester) async {
    supported = false;
    await open(tester);
    final addTile = find.widgetWithText(OutlinedButton, 'Thêm ô Dọn cache');
    expect(tester.widget<OutlinedButton>(addTile).onPressed, isNull);
    expect(calls, isNot(contains('addCacheTile')));
  });

  testWidgets('does not clean automatically or when Shizuku is stopped', (
    tester,
  ) async {
    await open(tester);
    expect(calls, ['getStatus']);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dọn cache hàng loạt'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Mở / cài Shizuku'));
    await tester.pumpAndSettle();
    expect(calls, contains('openShizuku'));
  });

  testWidgets('asks for permission without starting cleanup', (tester) async {
    running = true;
    await open(tester);
    await tester.tap(find.text('Cấp quyền Shizuku'));
    await tester.pumpAndSettle();
    expect(granted, isTrue);
    expect(calls, isNot(contains('clean')));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dọn cache hàng loạt'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('denied permission keeps cleanup disabled', (tester) async {
    running = true;
    denied = true;
    await open(tester);
    await tester.tap(find.text('Cấp quyền Shizuku'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa được cấp quyền Shizuku.'), findsOneWidget);
    expect(calls, isNot(contains('clean')));
  });

  testWidgets(
    'does not claim all caches were deleted on a successful request',
    (tester) async {
      running = granted = true;
      await open(tester);
      await tester.tap(find.text('Dọn cache hàng loạt'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'clean').length, 1);
      expect(find.textContaining('Android đã xử lý yêu cầu'), findsOneWidget);
      expect(
        find.textContaining('không xác nhận mọi cache đã được xóa'),
        findsOneWidget,
      );
    },
  );

  testWidgets('blocks duplicate cleanup and reports command failure', (
    tester,
  ) async {
    running = granted = true;
    cleaning = Completer();
    await open(tester);
    await tester.tap(find.text('Dọn cache hàng loạt'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    cleaning!.complete({
      'exitCode': 1,
      'output': 'Permission denied',
      'freedBytes': 0,
      'timedOut': false,
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission denied'), findsOneWidget);
    expect(find.textContaining('Android đã xử lý yêu cầu'), findsNothing);
  });

  testWidgets('handles Shizuku disconnects', (tester) async {
    running = granted = true;
    failClean = true;
    await open(tester);
    running = granted = false;
    await tester.tap(find.text('Dọn cache hàng loạt'));
    await tester.pumpAndSettle();
    expect(find.text('Shizuku đã ngắt kết nối.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dọn cache hàng loạt'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('reports a timeout as an unknown cleanup result', (tester) async {
    running = granted = true;
    cleaning = Completer();
    await open(tester);
    await tester.tap(find.text('Dọn cache hàng loạt'));
    await tester.pump();
    cleaning!.complete({
      'exitCode': -1,
      'output': '',
      'freedBytes': 0,
      'timedOut': true,
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Quá thời gian chờ'), findsOneWidget);
    expect(find.textContaining('Android đã xử lý yêu cầu'), findsNothing);
  });
}
