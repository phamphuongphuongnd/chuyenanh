import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('img2pdf_picker'));
  tearDown(() => tmp.deleteSync(recursive: true));

  final choose = find.byKey(const ValueKey('choose_photos_button'));
  final takePhoto = find.byKey(const ValueKey('take_photo_button'));

  testWidgets('mở màn là mở ngay trình chọn ảnh hệ thống; chọn xong vào màn sửa theo đúng thứ tự', (
    tester,
  ) async {
    final picker = FakePhotoPicker([
      ['/p/3.jpg', '/p/1.jpg', '/p/2.jpg'],
    ]);
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester);

    expect(picker.limits, [100], reason: 'giới hạn mặc định = maxImagesPerPdf');
    expect(h.cleanerCalls, 1, reason: 'lượt mới dọn file tạm');
    expect(picker.prepared, ['/p/3.jpg', '/p/1.jpg', '/p/2.jpg']);
    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Create PDF (3)'), findsOneWidget);
    // ảnh đang xem (trang 1) là ảnh chọn đầu tiên
    expect(h.processor.previews.first.$1, '/p/3.jpg');
  });

  testWidgets('huỷ trình chọn → ở lại màn chọn nguồn; bấm Chọn ảnh mở lại', (
    tester,
  ) async {
    final picker = FakePhotoPicker(); // lần đầu trả rỗng = huỷ
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester);

    expect(picker.calls, 1);
    expect(find.text('Select images'), findsOneWidget);
    expect(choose, findsOneWidget);
    expect(takePhoto, findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);

    picker.batches.add(['/p/a.jpg']);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(picker.calls, 2);
    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('nút Back thoát được khỏi màn chọn nguồn', (tester) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('từ màn sửa quay lại → về màn chọn nguồn, không tự mở trình chọn lần nữa', (
    tester,
  ) async {
    final picker = FakePhotoPicker([
      ['/p/a.jpg'],
    ]);
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester);
    expect(find.text('Edit images'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(choose, findsOneWidget);
    expect(picker.calls, 1);
  });

  testWidgets('ảnh cần đổi định dạng dùng đường dẫn đã đổi; ảnh hỏng bị bỏ qua + báo', (
    tester,
  ) async {
    final picker = FakePhotoPicker([
      ['/p/a.heic', '/p/bad.heic', '/p/c.jpg'],
    ]);
    picker.converted
      ..['/p/a.heic'] = '/work/a.jpg'
      ..['/p/bad.heic'] = null;
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester);

    expect(find.textContaining('1 image(s) could not be read'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    final previewed = h.processor.previews.map((e) => e.$1).toSet();
    expect(previewed.first, '/work/a.jpg');
    expect(previewed, isNot(contains('/p/a.heic')));
    expect(previewed, isNot(contains('/p/bad.heic')));
  });

  testWidgets('trình chọn trả quá giới hạn → cắt bớt giữ thứ tự + báo', (
    tester,
  ) async {
    final picker = FakePhotoPicker([
      ['/p/1.jpg', '/p/2.jpg', '/p/3.jpg'],
    ]);
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester, initialLocation: '/image-to-pdf/add', extra: 2);

    expect(picker.limits, [2]);
    expect(find.text('You can add up to 2 images.'), findsOneWidget);
    expect(picker.prepared, ['/p/1.jpg', '/p/2.jpg']);
    expect(find.text('HOME'), findsOneWidget, reason: 'màn thêm ảnh đóng lại');
  });

  testWidgets('chế độ thêm ảnh: giới hạn = số chỗ còn lại, trả đường dẫn, không dọn file tạm', (
    tester,
  ) async {
    final picker = FakePhotoPicker([
      ['/p/x.jpg', '/p/y.jpg'],
    ]);
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester, initialLocation: '/image-to-pdf/add', extra: 5);

    expect(picker.limits, [5]);
    expect(h.cleanerCalls, 0, reason: 'thêm ảnh không dọn file tạm của lượt đang làm');
    expect(find.text('HOME'), findsOneWidget);
    expect(choose, findsNothing);
  });

  testWidgets('chụp ảnh: huỷ trình chọn rồi bấm Chụp ảnh → vào màn sửa với ảnh vừa chụp', (
    tester,
  ) async {
    final h = Harness(tmp: tmp, camera: FakeCamera('/cam/shot.jpg'));
    await h.pump(tester);

    await tester.tap(takePhoto);
    await tester.pumpAndSettle();
    expect(h.camera.calls, 1);
    expect(h.picker.prepared, isEmpty, reason: 'ảnh camera là JPEG sẵn');
    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('huỷ camera → ở lại màn chọn nguồn', (tester) async {
    final h = Harness(tmp: tmp); // FakeCamera() trả null
    await h.pump(tester);
    await tester.tap(takePhoto);
    await tester.pumpAndSettle();
    expect(h.camera.calls, 1);
    expect(choose, findsOneWidget);
  });

  testWidgets('camera bị từ chối quyền → hiện thông báo lỗi', (tester) async {
    final camera = FakeCamera()..error = const PermissionDenied();
    final h = Harness(tmp: tmp, camera: camera);
    await h.pump(tester);

    await tester.tap(takePhoto);
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission denied'), findsOneWidget);
    expect(choose, findsOneWidget);
  });

  testWidgets('trình chọn báo lỗi quyền → hiện thông báo, vẫn ở màn chọn nguồn', (
    tester,
  ) async {
    final picker = FakePhotoPicker()..error = const PermissionDenied();
    final h = Harness(tmp: tmp, picker: picker);
    await h.pump(tester);

    expect(find.textContaining('Permission denied'), findsOneWidget);
    expect(choose, findsOneWidget);
  });
}
