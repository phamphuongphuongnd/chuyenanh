// Kiểm thử hộp trắng (A06) — services/export_service.dart. Mã bộ = buoc-5-du-lieu-thu.md của export_service.
// Engine + processor là bản giả theo interface sẵn có (ImageToPdfEngine, ImageProcessor).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';
import 'package:pdf_office/features/image_to_pdf/services/export_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';

class _Proc implements ImageProcessor {
  _Proc({this.bad = const {}, this.createDir = true});
  final Set<String> bad;
  final bool createDir;
  final List<String> baked = [];

  @override
  Future<ops.ImageInfoLite?> probe(String path) => throw UnimplementedError();

  @override
  Future<Uint8List> renderPreview(String path, ops.ImageEdit edit, {int maxSide = 1024}) =>
      throw UnimplementedError();

  @override
  Future<String> bake(
    String path,
    ops.ImageEdit edit, {
    required Directory outDir,
    required String name,
    int jpegQuality = 95,
  }) async {
    baked.add(path);
    // Giống bản thật: ảnh hỏng ném trước khi tạo thư mục ra.
    if (bad.contains(path)) throw const FormatException('corrupt');
    final out = p.join(outDir.path, '$name.jpg');
    if (!createDir) return out;
    await outDir.create(recursive: true);
    File(out).writeAsBytesSync([1, 2, 3]);
    return out;
  }
}

class _Engine implements ImageToPdfEngine {
  Object? error;
  List<String> skipped = const [];
  int calls = 0;
  List<String>? paths;

  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls++;
    paths = imagePaths;
    if (error != null) throw error!;
    onProgress?.call(1);
    File(outputPath).writeAsBytesSync(List.filled(100, 7));
    return ImageToPdfResult(
      outputPath: outputPath,
      pageCount: imagePaths.length - skipped.length,
      skippedImages: skipped,
    );
  }
}

const _rot = ops.ImageEdit(rotationQuarterTurns: 1);

ImageItem _it(int id, {ops.ImageEdit edit = const ops.ImageEdit()}) => ImageItem(
  id: id,
  originalPath: '/img/$id.jpg',
  originalWidth: 100,
  originalHeight: 100,
  edit: edit,
);

