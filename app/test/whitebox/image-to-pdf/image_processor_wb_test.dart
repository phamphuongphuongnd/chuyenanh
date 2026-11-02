// Kiểm thử hộp trắng (A06) — services/image_processor.dart. Mã bộ = buoc-5-du-lieu-thu.md của image_processor.
// path_provider được thay qua `PathProviderPlatform.instance` (giống test/core/ios_simulation_test.dart).
// Hai gói interface có sẵn qua path_provider (phụ thuộc bắc cầu), không thêm vào pubspec.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.tmp);
  final String tmp;
  @override
  Future<String?> getTemporaryPath() async => tmp;
}

class _CountingProcessor implements ImageProcessor {
  int renders = 0;
  @override
  Future<ops.ImageInfoLite?> probe(String path) async => null;
  @override
  Future<Uint8List> renderPreview(String path, ops.ImageEdit edit, {int maxSide = 1024}) async {
    renders++;
    return Uint8List.fromList([renders]);
  }

  @override
  Future<String> bake(
    String path,
    ops.ImageEdit edit, {
    required Directory outDir,
    required String name,
    int jpegQuality = 95,
  }) async => path;
}

/// Sửa trường chiều cao (Y, [offset] 5) hoặc chiều rộng (X, [offset] 7) trong SOF0 của JPEG
/// thành 0 — header hợp lệ về cú pháp.
Uint8List _jpegWithZero(Uint8List jpg, {int offset = 5}) {
  final b = Uint8List.fromList(jpg);
  for (var i = 0; i + 8 < b.length; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xC0) {
      b[i + offset] = 0;
      b[i + offset + 1] = 0;
      return b;
    }
  }
  throw StateError('no SOF0');
}

Uint8List _jpegWithZeroHeight(Uint8List jpg) => _jpegWithZero(jpg);

