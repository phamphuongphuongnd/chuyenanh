// ignore_for_file: depend_on_referenced_packages, unnecessary_import
// Kiểm thử hộp trắng (A06) — services/photo_picker_service.dart. Mã bộ = buoc-5-du-lieu-thu.md của
// photo_picker_service. Plugin image_picker được thay qua `ImagePickerPlatform.instance` (bản giả);
// codec hệ thống (dart:ui) chạy thật trong `tester.runAsync` (giống test/features/image_to_pdf/services_test.dart).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/image_to_pdf/services/photo_picker_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePicker extends Fake
    with MockPlatformInterfaceMixin
    implements ImagePickerPlatform {
  String? single;
  List<String> multi = const [];
  PlatformException? error;
  int singleCalls = 0;
  final List<MultiImagePickerOptions> multiCalls = [];
  ImageSource? singleSource;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleCalls++;
    singleSource = source;
    if (error != null) throw error!;
    return single == null ? null : XFile(single!);
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiCalls.add(options);
    if (error != null) throw error!;
    return [for (final m in multi) XFile(m)];
  }
}

List<int> _ftyp(String brand) => [0, 0, 0, 0x18, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0];

void main() {
  const svc = ImagePickerPhotoPickerService();

  group('U1 pickImages', () {
    late ImagePickerPlatform saved;
    late _FakePicker picker;
    setUp(() {
      saved = ImagePickerPlatform.instance;
      picker = _FakePicker();
      ImagePickerPlatform.instance = picker;
    });
    tearDown(() => ImagePickerPlatform.instance = saved);

    Future<Object> pick(int? limit) =>
        svc.pickImages(limit: limit).then<Object>((v) => v, onError: (Object e) => e);

    test('1-1 limit 5 ⇒ chọn nhiều, giới hạn 5, trả đường dẫn theo thứ tự hệ thống', () async {
      picker.multi = ['/b.jpg', '/a.jpg'];
      final r = await pick(5);
      expect(picker.singleCalls, 0);
      expect(picker.multiCalls.single.limit, 5);
      expect(r, ['/b.jpg', '/a.jpg']);
    });
    test('1-2 limit 1 ⇒ chọn 1 ảnh từ thư viện, trả [đường dẫn]', () async {
      picker.single = '/one.jpg';
      final r = await pick(1);
      expect(picker.multiCalls, isEmpty);
      expect(picker.singleSource, ImageSource.gallery);
      expect(r, ['/one.jpg']);
    });
    test('1-3 limit 1, người dùng huỷ ⇒ danh sách rỗng', () async {
      final r = await pick(1);
      expect(picker.singleCalls, 1);
      expect(r, isEmpty);
    });
    test('1-4 limit 1, bị chặn truy cập ảnh ⇒ PermissionDenied', () async {
      picker.error = PlatformException(code: 'photo_access_denied');
      final r = await pick(1);
      expect(picker.singleCalls, 1);
      expect(r, isA<PermissionDenied>());
    });
    test('1-5 lỗi nền tảng khác ⇒ AppError (không phải PermissionDenied)', () async {
      picker.error = PlatformException(code: 'already_active');
      final r = await pick(1);
      expect(r, isA<AppError>());
      expect(r, isNot(isA<PermissionDenied>()));
    });
    test('1-6 không giới hạn (null) ⇒ chọn nhiều không truyền limit', () async {
      picker.multi = ['/a.jpg'];
      final r = await pick(null);
      expect(picker.multiCalls.single.limit, isNull);
      expect(r, ['/a.jpg']);
    });
    test('1-7 limit 0 (chỉ mức unit) ⇒ không ném, đi nhánh chọn nhiều (*)', () async {
      picker.multi = ['/a.jpg'];
      final r = await pick(0);
      expect(picker.singleCalls, 0);
      expect(picker.multiCalls.single.limit, isNull);
      expect(r, ['/a.jpg']);
    });
    test('1-8 limit 5, bị chặn truy cập ảnh ⇒ PermissionDenied', () async {
      picker.error = PlatformException(code: 'photo_access_denied');
      final r = await pick(5);
      expect(picker.multiCalls, hasLength(1));
      expect(r, isA<PermissionDenied>());
    });
  });

  group('U2 prepareFile + U3 _readHead', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('wb_a06_pick'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('2-1 / 3-1 PNG đọc được ⇒ giữ nguyên đường dẫn, không tạo file tạm', () async {
      final f = File(p.join(tmp.path, 'a.png'))
        ..writeAsBytesSync(img.encodePng(img.Image(width: 3, height: 3)));
      final work = Directory(p.join(tmp.path, 'work'));
      expect(await svc.prepareFile(f.path, work), f.path);
      expect(work.existsSync(), isFalse);
    });
    test('2-2 / 3-2 file không mở được ⇒ null', () async {
      final work = Directory(p.join(tmp.path, 'work'));
      expect(await svc.prepareFile(p.join(tmp.path, 'missing.jpg'), work), isNull);
      expect(work.existsSync(), isFalse);
    });
    testWidgets('2-3 định dạng phải đổi (ICO) ⇒ JPEG mới trong workDir', (tester) async {
      final f = File(p.join(tmp.path, 'icon.ico'))
        ..writeAsBytesSync(img.encodeIco(img.Image(width: 16, height: 16)));
      expect(isDirectlyDecodableMime(detectImageMime(f.readAsBytesSync())), isFalse,
          reason: 'điều kiện đường: không đọc thẳng');
      final work = Directory(p.join(tmp.path, 'work'));
      final out = await tester.runAsync(() => svc.prepareFile(f.path, work));
      expect(out, isNotNull);
      expect(p.dirname(out!), work.path);
      expect(p.extension(out), '.jpg');
      expect(detectImageMime(File(out).readAsBytesSync()), 'image/jpeg');
    });
  });

  group('U4 isDirectlyDecodableMime', () {
    test('4-1 null ⇒ false', () => expect(isDirectlyDecodableMime(null), isFalse));
    test('4-2 image/heic ⇒ false', () => expect(isDirectlyDecodableMime('image/heic'), isFalse));
    test('4-3 IMAGE/WEBP ⇒ true', () => expect(isDirectlyDecodableMime('IMAGE/WEBP'), isTrue));
  });

  group('U5 detectImageMime (+ U5a at)', () {
    test('5-1 JPEG', () {
      expect(detectImageMime(img.encodeJpg(img.Image(width: 2, height: 2))), 'image/jpeg');
    });
    test('5-2 PNG', () {
      expect(detectImageMime(img.encodePng(img.Image(width: 2, height: 2))), 'image/png');
    });
    test('5-3 GIF', () {
      expect(detectImageMime(img.encodeGif(img.Image(width: 2, height: 2))), 'image/gif');
    });
    test('5-4 RIFF…WEBP', () {
      expect(detectImageMime([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]), 'image/webp');
    });
    test('5-5 RIFF nhưng không phải WEBP (WAVE) ⇒ null', () {
      expect(detectImageMime([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]), isNull);
    });
    test('5-6 BMP', () {
      expect(detectImageMime(img.encodeBmp(img.Image(width: 2, height: 2))), 'image/bmp');
    });
    test('5-7 ftyp avif ⇒ image/avif', () => expect(detectImageMime(_ftyp('avif')), 'image/avif'));
    test('5-8 ftyp heic ⇒ image/heic', () => expect(detectImageMime(_ftyp('heic')), 'image/heic'));
    test('5-9 ftyp mif1 ⇒ image/heif', () => expect(detectImageMime(_ftyp('mif1')), 'image/heif'));
    test('5-10 ftyp isom (video MP4) ⇒ null', () => expect(detectImageMime(_ftyp('isom')), isNull));
    test('5-11 ftyp nhưng chỉ 10 byte (thiếu brand) ⇒ null', () {
      expect(detectImageMime([0, 0, 0, 0, ...'ftyp'.codeUnits, 0x68, 0x65]), isNull);
    });
    test('5-12 không khớp chữ ký nào / quá ngắn ⇒ null', () {
      expect(detectImageMime(const [1, 2, 3]), isNull);
      expect(detectImageMime(const []), isNull);
    });
  });

  group('U6 fitWithin', () {
    test('6-1 width ≤ 0 ⇒ kích thước dương ≤ maxSide (*)', () {
      final r = fitWithin(0, 500, 3000);
      expect(r.width, inInclusiveRange(1, 3000));
      expect(r.height, inInclusiveRange(1, 3000));
    });
    test('6-2 height ≤ 0 ⇒ kích thước dương ≤ maxSide (*)', () {
      final r = fitWithin(500, 0, 3000);
      expect(r.width, inInclusiveRange(1, 3000));
      expect(r.height, inInclusiveRange(1, 3000));
    });
    test('6-3 đã vừa ⇒ giữ nguyên', () => expect(fitWithin(800, 600, 3000), (width: 800, height: 600)));
    test('6-4 lớn hơn ⇒ cạnh dài = maxSide, giữ tỉ lệ', () {
      expect(fitWithin(4000, 3000, 3000), (width: 3000, height: 2250));
    });
  });

  group('U8 convertImageFileToJpeg', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('wb_a06_conv'));
    tearDown(() => tmp.deleteSync(recursive: true));

    testWidgets('8-1 ảnh giải mã được, cạnh dài 3200 ⇒ JPEG cạnh dài 3000 ở dst', (tester) async {
      final src = File(p.join(tmp.path, 's.png'))
        ..writeAsBytesSync(img.encodePng(img.Image(width: 3200, height: 8)));
      final dst = p.join(tmp.path, 'o.jpg');
      final out = await tester.runAsync(() => convertImageFileToJpeg(src.path, dst));
      expect(out, dst);
      final bytes = File(dst).readAsBytesSync();
      expect(detectImageMime(bytes), 'image/jpeg');
      expect(img.decodeJpg(Uint8List.fromList(bytes))!.width, 3000);
    });
    testWidgets('8-2 file nguồn không tồn tại ⇒ null, không ghi dst', (tester) async {
      final dst = p.join(tmp.path, 'o.jpg');
      final out = await tester.runAsync(() => convertImageFileToJpeg(p.join(tmp.path, 'none.heic'), dst));
      expect(out, isNull);
      expect(File(dst).existsSync(), isFalse);
    });
    testWidgets('8-3 dữ liệu không phải ảnh ⇒ null, không ghi dst', (tester) async {
      final src = File(p.join(tmp.path, 'x.heic'))..writeAsBytesSync(List.filled(64, 7));
      final dst = p.join(tmp.path, 'o.jpg');
      final out = await tester.runAsync(() => convertImageFileToJpeg(src.path, dst));
      expect(out, isNull);
      expect(File(dst).existsSync(), isFalse);
    });
  });
}
