import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/editor/edited_output.dart';
import 'package:pdf_office/features/editor/signature_image.dart';
import 'package:pdf_office/features/editor/signature_store.dart';

Uint8List _pngWithDot({
  int w = 60,
  int h = 40,
  int? dotX,
  int? dotY,
  int dotSize = 6,
}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  if (dotX != null && dotY != null) {
    for (var y = dotY; y < dotY + dotSize; y++) {
      for (var x = dotX; x < dotX + dotSize; x++) {
        image.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sig_store_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('SignatureStore', () {
    test('thu muc chua co: list rong, save tu tao thu muc', () async {
      final store = SignatureStore(Directory('${dir.path}/sub/signatures'));
      expect(await store.list(), isEmpty);
      final saved = await store.save(_pngWithDot(dotX: 5, dotY: 5));
      expect(File(saved.path).existsSync(), isTrue);
      expect(await store.list(), hasLength(1));
    });

    test('luu roi doc lai dung byte', () async {
      final store = SignatureStore(dir);
      final png = _pngWithDot(dotX: 1, dotY: 1);
      final saved = await store.save(png);
      expect(await store.read(saved), png);
    });

    test('moi nhat truoc, bo qua file la, xoa duoc', () async {
      final store = SignatureStore(dir);
      final a = await store.save(_pngWithDot(dotX: 1, dotY: 1));
      File('${dir.path}/note.txt').writeAsStringSync('x');
      final b = await store.save(_pngWithDot(dotX: 2, dotY: 2));
      File(a.path).setLastModifiedSync(DateTime(2020));
      final all = await store.list();
      expect(all.map((e) => e.path), [b.path, a.path]);
      await store.delete(a);
      expect((await store.list()).map((e) => e.path), [b.path]);
      await store.delete(a); // xoá lần hai không lỗi
    });

    test('vuot gioi han thi xoa cai cu nhat', () async {
      final store = SignatureStore(dir);
      final first = await store.save(_pngWithDot(dotX: 1, dotY: 1));
      File(first.path).setLastModifiedSync(DateTime(2020));
      for (var i = 0; i < kMaxSavedSignatures; i++) {
        await store.save(_pngWithDot(dotX: 2, dotY: 2));
      }
      final all = await store.list();
      expect(all, hasLength(kMaxSavedSignatures));
      expect(all.any((e) => e.path == first.path), isFalse);
    });
  });

  group('trimSignaturePng', () {
    test('cat sat net ve + le', () {
      final trimmed = trimSignaturePng(
        _pngWithDot(w: 100, h: 60, dotX: 30, dotY: 20, dotSize: 10),
        padding: 2,
      )!;
      final out = img.decodePng(trimmed)!;
      expect((out.width, out.height), (14, 14)); // 10 + 2*2
    });

    test('le bi kep trong anh khi net sat mep', () {
      final trimmed = trimSignaturePng(
        _pngWithDot(w: 30, h: 30, dotX: 0, dotY: 0, dotSize: 5),
        padding: 4,
      )!;
      final out = img.decodePng(trimmed)!;
      expect((out.width, out.height), (9, 9)); // 0..8
    });

    test('anh trong suot hoan toan -> null (chua ky)', () {
      expect(trimSignaturePng(_pngWithDot()), isNull);
    });

    test('PNG hong -> CorruptFile', () {
      expect(
        () => trimSignaturePng(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('pngAspectRatio', () {
      expect(pngAspectRatio(_pngWithDot(w: 80, h: 20)), closeTo(4, 1e-9));
      expect(
        () => pngAspectRatio(Uint8List.fromList([1])),
        throwsA(isA<CorruptFile>()),
      );
    });
  });

  group('editedOutputPath', () {
    test('them hau to, duoi .pdf, khong trung file goc', () async {
      final out = await editedOutputPath(
        dir.path,
        '/x/Hop dong.pdf',
        EditKind.sign,
      );
      expect(out.endsWith('Hop dong_signed.pdf'), isTrue);
    });

    test('trung ten thi them (1)', () async {
      File('${dir.path}/a_annotated.pdf').writeAsStringSync('x');
      final out = await editedOutputPath(
        dir.path,
        '/x/a.pdf',
        EditKind.annotate,
      );
      expect(out.endsWith('a_annotated (1).pdf'), isTrue);
    });

    test('writeEditedPdf ghi file moi, giu nguyen file goc', () async {
      final input = File('${dir.path}/in.pdf')..writeAsBytesSync([1, 2, 3]);
      final out = await writeEditedPdf(
        dir.path,
        input.path,
        EditKind.fillForm,
        [9, 9],
      );
      expect(File(out).readAsBytesSync(), [9, 9]);
      expect(input.readAsBytesSync(), [1, 2, 3]);
      expect(out.endsWith('in_filled.pdf'), isTrue);
    });
  });
}