void main() {
  late Directory tmp;
  const proc = IsolateImageProcessor();
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_a06_proc'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  Uint8List jpeg(int w, int h) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(200, 10, 10));
    return Uint8List.fromList(img.encodeJpg(im, quality: 85));
  }

  group('U1 clearImg2pdfWorkDir', () {
    late PathProviderPlatform saved;
    setUp(() {
      saved = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    });
    tearDown(() => PathProviderPlatform.instance = saved);

    test('1-1 có thư mục img2pdf từ lượt trước ⇒ xoá sạch', () async {
      final dir = Directory(p.join(tmp.path, 'img2pdf'))..createSync();
      File(p.join(dir.path, 'old.jpg')).writeAsBytesSync([1]);
      await clearImg2pdfWorkDir();
      expect(dir.existsSync(), isFalse);
    });
    test('1-2 chưa có thư mục ⇒ không lỗi, không tạo gì', () async {
      await clearImg2pdfWorkDir();
      expect(Directory(p.join(tmp.path, 'img2pdf')).existsSync(), isFalse);
      expect((await img2pdfWorkDir()).path, p.join(tmp.path, 'img2pdf'));
    });
  });

  group('U2 _probeSync (qua probe)', () {
    test('2-1 JPEG hợp lệ 120×80 ⇒ thông tin đúng kích thước', () async {
      final info = await proc.probe(write('a.jpg', jpeg(120, 80)));
      expect((info!.width, info.height), (120, 80));
    });
    test('2-2 file hỏng ⇒ null', () async {
      expect(await proc.probe(write('bad.jpg', [1, 2, 3])), isNull);
    });
    test('2-3 JPEG header có chiều rộng 0 ⇒ null', () async {
      final bytes = _jpegWithZero(jpeg(40, 30), offset: 7);
      final pre = (() {
        try {
          return ops.probe(bytes);
        } catch (e) {
          return e;
        }
      })();
      expect(pre, isA<ops.ImageInfoLite>(), reason: 'đường 2-3 cần probe không ném');
      expect((pre as ops.ImageInfoLite).width, 0);
      expect(await proc.probe(write('zw.jpg', bytes)), isNull);
    });
    test('2-4 JPEG header có chiều cao 0 ⇒ null', () async {
      final bytes = _jpegWithZeroHeight(jpeg(40, 30));
      // Điều kiện đường (D1 S): ops.probe đọc được header, trả chiều cao 0.
      final pre = (() {
        try {
          return ops.probe(bytes);
        } catch (e) {
          return e;
        }
      })();
      expect(pre, isA<ops.ImageInfoLite>(), reason: 'đường 2-4 cần probe không ném');
      expect((pre as ops.ImageInfoLite).height, 0);
      expect(await proc.probe(write('zero.jpg', bytes)), isNull);
    });
  });

  group('U3 _bakeSync (qua bake) — cạnh dài ảnh nhúng', () {
    Future<(int, int)> bakeSize(ops.ImageEdit edit) async {
      final out = await proc.bake(
        write('wide.jpg', jpeg(3200, 10)),
        edit,
        outDir: Directory(p.join(tmp.path, 'o')),
        name: 'b${edit.maxLongSide}',
      );
      final info = ops.probe(File(out).readAsBytesSync());
      return (info.width, info.height);
    }

    test('3-1 không đặt maxLongSide, ảnh 3200 px ⇒ thu về 3000', () async {
      final (w, _) = await bakeSize(const ops.ImageEdit());
      expect(w, 3000);
    });
    test('3-2 maxLongSide 100 (< 3000) ⇒ cạnh dài 100', () async {
      final (w, _) = await bakeSize(const ops.ImageEdit(maxLongSide: 100));
      expect(w, 100);
    });
    test('3-3 maxLongSide 5000 (≥ 3000) ⇒ vẫn chặn ở 3000', () async {
      final (w, _) = await bakeSize(const ops.ImageEdit(maxLongSide: 5000));
      expect(w, 3000);
    });
    test('PH-maxLongSide≤0 (0 hoặc âm) ⇒ dùng mặc định, chặn ở 3000', () async {
      final (w0, _) = await bakeSize(const ops.ImageEdit(maxLongSide: 0));
      expect(w0, 3000);
      final (wNeg, _) = await bakeSize(const ops.ImageEdit(maxLongSide: -5));
      expect(wNeg, 3000);
    });
  });

  group('U4 bake', () {
    test('4-1 JPEG không trong suốt ⇒ ghi .jpg mới trong outDir, file gốc không đổi', () async {
      final src = write('a.jpg', jpeg(60, 40));
      final before = File(src).readAsBytesSync();
      final outDir = Directory(p.join(tmp.path, 'baked'));
      final out = await proc.bake(src, const ops.ImageEdit(rotationQuarterTurns: 1), outDir: outDir, name: 'x');
      expect(p.dirname(out), outDir.path);
      expect(p.basename(out), 'x.jpg');
      expect(File(out).readAsBytesSync().first, 0xFF);
      expect(File(src).readAsBytesSync(), before);
    });
    test('4-2 PNG có điểm trong suốt ⇒ ghi .png', () async {
      final im = img.Image(width: 8, height: 8, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(10, 20, 30, 255));
      im.setPixelRgba(0, 0, 0, 0, 0, 0);
      final src = write('t.png', img.encodePng(im));
      final out = await proc.bake(src, const ops.ImageEdit(), outDir: Directory(p.join(tmp.path, 'b2')), name: 'y');
      expect(p.extension(out), '.png');
      expect(File(out).readAsBytesSync().first, 0x89);
    });
    test('4-3 ảnh hỏng ⇒ ném lỗi, không tạo file', () async {
      final outDir = Directory(p.join(tmp.path, 'b3'));
      final r = await proc
          .bake(write('bad.jpg', [1, 2, 3]), const ops.ImageEdit(), outDir: outDir, name: 'z')
          .then<Object>((v) => v, onError: (Object e) => e);
      expect(r, isNot(isA<String>()));
      expect(outDir.existsSync(), isFalse);
    });
  });

  group('U5 PreviewCache.get', () {
    const e = ops.ImageEdit();
    test('5-1 lần đầu (miss), chưa đầy ⇒ render 1 lần', () async {
      final pr = _CountingProcessor();
      final c = PreviewCache(pr, capacity: 2);
      expect(await c.get('/a', e), [1]);
      expect(pr.renders, 1);
    });
    test('5-2 lần hai cùng khoá (hit) ⇒ không render lại, cùng kết quả', () async {
      final pr = _CountingProcessor();
      final c = PreviewCache(pr, capacity: 2);
      final f1 = c.get('/a', e);
      final f2 = c.get('/a', e);
      expect(identical(f1, f2), isTrue);
      expect(pr.renders, 1);
    });
    test('5-3 vượt dung lượng ⇒ bỏ mục cũ nhất', () async {
      final pr = _CountingProcessor();
      final c = PreviewCache(pr, capacity: 1);
      await c.get('/a', e);
      await c.get('/b', e); // đẩy /a ra
      await c.get('/a', e);
      expect(pr.renders, 3);
    });
    test('5-4 (bổ sung) mục vừa dùng lại được giữ (LRU), mục ít dùng bị bỏ', () async {
      final pr = _CountingProcessor();
      final c = PreviewCache(pr, capacity: 2);
      await c.get('/a', e);
      await c.get('/b', e);
      await c.get('/a', e); // hit ⇒ /a lên cuối
      await c.get('/c', e); // bỏ /b
      final before = pr.renders;
      await c.get('/a', e);
      expect(pr.renders, before, reason: '/a còn trong cache');
      await c.get('/b', e);
      expect(pr.renders, before + 1, reason: '/b đã bị bỏ');
    });
  });
}
