import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/image_to_pdf/services/gallery_service.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('img2pdf_picker'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Finder badge(String n) => find.descendant(
    of: find.byType(GridView),
    matching: find.text(n),
  );

  testWidgets('hiện camera + lưới ảnh; chọn nhiều có số thứ tự, bỏ chọn dồn số', (
    tester,
  ) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester);

    expect(find.byKey(const ValueKey('camera_tile')), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset_all_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('next_button')), findsNothing);
    expect(h.cleanerCalls, 1, reason: 'lượt mới dọn file tạm');

    await tester.tap(find.byKey(const ValueKey('asset_all_2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_4')));
    await tester.pump();

    expect(badge('1'), findsOneWidget); // all_2
    expect(badge('2'), findsOneWidget); // all_0
    expect(badge('3'), findsOneWidget); // all_4
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('next_button')), findsOneWidget);

    // bỏ chọn ảnh đầu tiên (all_2) → các ảnh sau dồn số
    await tester.tap(find.byKey(const ValueKey('asset_all_2')));
    await tester.pump();
    expect(badge('3'), findsNothing);
    expect(find.text('2 selected'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('asset_all_0')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('asset_all_4')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Next: lấy file theo đúng thứ tự chọn rồi mở màn sửa', (
    tester,
  ) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester);

    await tester.tap(find.byKey(const ValueKey('asset_all_3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    expect(h.gallery.resolved, ['all_3', 'all_1']);
    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('chụp camera thêm vào cuối danh sách chọn', (tester) async {
    final h = Harness(tmp: tmp, camera: FakeCamera('/cam/shot.jpg'));
    await h.pump(tester);

    await tester.tap(find.byKey(const ValueKey('asset_all_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('camera_tile')));
    await tester.pumpAndSettle();

    expect(h.camera.calls, 1);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();
    expect(h.gallery.resolved, ['all_0'], reason: 'ảnh camera là file sẵn, không qua thư viện');
    expect(find.text('2 / 2'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('camera bị từ chối quyền → hiện thông báo lỗi', (tester) async {
    final camera = FakeCamera()..error = const PermissionDenied();
    final h = Harness(tmp: tmp, camera: camera);
    await h.pump(tester);

    await tester.tap(find.byKey(const ValueKey('camera_tile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission denied'), findsOneWidget);
  });

  testWidgets('bấm vào ảnh nhỏ ở thanh đã chọn thì bỏ chọn', (tester) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester);
    await tester.tap(find.byKey(const ValueKey('asset_all_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selected_a:all_0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('next_button')), findsNothing);
  });

  testWidgets('bị từ chối quyền ảnh → màn xin quyền, nút cho phép hỏi lại', (
    tester,
  ) async {
    final gallery = FakeGallery(access: GalleryAccess.denied);
    final h = Harness(tmp: tmp, gallery: gallery);
    await h.pump(tester);

    expect(find.text('Photo access needed'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset_all_0')), findsNothing);

    gallery.access = GalleryAccess.granted;
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    expect(gallery.requestCount, 2);
    expect(find.byKey(const ValueKey('asset_all_0')), findsOneWidget);

    gallery.access = GalleryAccess.denied;
  });

  testWidgets('nút Mở cài đặt gọi dịch vụ', (tester) async {
    final gallery = FakeGallery(access: GalleryAccess.denied);
    final h = Harness(tmp: tmp, gallery: gallery);
    await h.pump(tester);
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(gallery.openSettingsCount, 1);
  });

  testWidgets('đổi album từ menu tiêu đề', (tester) async {
    final gallery = FakeGallery(
      albumList: const [
        GalleryAlbum(id: 'all', name: 'Recent', count: 6),
        GalleryAlbum(id: 'cam', name: 'Camera', count: 6),
      ],
    );
    final h = Harness(tmp: tmp, gallery: gallery);
    await h.pump(tester);

    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera (6)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('asset_cam_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset_all_0')), findsNothing);
  });

  testWidgets('chế độ thêm ảnh: trả về đường dẫn cho màn gọi, giới hạn theo chỗ còn lại', (
    tester,
  ) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester, initialLocation: '/image-to-pdf/add', extra: 2);
    expect(h.cleanerCalls, 0, reason: 'thêm ảnh không dọn file tạm của lượt đang làm');

    await tester.tap(find.byKey(const ValueKey('asset_all_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_2'))); // vượt giới hạn 2
    await tester.pump();
    expect(find.text('You can add up to 2 images.'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();
    // màn thêm ảnh đã đóng, quay lại trang dưới (HOME)
    expect(find.byKey(const ValueKey('next_button')), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(h.gallery.resolved, ['all_0', 'all_1']);
  });
}
