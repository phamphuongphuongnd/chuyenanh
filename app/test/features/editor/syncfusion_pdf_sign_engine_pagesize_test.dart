import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/editor/syncfusion_pdf_sign_engine.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<Uint8List> _makePdf(List<sf.PdfPageRotateAngle> rotations) async {
  final doc = sf.PdfDocument();
  doc.compressionLevel = sf.PdfCompressionLevel.none;
  doc.pageSettings.size = const Size(300, 500);
  for (final r in rotations) {
    doc.pageSettings.rotate = r;
    doc.pages.add().graphics.drawString(
      'page',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

void main() {
  test('pageSize nhiều trang chỉ parse file một lần', () async {
    final bytes = await _makePdf([
      sf.PdfPageRotateAngle.rotateAngle90,
      sf.PdfPageRotateAngle.rotateAngle90,
      sf.PdfPageRotateAngle.rotateAngle90,
    ]);
    final dir = Directory.systemTemp.createTempSync('pgsize');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/a.pdf')..writeAsBytesSync(bytes);
    SyncfusionPdfSignEngine.debugClearPageSizeCache();
    const engine = SyncfusionPdfSignEngine();
    final s0 = await engine.pageSize(f.path, 0);
    final s1 = await engine.pageSize(f.path, 1);
    final s2 = await engine.pageSize(f.path, 2);
    expect(s0, const Size(500, 300));
    expect(s1, const Size(500, 300));
    expect(s2, const Size(500, 300));
    expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 1);
    await expectLater(engine.pageSize(f.path, 9), throwsA(isA<CorruptFile>()));
  });
}
