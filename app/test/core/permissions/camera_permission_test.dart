import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/permissions/camera_permission.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_camera_permission.dart';

final _dialog = find.byKey(const ValueKey('camera_permission_dialog'));
final _continue = find.byKey(const ValueKey('camera_permission_continue'));
final _later = find.byKey(const ValueKey('camera_permission_later'));

void main() {
  /// Kết quả lần gọi [ensureCameraPermission] gần nhất (`bool` hoặc lỗi ném ra).
  Object? outcome;

  setUp(() => outcome = null);

  Future<void> pump(
    WidgetTester tester,
    FakeCameraPermission perm, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cameraPermissionProvider.overrideWithValue(perm)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async {
                  try {
                    outcome = await ensureCameraPermission(context, ref);
                  } catch (e) {
                    outcome = e;
                  }
                },
                child: const Text('open camera'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapOpen(WidgetTester tester) async {
    await tester.tap(find.text('open camera'));
    await tester.pumpAndSettle();
  }

  testWidgets('đã có quyền → không hiện hộp giải thích, không xin lại', (
    tester,
  ) async {
    final perm = FakeCameraPermission();
    await pump(tester, perm);
    await tapOpen(tester);

    expect(_dialog, findsNothing);
    expect(perm.requestCalls, 0);
    expect(outcome, isTrue);
  });

  testWidgets('chưa có quyền → hộp giải thích → Tiếp tục → xin quyền hệ thống', (
    tester,
  ) async {
    final perm = FakeCameraPermission(current: PermissionStatus.denied);
    await pump(tester, perm);
    await tapOpen(tester);

    expect(_dialog, findsOneWidget);
    expect(find.text('Allow camera access'), findsOneWidget);
    expect(
      find.text(
        'Phiotron PDF uses the camera to photograph and scan documents and to read QR codes.',
      ),
      findsOneWidget,
    );
    expect(perm.requestCalls, 0, reason: 'chưa bấm gì thì chưa xin quyền');

    await tester.tap(_continue);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(perm.requestCalls, 1);
    expect(outcome, isTrue);
  });

  testWidgets('Để sau → không xin quyền, trả false (không ném lỗi)', (
    tester,
  ) async {
    final perm = FakeCameraPermission(current: PermissionStatus.denied);
    await pump(tester, perm);
    await tapOpen(tester);

    await tester.tap(_later);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(perm.requestCalls, 0);
    expect(outcome, isFalse);
  });

  testWidgets('Tiếp tục nhưng hệ thống bị từ chối → ném PermissionDenied', (
    tester,
  ) async {
    final perm = FakeCameraPermission(
      current: PermissionStatus.denied,
      afterRequest: PermissionStatus.denied,
    );
    await pump(tester, perm);
    await tapOpen(tester);
    await tester.tap(_continue);
    await tester.pumpAndSettle();

    expect(perm.requestCalls, 1);
    expect(outcome, isA<PermissionDenied>());
  });

  testWidgets('bị từ chối vĩnh viễn → không hộp giải thích, không xin, ném PermissionDenied', (
    tester,
  ) async {
    final perm = FakeCameraPermission(
      current: PermissionStatus.permanentlyDenied,
    );
    await pump(tester, perm);
    await tapOpen(tester);

    expect(_dialog, findsNothing);
    expect(perm.requestCalls, 0);
    expect(outcome, isA<PermissionDenied>());
  });

  testWidgets('tiếng Việt: chữ hộp giải thích và hai nút', (tester) async {
    final perm = FakeCameraPermission(current: PermissionStatus.denied);
    await pump(tester, perm, locale: const Locale('vi'));
    await tapOpen(tester);

    expect(find.text('Cho phép dùng máy ảnh'), findsOneWidget);
    expect(
      find.text('Ảnh chỉ được xử lý trên máy, không gửi đi đâu.'),
      findsOneWidget,
    );
    expect(find.text('Để sau'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });
}
