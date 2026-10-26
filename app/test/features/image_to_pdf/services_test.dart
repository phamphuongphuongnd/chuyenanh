import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/image_to_pdf/services/gallery_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';
import 'package:pdf_office/features/image_to_pdf/services/output_registry.dart';

void main() {
  group('gallery_service (hàm thuần)', () {
    test('isDirectlyDecodableMime', () {
      expect(isDirectlyDecodableMime('image/jpeg'), isTrue);
      expect(isDirectlyDecodableMime('IMAGE/PNG'), isTrue);
      expect(isDirectlyDecodableMime('image/webp'), isTrue);
      expect(isDirectlyDecodableMime('image/heic'), isFalse);
      expect(isDirectlyDecodableMime('image/heif'), isFalse);
      expect(isDirectlyDecodableMime(null), isFalse);
    });

    test('fitWithin giữ tỉ lệ, không phóng to', () {
      expect(fitWithin(6000, 3000, 3000), (width: 3000, height: 1500));
      expect(fitWithin(3000, 6000, 3000), (width: 1500, height: 3000));
      expect(fitWithin(800, 600, 3000), (width: 800, height: 600));
      expect(fitWithin(0, 0, 3000), (width: 3000, height: 3000));
    });
  });

  group('output_registry', () {
    late Directory tmp;
    late AppDatabase db;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('img2pdf_reg');
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    test('registerOutputDocument thêm vào documents và recents', () async {
      final path = p.join(tmp.path, 'PDF Office', 'a.pdf');
      Directory(p.dirname(path)).createSync(recursive: true);
      File(path).writeAsBytesSync(List.filled(1234, 1));
      await registerOutputDocument(db, path);
      final doc = await db.documentsDao.getByPath(path);
      expect(doc, isNotNull);
      expect(doc!.name, 'a.pdf');
      expect(doc.ext, 'pdf');
      expect(doc.size, 1234);
      expect(doc.folder, 'PDF Office');
      final recents = await db.recentsDao.getRecent();
      expect(recents.map((e) => e.path), contains(path));
    });

    test('renameOutputDocument đổi file thật + DB, tránh ghi đè', () async {
      final a = p.join(tmp.path, 'a.pdf');
      final b = p.join(tmp.path, 'b.pdf');
      File(a).writeAsBytesSync([1]);
      File(b).writeAsBytesSync([2]);
      await registerOutputDocument(db, a);

      final renamed = await renameOutputDocument(db, a, 'c');
      expect(p.basename(renamed), 'c.pdf');
      expect(File(a).existsSync(), isFalse);
      expect(File(renamed).existsSync(), isTrue);
      expect(await db.documentsDao.getByPath(a), isNull);
      expect((await db.documentsDao.getByPath(renamed))!.name, 'c.pdf');

      // đổi sang tên đã có → thêm (1), file b còn nguyên
      final again = await renameOutputDocument(db, renamed, 'b');
      expect(p.basename(again), 'b (1).pdf');
      expect(File(b).readAsBytesSync(), [2]);
    });

    test('đổi sang đúng tên cũ → giữ nguyên', () async {
      final a = p.join(tmp.path, 'a.pdf');
      File(a).writeAsBytesSync([1]);
      expect(await renameOutputDocument(db, a, 'a'), a);
      expect(File(a).existsSync(), isTrue);
    });
  });

  group('IsolateImageProcessor', () {
    late Directory tmp;
    const proc = IsolateImageProcessor();

    setUp(() => tmp = Directory.systemTemp.createTempSync('img2pdf_proc'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String writeJpeg(String name, int w, int h) {
      final im = img.Image(width: w, height: h);
      img.fill(im, color: img.ColorRgb8(200, 10, 10));
      final f = File(p.join(tmp.path, name))
        ..writeAsBytesSync(img.encodeJpg(im, quality: 90));
      return f.path;
    }

    test('probe: kích thước đúng; file hỏng / không tồn tại → null', () async {
      final path = writeJpeg('a.jpg', 120, 80);
      final info = await proc.probe(path);
      expect(info!.width, 120);
      expect(info.height, 80);
      final bad = File(p.join(tmp.path, 'bad.jpg'))..writeAsBytesSync([1, 2, 3]);
      expect(await proc.probe(bad.path), isNull);
      expect(await proc.probe(p.join(tmp.path, 'none.jpg')), isNull);
    });

    test('renderPreview: ảnh xem trước nhỏ hơn cỡ tối đa và đã xoay', () async {
      final path = writeJpeg('a.jpg', 400, 200);
      final bytes = await proc.renderPreview(
        path,
        const ops.ImageEdit(rotationQuarterTurns: 1),
        maxSide: 100,
      );
      final info = ops.probe(bytes);
      expect(info.height, lessThanOrEqualTo(100));
      expect(info.height, greaterThan(info.width));
    });

    test('bake: ghi file mới đã áp xoay, không đụng file gốc', () async {
      final path = writeJpeg('a.jpg', 300, 100);
      final before = File(path).readAsBytesSync();
      final outDir = Directory(p.join(tmp.path, 'baked'));
      final baked = await proc.bake(
        path,
        const ops.ImageEdit(rotationQuarterTurns: 1),
        outDir: outDir,
        name: 'x',
      );
      expect(p.dirname(baked), outDir.path);
      final info = ops.probe(File(baked).readAsBytesSync());
      expect((info.width, info.height), (100, 300));
      expect(File(path).readAsBytesSync(), before);
    });

    test('bake ảnh hỏng → ném lỗi', () async {
      final bad = File(p.join(tmp.path, 'bad.jpg'))..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        proc.bake(
          bad.path,
          const ops.ImageEdit(),
          outDir: Directory(p.join(tmp.path, 'o')),
          name: 'y',
        ),
        throwsA(anything),
      );
    });
  });

  group('PreviewCache', () {
    test('cùng khoá chỉ render một lần; khác chỉnh sửa thì render lại', () async {
      final proc = _CountingProcessor();
      final cache = PreviewCache(proc);
      const e = ops.ImageEdit();
      await cache.get('/a', e);
      await cache.get('/a', e);
      expect(proc.renders, 1);
      await cache.get('/a', e.copyWith(filter: ops.ImageFilter.grayscale));
      expect(proc.renders, 2);
    });

    test('vượt dung lượng thì bỏ mục cũ nhất', () async {
      final proc = _CountingProcessor();
      final cache = PreviewCache(proc, capacity: 2);
      const e = ops.ImageEdit();
      await cache.get('/1', e);
      await cache.get('/2', e);
      await cache.get('/3', e); // đẩy /1 ra
      await cache.get('/1', e);
      expect(proc.renders, 4);
    });

    test('lỗi không bị giữ trong cache', () async {
      final proc = _CountingProcessor(failFirst: true);
      final cache = PreviewCache(proc);
      await expectLater(cache.get('/a', const ops.ImageEdit()), throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      await cache.get('/a', const ops.ImageEdit());
      expect(proc.renders, 2);
    });
  });
}

class _CountingProcessor implements ImageProcessor {
  _CountingProcessor({this.failFirst = false});

  final bool failFirst;
  int renders = 0;

  @override
  Future<ops.ImageInfoLite?> probe(String path) async => null;

  @override
  Future<Uint8List> renderPreview(
    String path,
    ops.ImageEdit edit, {
    int maxSide = 1024,
  }) async {
    renders++;
    if (failFirst && renders == 1) throw StateError('boom');
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