void main() {
  late Directory tmp;
  late Directory work;
  late Directory out;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_a06_export');
    work = Directory(p.join(tmp.path, 'work'))..createSync();
    out = Directory(p.join(tmp.path, 'out'))..createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Object> run(
    ImageToPdfExporter ex,
    List<ImageItem> items, {
    ProgressCallback? onProgress,
    CancelToken? token,
  }) => ex
      .export(
        items: items,
        options: const ImageToPdfOptions(),
        outputDir: out.path,
        fileName: 'x',
        onProgress: onProgress,
        cancelToken: token,
      )
      .then<Object>((v) => v, onError: (Object e) => e);

  group('U1 normalizePdfName', () {
    test('1-1 tên thường ⇒ giữ nguyên (bỏ khoảng trắng hai đầu)', () {
      expect(normalizePdfName('  Báo cáo ', fallback: 'fb'), 'Báo cáo');
    });
    test('1-2 có đuôi .PDF ⇒ bỏ đuôi', () {
      expect(normalizePdfName('a.PDF', fallback: 'fb'), 'a');
    });
    test('1-3 rỗng sau khi bỏ khoảng trắng ⇒ tên dự phòng', () {
      expect(normalizePdfName('   ', fallback: 'fb'), 'fb');
    });
  });

  group('U2 export', () {
    test('2-1 1 ảnh đã xoay, có token + onProgress ⇒ PDF, engine nhận file đã áp chỉnh sửa, dọn file tạm', () async {
      final proc = _Proc();
      final eng = _Engine();
      final progress = <double>[];
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], onProgress: progress.add, token: CancelToken());
      expect(proc.baked, ['/img/1.jpg']);
      expect(eng.calls, 1);
      expect(eng.paths!.single, isNot('/img/1.jpg'), reason: 'engine nhận file đã nướng');
      expect(r, isA<ExportOutcome>());
      final o = r as ExportOutcome;
      expect(p.basename(o.outputPath), 'x.pdf');
      expect(p.dirname(o.outputPath), out.path);
      expect(o.pageCount, 1);
      expect(o.skippedCount, 0);
      expect(o.sizeBytes, File(o.outputPath).lengthSync());
      expect(progress.last, closeTo(1, 1e-9));
      expect(progress.first, lessThan(1));
      expect(work.listSync(), isEmpty, reason: 'file tạm đã dọn');
    });
    test('2-2 danh sách rỗng ⇒ CorruptFile, không gọi engine', () async {
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, const []);
      expect(eng.calls, 0);
      expect(r, isA<CorruptFile>());
    });
    test('2-3 không có token huỷ ⇒ vẫn tạo PDF', () async {
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], onProgress: (_) {});
      expect(eng.calls, 1);
      expect(r, isA<ExportOutcome>());
      expect(work.listSync(), isEmpty);
    });
    test('2-4 token đã huỷ trước khi bắt đầu ⇒ Cancelled, không nướng, không gọi engine', () async {
      final proc = _Proc();
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken()..cancel());
      expect(proc.baked, isEmpty);
      expect(eng.calls, 0);
      expect(r, isA<Cancelled>());
      expect(out.listSync(), isEmpty);
    });
    test('2-7 huỷ trong lúc nướng (sau ảnh 1) ⇒ Cancelled, dừng trước ảnh 2, không PDF, dọn file tạm', () async {
      final proc = _Proc();
      final eng = _Engine();
      final token = CancelToken();
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(
        ex,
        [_it(1, edit: _rot), _it(2, edit: _rot)],
        token: token,
        onProgress: (_) => token.cancel(),
      );
      expect(proc.baked, ['/img/1.jpg']);
      expect(eng.calls, 0);
      expect(r, isA<Cancelled>());
      expect(out.listSync(), isEmpty);
      expect(work.listSync(), isEmpty);
    });
    test('2-8 ảnh chưa chỉnh sửa ⇒ không nướng, engine nhận file gốc', () async {
      final proc = _Proc();
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(ex, [_it(1)], token: CancelToken(), onProgress: (_) {});
      expect(proc.baked, isEmpty);
      expect(eng.paths, ['/img/1.jpg']);
      expect(r, isA<ExportOutcome>());
      expect(work.listSync(), isEmpty);
    });
    test('2-9 mọi ảnh đã sửa đều hỏng ⇒ CorruptFile, không gọi engine, không PDF', () async {
      final proc = _Proc(bad: {'/img/1.jpg'});
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken(), onProgress: (_) {});
      expect(proc.baked, ['/img/1.jpg']);
      expect(eng.calls, 0);
      expect(r, isA<CorruptFile>());
      expect(out.listSync(), isEmpty);
      expect(work.listSync(), isEmpty);
    });
    test('2-10 không có onProgress ⇒ vẫn tạo PDF', () async {
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken());
      expect(eng.calls, 1);
      expect(r, isA<ExportOutcome>());
    });
    test('2-13 huỷ sau khi nướng xong, trước engine ⇒ Cancelled, không gọi engine, dọn file tạm', () async {
      final eng = _Engine();
      final token = CancelToken();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: token, onProgress: (_) => token.cancel());
      expect(eng.calls, 0);
      expect(r, isA<Cancelled>());
      expect(out.listSync(), isEmpty);
      expect(work.listSync(), isEmpty);
    });
    test('2-14 engine báo AppError (NoSpace) ⇒ ném đúng lỗi đó, dọn file tạm', () async {
      final eng = _Engine()..error = const NoSpace();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken(), onProgress: (_) {});
      expect(eng.calls, 1);
      expect(r, isA<NoSpace>());
      expect(work.listSync(), isEmpty);
    });
    test('2-15 engine ném lỗi lạ ⇒ đổi thành AppError, dọn file tạm', () async {
      final eng = _Engine()..error = StateError('boom');
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken(), onProgress: (_) {});
      expect(eng.calls, 1);
      expect(r, isA<AppError>());
      expect(work.listSync(), isEmpty);
    });
    test('2-16 nướng xong nhưng không có thư mục tạm ⇒ vẫn trả kết quả, không lỗi khi dọn', () async {
      final eng = _Engine();
      final ex = ImageToPdfExporter(engine: eng, processor: _Proc(createDir: false), workDir: work);
      final r = await run(ex, [_it(1, edit: _rot)], token: CancelToken(), onProgress: (_) {});
      expect(eng.calls, 1);
      expect(r, isA<ExportOutcome>());
    });
    test('2-17 (bổ sung) 1 ảnh sửa hỏng + 1 ảnh sửa tốt, engine bỏ 1 ⇒ skippedCount = 2', () async {
      final proc = _Proc(bad: {'/img/1.jpg'});
      final eng = _Engine()..skipped = ['whatever'];
      final ex = ImageToPdfExporter(engine: eng, processor: proc, workDir: work);
      final r = await run(
        ex,
        [_it(1, edit: _rot), _it(2, edit: _rot), _it(3)],
        token: CancelToken(),
        onProgress: (_) {},
      );
      expect(proc.baked, ['/img/1.jpg', '/img/2.jpg']);
      expect(eng.paths, hasLength(2));
      expect((r as ExportOutcome).skippedCount, 2);
    });
  });

  group('U3 onProgress của engine (lambda dòng 113)', () {
    test('3-1 onProgress null, engine báo tiến độ ⇒ không ném', () async {
      final ex = ImageToPdfExporter(engine: _Engine(), processor: _Proc(), workDir: work);
      final r = await run(ex, [_it(1)]);
      expect(r, isA<ExportOutcome>());
    });
    test('3-2 onProgress có, engine báo 100% ⇒ nhận 1.0', () async {
      final got = <double>[];
      final ex = ImageToPdfExporter(engine: _Engine(), processor: _Proc(), workDir: work);
      await run(ex, [_it(1)], onProgress: got.add);
      expect(got, [closeTo(1, 1e-9)]);
    });
  });
}
