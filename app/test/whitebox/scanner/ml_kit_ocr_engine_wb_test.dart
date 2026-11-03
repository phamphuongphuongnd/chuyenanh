// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng A07 — scanner/ocr/ml_kit_ocr_engine.dart (Bước 6).
// Plugin ML Kit thay bằng `recognizeFn` (interface sẵn có) hoặc mock MethodChannel của plugin.
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/features/scanner/ocr/ml_kit_ocr_engine.dart';

mlkit.TextLine _line(String t) => mlkit.TextLine(
      text: t,
      elements: const [],
      boundingBox: const Rect.fromLTWH(1, 2, 30, 10),
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
      confidence: null,
      angle: null,
    );

mlkit.TextBlock _block(String t) => mlkit.TextBlock(
      text: t,
      lines: [_line(t)],
      boundingBox: const Rect.fromLTWH(1, 2, 30, 10),
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
    );

const _channel = MethodChannel('google_mlkit_text_recognizer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String good;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('wb_mlkit_');
    good = '${dir.path}${Platform.pathSeparator}p.jpg';
    File(good).writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 30)));
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    dir.deleteSync(recursive: true);
  });

  group('U1 mlKitScriptFor', () {
    test('U1-B1 latin', () => expect(mlKitScriptFor(OcrScript.latin), mlkit.TextRecognitionScript.latin));
    // Đổi (chỉ Anh/Việt): U1-B2..B4 (chinese/japanese/korean) đã xoá cùng giá trị enum.
    test('U1-B2 enum chỉ còn latin', () => expect(OcrScript.values, [OcrScript.latin]));
  });

  group('U2 ocrResultFromMlKit', () {
    test('U2-B1 có block ⇒ toàn văn = các block (trim, bỏ rỗng) cách dòng trống', () {
      final r = ocrResultFromMlKit(
        mlkit.RecognizedText(text: 'bỏ qua', blocks: [_block(' Một '), _block('  '), _block('Hai')]),
        imageWidth: 40,
        imageHeight: 30,
      );
      expect(r.text, 'Một\n\nHai');
      expect(r.blocks, hasLength(3));
      expect(r.imageWidth, 40);
      expect(r.imageHeight, 30);
    });
    test('U2-B2 không có block ⇒ toàn văn = recognized.text đã trim', () {
      final r = ocrResultFromMlKit(mlkit.RecognizedText(text: '  chữ rời \n', blocks: []));
      expect(r.text, 'chữ rời');
      expect(r.blocks, isEmpty);
    });
  });

  group('U3 hàm dựng + U5 dispose', () {
    test('U3-B1 có recognizeFn ⇒ dùng fn, không gọi plugin', () async {
      var calls = 0;
      var channelCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (c) async => channelCalls++);
      final e = MlKitOcrEngine(recognizeFn: (p, s) async {
        calls++;
        return mlkit.RecognizedText(text: '', blocks: [_block('Xin chào')]);
      });
      final r = await e.recognize(good, OcrScript.latin);
      expect(calls, 1);
      expect(channelCalls, 0);
      expect(r.text, 'Xin chào');
    });
    test('U3-B2 recognizeFn null ⇒ gọi ML Kit (plugin); U5-B1 dispose đóng từng recognizer', () async {
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (c) async {
        log.add(c);
        if (c.method == 'vision#startTextRecognizer') {
          return <String, dynamic>{'text': 'Độc lập', 'blocks': <dynamic>[]};
        }
        return null;
      });
      final e = MlKitOcrEngine();
      final r1 = await e.recognize(good, OcrScript.latin);
      await e.recognize(good, OcrScript.latin);
      await e.recognize(good, OcrScript.latin);
      expect(log.where((c) => c.method == 'vision#startTextRecognizer'), hasLength(3));
      expect(r1.text, 'Độc lập');
      expect(r1.imageWidth, 40);
      await e.dispose();
      expect(log.where((c) => c.method == 'vision#closeTextRecognizer'), hasLength(1),
          reason: 'mỗi hệ chữ giữ 1 recognizer (nay chỉ latin)');
    });
    test('U5-B2 chưa tạo recognizer nào ⇒ dispose không gọi plugin', () async {
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (c) async => log.add(c));
      await MlKitOcrEngine().dispose();
      expect(log, isEmpty);
    });
  });

  group('U4 recognize', () {
    MlKitOcrEngine engine(Future<mlkit.RecognizedText> Function() body, List<int> calls) =>
        MlKitOcrEngine(recognizeFn: (p, s) {
          calls.add(1);
          return body();
        });

    test('U4-B1 ảnh tốt ⇒ OcrResult kèm kích thước ảnh', () async {
      final calls = <int>[];
      final r = await engine(() async => mlkit.RecognizedText(text: '', blocks: [_block('abc')]), calls)
          .recognize(good, OcrScript.latin);
      expect(calls, hasLength(1));
      expect(r.imageWidth, 40);
      expect(r.imageHeight, 30);
    });
    test('U4-B2 file không tồn tại ⇒ CorruptFile, không gọi ML Kit', () async {
      final calls = <int>[];
      final r = await engine(() async => mlkit.RecognizedText(text: '', blocks: []), calls)
          .recognize('${dir.path}/none.jpg', OcrScript.latin)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(calls, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U4-B3 ảnh hỏng ⇒ CorruptFile, không gọi ML Kit', () async {
      final bad = '${dir.path}/bad.jpg';
      File(bad).writeAsBytesSync([1, 2, 3, 4, 5]);
      final calls = <int>[];
      final r = await engine(() async => mlkit.RecognizedText(text: '', blocks: []), calls)
          .recognize(bad, OcrScript.latin)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(calls, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U4-B4 ML Kit ném AppError ⇒ giữ nguyên lỗi đó', () async {
      final calls = <int>[];
      final r = await engine(() async => throw const PermissionDenied(), calls)
          .recognize(good, OcrScript.latin)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(calls, hasLength(1));
      expect(r, isA<PermissionDenied>());
    });
    test('U4-B5 ML Kit ném lỗi khác ⇒ đổi thành AppError (Unknown)', () async {
      final calls = <int>[];
      final r = await engine(() async => throw StateError('native'), calls)
          .recognize(good, OcrScript.latin)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(calls, hasLength(1));
      expect(r, isA<Unknown>());
    });
  });
}
