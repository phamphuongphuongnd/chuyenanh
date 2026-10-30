import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/id_card/id_card_services.dart';

class FakePdfEngine implements ImageToPdfEngine {
  List<String>? paths;
  ImageToPdfOptions? options;
  bool inputExisted = false;

  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    paths = imagePaths;
    this.options = options;
    inputExisted = File(imagePaths.single).existsSync();
    await File(outputPath).writeAsString('%PDF');
    return ImageToPdfResult(outputPath: outputPath, pageCount: 1);
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('idcard_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('deleteFilesUnder chỉ xoá file nằm trong thư mục gốc', () async {
    final inside = File(p.join(tmp.path, 'cache', 'a.jpg'))
      ..createSync(recursive: true);
    final outsideDir = Directory.systemTemp.createTempSync('idcard_out');
    addTearDown(() => outsideDir.deleteSync(recursive: true));
    final outside = File(p.join(outsideDir.path, 'b.jpg'))..createSync();
    final n = await deleteFilesUnder(p.join(tmp.path, 'cache'), [
      inside.path,
      outside.path,
      p.join(tmp.path, 'cache', 'missing.jpg'),
    ]);
    expect(n, 1);
    expect(inside.existsSync(), isFalse);
    expect(outside.existsSync(), isTrue);
  });

  test('xuất JPG ghi đúng byte, không đè file trùng tên', () async {
    final engine = FakePdfEngine();
    final ex = DefaultIdCardExporter(engine, () async => tmp);
    File(p.join(tmp.path, 'IDCard_x.jpg')).writeAsStringSync('old');
    final out = await ex.export(
      page: Uint8List.fromList([1, 2, 3]),
      format: IdCardFormat.jpg,
      outputDir: tmp.path,
      baseName: 'IDCard_x',
    );
    expect(p.basename(out), 'IDCard_x (1).jpg');
    expect(File(out).readAsBytesSync(), [1, 2, 3]);
    expect(engine.paths, isNull);
  });

  test('xuất PDF: 1 trang A4 dọc lề 0, dọn ảnh tạm', () async {
    final engine = FakePdfEngine();
    final work = Directory(p.join(tmp.path, 'work'))..createSync();
    final ex = DefaultIdCardExporter(engine, () async => work);
    final out = await ex.export(
      page: Uint8List.fromList([1, 2, 3]),
      format: IdCardFormat.pdf,
      outputDir: tmp.path,
      baseName: 'IDCard_y',
    );
    expect(p.basename(out), 'IDCard_y.pdf');
    expect(engine.inputExisted, isTrue);
    expect(engine.options!.pageSize, PageSizeOption.a4);
    expect(engine.options!.orientation, PageOrientation.portrait);
    expect(engine.options!.margin, PageMargin.none);
    expect(work.listSync(), isEmpty);
  });

  test('IdCardRequest: xem trước nửa độ phân giải, tỉ lệ A4', () {
    const side = IdCardSide('a.jpg');
    final full = const IdCardRequest(front: side, back: side).layout;
    final prev = const IdCardRequest(
      front: side,
      back: side,
      preview: true,
    ).layout;
    expect(full.pageWidthPx, 2480);
    expect(full.pageHeightPx, 3508);
    expect(prev.pageWidthPx * 2, full.pageWidthPx);
    expect(side.rotated().rotated().rotated().rotated().turns, 0);
  });
}
