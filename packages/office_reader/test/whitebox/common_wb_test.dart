// Kiểm thử hộp trắng (agent A17) cho lib/src/common.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/common/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:office_reader/src/common.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../helpers/ooxml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;
OoxmlPackage pkgOf(Map<String, Object> files) => OoxmlPackage(buildZip(files));
Uint8List u8(List<int> b) => Uint8List.fromList(b);
const relNs = 'xmlns="http://schemas.openxmlformats.org/package/2006/relationships"';
String relsXml(String inner) => '<Relationships $relNs>$inner</Relationships>';
Uint8List buildZipDirOnly() =>
    ZipEncoder().encodeBytes(Archive()..addFile(ArchiveFile.directory('word/')));
Uint8List badOffsetZip() {
  final z = Uint8List.fromList(buildZip({'a.xml': '<a/>'}));
  final e = z.length - 22; // EOCD không có comment
  final cd = z[e + 16] | z[e + 17] << 8 | z[e + 18] << 16 | z[e + 19] << 24;
  z.setAll(cd + 42, [0xFF, 0xFF, 0xFF, 0x0F]); // offset local header trỏ ra ngoài dữ liệu
  return z;
}
List<int> utf16le(String s) => [for (final c in s.codeUnits) ...[c & 0xFF, c >> 8]];
List<int> utf16be(String s) => [for (final c in s.codeUnits) ...[c >> 8, c & 0xFF]];

