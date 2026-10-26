import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/features/scanner/ocr/ml_kit_ocr_engine.dart';

mlkit.TextLine _line(String t, Rect r) => mlkit.TextLine(
  text: t,
  elements: const [],
  boundingBox: r,
  recognizedLanguages: const [],
  cornerPoints: const <Point<int>>[],
  confidence: null,
  angle: null,
);

mlkit.TextBlock _block(List<mlkit.TextLine> lines) => mlkit.TextBlock(
  text: lines.map((l) => l.text).join('\n'),
  lines: lines,
  boundingBox: lines.first.boundingBox,
  recognizedLanguages: const [],
  cornerPoints: const <Point<int>>[],
);

void main() {
  test('mlKitScriptFor ánh xạ đủ 4 hệ chữ', () {
    expect(mlKitScriptFor(OcrScript.latin), mlkit.TextRecognitionScript.latin);
    expect(
      mlKitScriptFor(OcrScript.chinese),
      mlkit.TextRecognitionScript.chinese,
    );
    expect(
      mlKitScriptFor(OcrScript.japanese),
      mlkit.TextRecognitionScript.japanese,
    );
    expect(
      mlKitScriptFor(OcrScript.korean),
      mlkit.TextRecognitionScript.korean,
    );
  });

  test('ocrScriptForLanguage: vi/id/en → latin, zh/ja/ko đúng, th → latin', () {
    expect(ocrScriptForLanguage('vi'), OcrScript.latin);
    expect(ocrScriptForLanguage('id'), OcrScript.latin);
    expect(ocrScriptForLanguage('en'), OcrScript.latin);
    expect(ocrScriptForLanguage('th'), OcrScript.latin);
    expect(ocrScriptForLanguage('zh'), OcrScript.chinese);
    expect(ocrScriptForLanguage('ja'), OcrScript.japanese);
    expect(ocrScriptForLanguage('ko'), OcrScript.korean);
  });

  group('ocrResultFromMlKit', () {
    test('giữ block, dòng, toạ độ; toàn văn cách block bằng dòng trống', () {
      final rt = mlkit.RecognizedText(
        text: 'ignored',
        blocks: [
          _block([
            _line('Cộng hoà xã hội', const Rect.fromLTWH(10, 10, 200, 30)),
            _line('chủ nghĩa Việt Nam', const Rect.fromLTWH(10, 45, 220, 30)),
          ]),
          _block([_line('Độc lập', const Rect.fromLTWH(10, 120, 100, 30))]),
        ],
      );
      final r = ocrResultFromMlKit(rt, imageWidth: 800, imageHeight: 1200);
      expect(r.blocks, hasLength(2));
      expect(r.blocks[0].lines, hasLength(2));
      expect(r.blocks[0].lines[1].bounds, const Rect.fromLTWH(10, 45, 220, 30));
      expect(r.text, 'Cộng hoà xã hội\nchủ nghĩa Việt Nam\n\nĐộc lập');
      expect(r.imageWidth, 800);
      expect(r.imageHeight, 1200);
    });

    test('không có block → rỗng', () {
      final r = ocrResultFromMlKit(mlkit.RecognizedText(text: '', blocks: []));
      expect(r.text, '');
      expect(r.blocks, isEmpty);
    });
  });

  group('MlKitOcrEngine.recognize', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ocr_engine_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('đọc kích thước ảnh rồi gọi ML Kit với đúng hệ chữ', () async {
      final path = '${dir.path}/p.jpg';
      File(path).writeAsBytesSync(
        img.encodeJpg(img.Image(width: 64, height: 32), quality: 80),
      );
      mlkit.TextRecognitionScript? seen;
      final engine = MlKitOcrEngine(
        recognizeFn: (p, s) async {
          seen = s;
          return mlkit.RecognizedText(
            text: 'x',
            blocks: [
              _block([_line('Xin chào', const Rect.fromLTWH(1, 1, 5, 5))]),
            ],
          );
        },
      );
      final r = await engine.recognize(path, OcrScript.korean);
      expect(seen, mlkit.TextRecognitionScript.korean);
      expect(r.text, 'Xin chào');
      expect(r.imageWidth, 64);
      expect(r.imageHeight, 32);
    });

    test('file không tồn tại → CorruptFile', () async {
      final engine = MlKitOcrEngine(
        recognizeFn: (p, s) async => fail('không được gọi'),
      );
      expect(
        engine.recognize('${dir.path}/none.jpg', OcrScript.latin),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('ảnh hỏng → CorruptFile, không gọi ML Kit', () async {
      final path = '${dir.path}/bad.jpg';
      File(path).writeAsBytesSync([1, 2, 3, 4]);
      final engine = MlKitOcrEngine(
        recognizeFn: (p, s) async => fail('không được gọi'),
      );
      expect(
        engine.recognize(path, OcrScript.latin),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('lỗi từ plugin được đổi thành AppError', () async {
      final path = '${dir.path}/p.jpg';
      File(path)
          .writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
      final engine = MlKitOcrEngine(
        recognizeFn: (p, s) async => throw StateError('boom'),
      );
      expect(engine.recognize(path, OcrScript.latin), throwsA(isA<Unknown>()));
    });
  });
}
