import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/office_viewer/data/text_decoder.dart';

Uint8List _utf16le(String s, {bool bom = true}) {
  final out = <int>[if (bom) ...[0xFF, 0xFE]];
  for (final u in s.codeUnits) {
    out
      ..add(u & 0xFF)
      ..add(u >> 8);
  }
  return Uint8List.fromList(out);
}

Uint8List _utf16be(String s, {bool bom = true}) {
  final out = <int>[if (bom) ...[0xFE, 0xFF]];
  for (final u in s.codeUnits) {
    out
      ..add(u >> 8)
      ..add(u & 0xFF);
  }
  return Uint8List.fromList(out);
}

void main() {
  const sample = 'Xin chào thế giới — 你好 😀';

  group('decodeText', () {
    test('UTF-8 không BOM', () {
      final r = decodeText(Uint8List.fromList(utf8.encode(sample)));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, sample);
    });

    test('UTF-8 có BOM: bỏ BOM', () {
      final r = decodeText(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(sample)]),
      );
      expect(r.encoding, TextEncoding.utf8Bom);
      expect(r.text, sample);
    });

    test('UTF-16 LE có BOM', () {
      final r = decodeText(_utf16le(sample));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, sample);
    });

    test('UTF-16 BE có BOM', () {
      final r = decodeText(_utf16be(sample));
      expect(r.encoding, TextEncoding.utf16be);
      expect(r.text, sample);
    });

    test('UTF-16 LE/BE không BOM (chữ Latin nhiều byte 0)', () {
      const latin = 'Hello world, this is plain text';
      expect(decodeText(_utf16le(latin, bom: false)).encoding, TextEncoding.utf16le);
      expect(decodeText(_utf16le(latin, bom: false)).text, latin);
      expect(decodeText(_utf16be(latin, bom: false)).encoding, TextEncoding.utf16be);
      expect(decodeText(_utf16be(latin, bom: false)).text, latin);
    });

    test('byte không hợp lệ UTF-8 → Windows-1252', () {
      // "café “x”" với é = 0xE9, “ = 0x93, ” = 0x94
      final r = decodeText(
        Uint8List.fromList([0x63, 0x61, 0x66, 0xE9, 0x20, 0x93, 0x78, 0x94]),
      );
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'café “x”');
    });

    test('rỗng → UTF-8, chuỗi rỗng', () {
      final r = decodeText(Uint8List(0));
      expect(r.text, '');
      expect(r.encoding, TextEncoding.utf8);
    });

    test('bị cắt giữa ký tự UTF-8: bỏ byte dở khi truncated', () {
      final bytes = Uint8List.fromList(utf8.encode('abc ế'));
      final cut = Uint8List.sublistView(bytes, 0, bytes.length - 1);
      final r = decodeText(cut, truncated: true);
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'abc ');
      expect(r.truncated, isTrue);
    });
  });

  test('splitLines xử lý \\r\\n, \\n, \\r', () {
    expect(splitLines('a\r\nb\nc\rd'), ['a', 'b', 'c', 'd']);
    expect(splitLines(''), ['']);
    expect(splitLines('a\n'), ['a', '']);
  });

  group('readTextFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('txt_dec'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('đọc file UTF-16 LE', () async {
      final f = File('${dir.path}/a.txt')..writeAsBytesSync(_utf16le(sample));
      final r = await readTextFile(f.path);
      expect(r.text, sample);
      expect(r.encoding, TextEncoding.utf16le);
    });

    test('file không tồn tại → CorruptFile', () async {
      await expectLater(
        readTextFile('${dir.path}/none.txt'),
        throwsA(isA<CorruptFile>()),
      );
    });
  });
}