void main() {
  group('Đơn vị 1 — OfficeFormatException.toString', () {
    // Đường: D1S → R2
    test('1-1 OfficeFormatException(\'x\', \'y\')', () {
      final res = _run(() => OfficeFormatException('x', 'y').toString());
      expect(res, 'OfficeFormatException: x (y)');
    });
    // Đường: D1Đ → R1
    test('1-2 OfficeFormatException(\'x\')', () {
      final res = _run(() => const OfficeFormatException('x').toString());
      expect(res, 'OfficeFormatException: x');
    });
  });
  group('Đơn vị 2 — guardFormat', () {
    // Đường: D1S D2S → R3
    test('2-1 body trả 42', () {
      final res = _run(() => guardFormat('docx', () => 42));
      expect(res, 42);
    });
    // Đường: D1Đ → R1
    test('2-2 body ném OfficeFormatException(\'a\')', () {
      final res = _run(() => guardFormat('docx', () => throw const OfficeFormatException('a')));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'message', 'a').having((e) => e.cause, 'cause', isNull));
    });
    // Đường: D1S D2Đ → R2
    test('2-3 body ném StateError(\'boom\')', () {
      final res = _run(() => guardFormat('xlsx', () => throw StateError('boom')));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'message', 'Cannot read xlsx').having((e) => e.cause, 'cause', isA<StateError>()));
    });
  });
  group('Đơn vị 3 — OoxmlPackage (constructor)', () {
    // Đường: D1S D2S D3S D4S D5Đ → R3
    test('3-1 zip 1 file \'Word/Doc.XML\' = \'x\'', () {
      final res = _run(() => pkgOf({'Word/Doc.XML': 'x'}).has('word/doc.xml'));
      expect(res, isTrue);
    });
    // Đường: D1Đ → R1
    test('3-2 bytes [0x50,0x4B,0x03] (3 byte)', () {
      final res = _run(() => OoxmlPackage(u8([0x50, 0x4B, 0x03])));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'm', 'Not a zip (OOXML) package'));
    });
    // Đường: D1S D2Đ → R1
    test('3-3 bytes \'XK..\' (byte 0 sai)', () {
      final res = _run(() => OoxmlPackage(u8([0x58, 0x4B, 3, 4, 5])));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'm', 'Not a zip (OOXML) package'));
    });
    // Đường: D1S D2S D3Đ → R1
    test('3-4 bytes \'PX..\' (byte 1 sai)', () {
      final res = _run(() => OoxmlPackage(u8([0x50, 0x58, 3, 4, 5])));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'm', 'Not a zip (OOXML) package'));
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('3-5 zip thật, offset local header trong thư mục trung tâm bị sửa trỏ ra ngoài dữ liệu (hỏng)', () {
      final res = _run(() => OoxmlPackage(badOffsetZip()));
      expect(res, isA<OfficeFormatException>().having((e) => e.message, 'm', 'Corrupt zip package'));
    });
    // Đường: D1S D2S D3S D4S D5S → R3
    test('3-6 zip chỉ có thư mục \'word/\' (không có file)', () {
      final res = _run(() => OoxmlPackage(buildZipDirOnly()).has('word/'));
      expect(res, isFalse);
    });
  });
  group('Đơn vị 4 — OoxmlPackage._norm', () {
    // Đường: D1Đ D1S → R1
    test('4-1 zip có \'a/b.xml\'; tra \'/A\\\\B.XML\'', () {
      final res = _run(() => pkgOf({'a/b.xml': 'x'}).has('/A\\B.XML'));
      expect(res, isTrue);
    });
    // Đường: D1S → R1
    test('4-2 tra \'a/b.xml\' (không có / đầu)', () {
      final res = _run(() => pkgOf({'a/b.xml': 'x'}).has('a/b.xml'));
      expect(res, isTrue);
    });
  });
  group('Đơn vị 5 — OoxmlPackage.bytes', () {
    // Đường: D1S → R2
    test('5-1 zip {\'a.bin\': [1,2,3]}; bytes(\'a.bin\')', () {
      final res = _run(() => pkgOf({'a.bin': [1, 2, 3]}).bytes('a.bin'));
      expect(res, equals([1, 2, 3]));
    });
    // Đường: D1Đ → R1
    test('5-2 bytes(\'khong-co.bin\')', () {
      final res = _run(() => pkgOf({'a.bin': [1]}).bytes('khong-co.bin'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 6 — OoxmlPackage.xml', () {
    // Đường: D1S D2S → R3
    test('6-1 part \'a.xml\' = \'<a>x\\r\\ny\\rz</a>\'', () {
      final res = _run(() => pkgOf({'a.xml': '<a>x\r\ny\rz</a>'}).xml('a.xml')!.rootElement.innerText);
      expect(res, 'x\ny\nz');
    });
    // Đường: D1Đ → R1
    test('6-2 xml(\'khong-co.xml\')', () {
      final res = _run(() => pkgOf({'a.xml': '<a/>'}).xml('khong-co.xml'));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ → R2
    test('6-3 part \'a.xml\' = \'<a><b></a>\' (hỏng)', () {
      final res = _run(() => pkgOf({'a.xml': '<a><b></a>'}).xml('a.xml'));
      expect(res, isA<XmlException>());
    });
  });
  group('Đơn vị 7 — OoxmlPackage.rels', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S → R2
    test('7-1 partPath \'word/document.xml\', rels có 1 Relationship đủ Id/Type/Target \'media/a.png\' nội bộ', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Relationship Id="r1" Type="t/image" Target="media/a.png"/>')}).rels('word/document.xml')['r1']!.resolvedPath);
      expect(res, 'word/media/a.png');
    });
    // Đường: D1Đ D2Đ D3S D4S D5S D6S D7S D8S → R2
    test('7-2 partPath \'\' (rels gốc _rels/.rels)', () {
      final res = _run(() => pkgOf({'_rels/.rels': relsXml('<Relationship Id="r1" Type="x/officeDocument" Target="word/document.xml"/>')}).rels('')['r1']!.resolvedPath);
      expect(res, 'word/document.xml');
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S → R2
    test('7-3 partPath \'/doc.xml\' ("/" ở đầu ⇒ dir rỗng), có _rels/doc.xml.rels, Target \'a.xml\'', () {
      final res = _run(() => pkgOf({'_rels/doc.xml.rels': relsXml('<Relationship Id="r1" Type="t" Target="a.xml"/>')}).rels('/doc.xml')['r1']!.resolvedPath);
      expect(res, 'a.xml');
    });
    // Đường: D1S D2S D3Đ → R1
    test('7-4 rels không có part .rels', () {
      final res = _run(() => pkgOf({'a.xml': '<a/>'}).rels('word/document.xml'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('7-5 phần tử con khác tên (vd <Foo/>)', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Foo Id="r1" Target="a"/>')}).rels('word/document.xml'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5Đ → R2
    test('7-6 Relationship thiếu Id', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Relationship Type="t" Target="a"/>')}).rels('word/document.xml'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R2
    test('7-7 Relationship thiếu Target', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Relationship Id="r1" Type="t"/>')}).rels('word/document.xml'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D8S → R2
    test('7-8 Relationship thiếu Type', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Relationship Id="r1" Target="a.xml"/>')}).rels('word/document.xml')['r1']!.type);
      expect(res, '');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ → R2
    test('7-9 TargetMode=\'External\', Target \'http://x.vn/a b\'', () {
      final res = _run(() => pkgOf({'word/_rels/document.xml.rels': relsXml('<Relationship Id="r1" Type="t" Target="http://x.vn/a b" TargetMode="External"/>')}).rels('word/document.xml')['r1']!.resolvedPath);
      expect(res, 'http://x.vn/a b');
    });
  });
  group('Đơn vị 8 — OoxmlPackage.resolvePath', () {
    // Đường: D1S D2Đ D3S D4S D5S → R1
    test('8-1 (\'word\', \'media/a%20b.png\')', () {
      final res = _run(() => OoxmlPackage.resolvePath('word', 'media/a%20b.png'));
      expect(res, 'word/media/a b.png');
    });
    // Đường: D1Đ D2Đ D3S D4S D5S → R1
    test('8-2 (\'word\', \'100%.png\') — % trần', () {
      final res = _run(() => OoxmlPackage.resolvePath('word', '100%.png'));
      expect(res, 'word/100%.png');
    });
    // Đường: D1S D2S D3S D4S D5S → R1
    test('8-3 (\'word\', \'/xl/a.xml\') — tuyệt đối', () {
      final res = _run(() => OoxmlPackage.resolvePath('word', '/xl/a.xml'));
      expect(res, 'xl/a.xml');
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('8-4 (\'word\', \'a//b.xml\') — đoạn rỗng', () {
      final res = _run(() => OoxmlPackage.resolvePath('word', 'a//b.xml'));
      expect(res, 'word/a/b.xml');
    });
    // Đường: D1S D2Đ D3S D4Đ → R1
    test('8-5 (\'word\', \'./a.xml\')', () {
      final res = _run(() => OoxmlPackage.resolvePath('word', './a.xml'));
      expect(res, 'word/a.xml');
    });
    // Đường: D1S D2Đ D3S D4S D5Đ D6Đ → R1
    test('8-6 (\'word/sub\', \'../a.xml\')', () {
      final res = _run(() => OoxmlPackage.resolvePath('word/sub', '../a.xml'));
      expect(res, 'word/a.xml');
    });
    // Đường: D1S D2Đ D3S D4S D5Đ D6S → R1
    test('8-7 (\'\', \'../a.xml\') — lùi quá gốc', () {
      final res = _run(() => OoxmlPackage.resolvePath('', '../a.xml'));
      expect(res, 'a.xml');
    });
  });
  group('Đơn vị 9 — _decodeText (qua OoxmlPackage.xml)', () {
    // Đường: D1Đ D2S D5Đ D6S D9Đ D10S → R3
    test('9-1 part UTF-8 không BOM \'<a>Á</a>\'', () {
      final res = _run(() => pkgOf({'a.xml': '<a>Á</a>'}).xml('a.xml')!.rootElement.innerText);
      expect(res, 'Á');
    });
    // Đường: D1S D5S D9S → R3
    test('9-2 part 1 byte \'<\' (độ dài < 2)', () {
      final res = _run(() => pkgOf({'a.xml': [0x3C]}).xml('a.xml'));
      expect(res, isA<XmlException>());
    });
    // Đường: D1Đ D2Đ D3S D5Đ D6S D9Đ D10S → R3
    test('9-3 part FF 3C 61 2F 3E (FF nhưng không phải BOM)', () {
      final res = _run(() => pkgOf({'a.xml': [0xFF, ...utf8.encode('<a/>')]}).xml('a.xml'));
      expect(res, isA<XmlDocument>().having((d) => d.rootElement.localName, 'gốc', 'a').having((d) => d.toXmlString().startsWith('�'), 'byte đầu giải mã UTF-8 thành U+FFFD', isTrue));
    });
    // Đường: D1Đ D2S D5Đ D6Đ D7S D9Đ D10S → R3
    test('9-5 part FE 3C 61 2F 3E', () {
      final res = _run(() => pkgOf({'a.xml': [0xFE, ...utf8.encode('<a/>')]}).xml('a.xml'));
      expect(res, isA<XmlDocument>().having((d) => d.rootElement.localName, 'gốc', 'a').having((d) => d.toXmlString().startsWith('�'), 'byte đầu giải mã UTF-8 thành U+FFFD', isTrue));
    });
    // Đường: D1Đ D2S D5Đ D6S D9S → R3
    test('9-6 part 2 byte \'<a\' (độ dài 2, không BOM)', () {
      final res = _run(() => pkgOf({'a.xml': [0x3C, 0x61]}).xml('a.xml'));
      expect(res, isA<XmlException>());
    });
    // Đường: D1Đ D2S D5Đ D6S D9Đ D10Đ D11S → R3
    test('9-7 part EF 3C 61 2F 3E', () {
      final res = _run(() => pkgOf({'a.xml': [0xEF, ...utf8.encode('<a/>')]}).xml('a.xml'));
      expect(res, isA<XmlDocument>().having((d) => d.rootElement.localName, 'gốc', 'a').having((d) => d.toXmlString().startsWith('�'), 'byte đầu giải mã UTF-8 thành U+FFFD', isTrue));
    });
    // Đường: D1Đ D2Đ D3Đ D4Đ D4S → R1
    test('9-8 part FF FE + \'<a>Á</a>\' UTF-16LE', () {
      final res = _run(() => pkgOf({'a.xml': [0xFF, 0xFE, ...utf16le('<a>Á</a>')]}).xml('a.xml')!.rootElement.innerText);
      expect(res, 'Á');
    });
    // Đường: D1Đ D2S D5Đ D6Đ D7Đ D8Đ D8S → R2
    test('9-9 part FE FF + \'<a>Á</a>\' UTF-16BE', () {
      final res = _run(() => pkgOf({'a.xml': [0xFE, 0xFF, ...utf16be('<a>Á</a>')]}).xml('a.xml')!.rootElement.innerText);
      expect(res, 'Á');
    });
    // Đường: D1Đ D2S D5Đ D6S D9Đ D10Đ D11Đ D12S → R3
    test('9-10 part EF BB 3C 61 2F 3E', () {
      final res = _run(() => pkgOf({'a.xml': [0xEF, 0xBB, ...utf8.encode('<a/>')]}).xml('a.xml'));
      expect(res, isA<XmlDocument>().having((d) => d.rootElement.localName, 'gốc', 'a').having((d) => d.toXmlString().startsWith('�'), 'byte đầu giải mã UTF-8 thành U+FFFD', isTrue));
    });
    // Đường: D1Đ D2Đ D3Đ D4S → R1
    test('9-11 part chỉ có BOM FF FE', () {
      final res = _run(() => pkgOf({'a.xml': [0xFF, 0xFE]}).xml('a.xml'));
      expect(res, isA<XmlException>());
    });
    // Đường: D1Đ D2S D5Đ D6Đ D7Đ D8S → R2
    test('9-12 part chỉ có BOM FE FF', () {
      final res = _run(() => pkgOf({'a.xml': [0xFE, 0xFF]}).xml('a.xml'));
      expect(res, isA<XmlException>());
    });
    // Đường: D1Đ D2S D5Đ D6S D9Đ D10Đ D11Đ D12Đ → R3
    test('9-13 part EF BB BF + \'<a>Á</a>\' (UTF-8 có BOM)', () {
      final res = _run(() => pkgOf({'a.xml': [0xEF, 0xBB, 0xBF, ...utf8.encode('<a>Á</a>')]}).xml('a.xml')!.rootElement.innerText);
      expect(res, 'Á');
    });
  });
  group('Đơn vị 10 — XmlElementX.attr', () {
    // Đường: D1Đ → R1
    test('10-1 <a w:val="x" xmlns:w="u"/> attr("val")', () {
      final res = _run(() => el('<a w:val="x" xmlns:w="u"/>').attr('val'));
      expect(res, 'x');
    });
    // Đường: D1S → R2
    test('10-2 <a b="1"/> attr("val")', () {
      final res = _run(() => el('<a b="1"/>').attr('val'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 11 — XmlElementX.child', () {
    // Đường: D1Đ D2Đ → R1
    test('11-1 <a><w:b xmlns:w="u"/></a> child("b")', () {
      final res = _run(() => el('<a><w:b xmlns:w="u"/></a>').child('b')?.localName);
      expect(res, 'b');
    });
    // Đường: D1S → R2
    test('11-2 <a>text</a> child("b") — con là văn bản', () {
      final res = _run(() => el('<a>text</a>').child('b'));
      expect(res, isNull);
    });
    // Đường: D1Đ D2S → R2
    test('11-3 <a><c/></a> child("b")', () {
      final res = _run(() => el('<a><c/></a>').child('b'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 12 — XmlElementX.descendant', () {
    // Đường: D1Đ → R1
    test('12-1 <a><b><c i="1"/></b><c i="2"/></a> descendant("c")', () {
      final res = _run(() => el('<a><b><c i="1"/></b><c i="2"/></a>').descendant('c')!.getAttribute('i'));
      expect(res, '1');
    });
    // Đường: D1S → R2
    test('12-2 <a><b/></a> descendant("c")', () {
      final res = _run(() => el('<a><b/></a>').descendant('c'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 13 — XmlElementX.childVal', () {
    // Đường: D1S → R2
    test('13-1 <a><jc val="center"/></a> childVal("jc")', () {
      final res = _run(() => el('<a><jc val="center"/></a>').childVal('jc'));
      expect(res, 'center');
    });
    // Đường: D1Đ → R1
    test('13-2 <a/> childVal("jc")', () {
      final res = _run(() => el('<a/>').childVal('jc'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 14 — parseIntOrNull', () {
    // Đường: D1S D2S → R2
    test('14-1 \' 12 \'', () {
      final res = _run(() => parseIntOrNull(' 12 '));
      expect(res, 12);
    });
    // Đường: D1Đ → R1
    test('14-2 null', () {
      final res = _run(() => parseIntOrNull(null));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S → R4
    test('14-3 \'2.6\'', () {
      final res = _run(() => parseIntOrNull('2.6'));
      expect(res, 3);
    });
    // Đường: D1S D2Đ D3Đ → R3
    test('14-4 \'abc\'', () {
      final res = _run(() => parseIntOrNull('abc'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 15 — parseDoubleOrNull', () {
    // Đường: D1S → R2
    test('15-1 \' 1.5 \'', () {
      final res = _run(() => parseDoubleOrNull(' 1.5 '));
      expect(res, 1.5);
    });
    // Đường: D1Đ → R1
    test('15-2 null', () {
      final res = _run(() => parseDoubleOrNull(null));
      expect(res, isNull);
    });
  });
  group('Đơn vị 16 — parseHexColor', () {
    // Đường: D1S D2Đ D3S → R2
    test('16-1 \'1F4E79\'', () {
      final res = _run(() => parseHexColor('1F4E79'));
      expect(res, 0xFF1F4E79);
    });
    // Đường: D1Đ → R1
    test('16-2 null', () {
      final res = _run(() => parseHexColor(null));
      expect(res, isNull);
    });
    // Đường: D1S D2S D4S → R4
    test('16-3 \'auto\'', () {
      final res = _run(() => parseHexColor('auto'));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('16-4 \'auto00\' (6 ký tự không phải hex)', () {
      final res = _run(() => parseHexColor('auto00'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D4Đ D5S → R3
    test('16-5 \'80FF0000\' (AARRGGBB)', () {
      final res = _run(() => parseHexColor('80FF0000'));
      expect(res, 0xFFFF0000);
    });
    // Đường: D1S D2S D4Đ D5Đ → R1
    test('16-6 \'ZZXXYYWW\' (8 ký tự không phải hex)', () {
      final res = _run(() => parseHexColor('ZZXXYYWW'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 17 — ooxmlBool', () {
    // Đường: D1S D2S D3S D4S → R3
    test('17-1 \'0\'', () {
      final res = _run(() => ooxmlBool('0'));
      expect(res, isFalse);
    });
    // Đường: D1Đ → R1
    test('17-2 null (mặc định ifMissing = true)', () {
      final res = _run(() => ooxmlBool(null));
      expect(res, isTrue);
    });
    // Đường: D1S D2Đ → R2
    test('17-3 \'1\'', () {
      final res = _run(() => ooxmlBool('1'));
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3Đ → R2
    test('17-4 \'TRUE\'', () {
      final res = _run(() => ooxmlBool('TRUE'));
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('17-5 \'on\'', () {
      final res = _run(() => ooxmlBool('on'));
      expect(res, isTrue);
    });
  });
}
