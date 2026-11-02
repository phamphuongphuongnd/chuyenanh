// Kiểm thử hộp trắng A19 — lib/src/package.dart (mã bộ K*, xem
// test-output/whitebox/pptx-reader/package/buoc-5-du-lieu-thu.md).
// Không mock: zip dựng thật bằng package:archive; nhánh khẳng định qua kết quả phân biệt.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pptx_reader/src/model.dart';
import 'package:pptx_reader/src/package.dart';
import 'package:test/test.dart';

Uint8List zipOf(Map<String, String> files, {List<String> dirs = const []}) {
  final a = Archive();
  for (final d in dirs) {
    a.addFile(ArchiveFile.directory(d));
  }
  files.forEach((k, v) => a.addFile(ArchiveFile.bytes(k, utf8.encode(v))));
  return ZipEncoder().encodeBytes(a);
}

const relNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
const tSlide =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';
String relsXml(String body) => '<Relationships xmlns="$relNs">$body</Relationships>';

Object? errOf(void Function() f) {
  try {
    f();
    return 'ok';
  } catch (e) {
    return e;
  }
}

void main() {
  group('K1 OpcPackage.open', () {
    test('K1.1 zip hợp lệ 1 file ⇒ mở được, tên part không phân biệt hoa thường', () {
      final p = OpcPackage.open(zipOf({'ppt/A.xml': '<a/>'}));
      expect(p.exists('ppt/a.xml'), isTrue);
      expect(p.exists('PPT/A.XML'), isTrue);
    });
    test('K1.2 ít hơn 4 byte ⇒ PptxFormatException', () {
      final r = errOf(() => OpcPackage.open(Uint8List.fromList([0x50, 0x4B, 3])));
      expect(r, isA<PptxFormatException>());
    });
    test('K1.3 byte 0 khác P ⇒ PptxFormatException', () {
      final r = errOf(() => OpcPackage.open(Uint8List.fromList([0, 0x4B, 3, 4, 5])));
      expect(r, isA<PptxFormatException>());
    });
    test('K1.4 byte 1 khác K ⇒ PptxFormatException', () {
      final r = errOf(() => OpcPackage.open(Uint8List.fromList([0x50, 0, 3, 4, 5])));
      expect(r, isA<PptxFormatException>());
    });
    test('K1.5 có chữ ký PK nhưng zip hỏng ⇒ PptxFormatException', () {
      // Đã sửa test: rác sau 'PK' không làm ZipDecoder (archive 4) ném — phải làm hỏng
      // offset local header trong central directory thì decodeBytes mới ném.
      final bytes = zipOf({'a.xml': '<a/>'});
      var cd = -1;
      for (var i = bytes.length - 4; i >= 0; i--) {
        if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 1 && bytes[i + 3] == 2) {
          cd = i;
          break;
        }
      }
      bytes.setRange(cd + 42, cd + 46, [0xFF, 0xFF, 0xFF, 0x7F]);
      final r = errOf(() => OpcPackage.open(bytes));
      expect(r, isA<PptxFormatException>());
      expect((r as PptxFormatException).message, startsWith('Corrupt zip'));
    });
    test('K1.6 zip rỗng ⇒ mở được, không có part', () {
      // Đã sửa test: bản đầu thêm mục thư mục (trùng K1.7) — nay zip rỗng thật.
      final p = OpcPackage.open(zipOf({}));
      expect(p.exists('ppt/'), isFalse);
      expect(p.exists('[Content_Types].xml'), isFalse);
    });
    test('K1.7 mục thư mục bị bỏ, file vẫn có', () {
      final p = OpcPackage.open(zipOf({'ppt/a.xml': '<a/>'}, dirs: ['ppt/']));
      expect(p.exists('ppt/'), isFalse);
      expect(p.exists('ppt/a.xml'), isTrue);
    });
  });

  group('K2 media', () {
    final p = OpcPackage.open(zipOf({'ppt/media/i.png': 'PNG'}));
    test('K2.1 part có ⇒ bytes, gọi lại trả cùng bản cache', () {
      final b = p.media('ppt/media/i.png');
      expect(utf8.decode(b!), 'PNG');
      expect(identical(p.media('ppt/media/i.png'), b), isTrue);
    });
    test('K2.2 part không có ⇒ null', () {
      expect(p.media('ppt/media/none.png'), isNull);
    });
  });

  group('K3 xml', () {
    final p = OpcPackage.open(zipOf({
      'a.xml': '<root v="1"/>',
      'bom.xml': '﻿<root v="2"/>',
      'bad.xml': '<root>',
    }));
    test('K3.1 part có, không BOM ⇒ phần tử gốc', () {
      expect(p.xml('a.xml')?.getAttribute('v'), '1');
    });
    test('K3.2 gọi lần 2 ⇒ cùng phần tử (cache)', () {
      final a = p.xml('a.xml');
      expect(identical(p.xml('a.xml'), a), isTrue);
    });
    test('K3.3 part không có ⇒ null', () {
      expect(p.xml('none.xml'), isNull);
    });
    test('K3.4 có BOM ⇒ vẫn đọc được', () {
      expect(p.xml('bom.xml')?.getAttribute('v'), '2');
    });
    test('K3.5 XML hỏng ⇒ PptxFormatException nêu tên part', () {
      final r = errOf(() => p.xml('bad.xml'));
      expect(r, isA<PptxFormatException>());
      expect((r as PptxFormatException).message, contains('bad.xml'));
    });
  });

  group('K4 rels', () {
    OpcPackage pkg(Map<String, String> f) => OpcPackage.open(zipOf(f));
    test('K4.1 rels của part trong thư mục ⇒ đích tuyệt đối', () {
      final r = pkg({
        'ppt/_rels/presentation.xml.rels': relsXml(
          '<Relationship Id="rId1" Type="$tSlide" Target="slides/slide1.xml"/>',
        ),
      }).rels('ppt/presentation.xml');
      expect(r.keys, ['rId1']);
      expect(r['rId1']!.target, 'ppt/slides/slide1.xml');
      expect(r['rId1']!.type, tSlide);
      expect(r['rId1']!.external, isFalse);
    });
    test("K4.2 '' ⇒ rels của gói (_rels/.rels)", () {
      final r = pkg({
        '_rels/.rels': relsXml('<Relationship Id="rId1" Type="t" Target="ppt/presentation.xml"/>'),
      }).rels('');
      expect(r['rId1']!.target, 'ppt/presentation.xml');
    });
    test("K4.3 part bắt đầu '/' (dir rỗng) ⇒ _rels/<file>.rels", () {
      final r = pkg({
        '_rels/x.xml.rels': relsXml('<Relationship Id="rId1" Type="t" Target="y.xml"/>'),
      }).rels('/x.xml');
      expect(r['rId1']!.target, 'y.xml');
    });
    test('K4.4 rels XML hỏng ⇒ PptxFormatException', () {
      final p = pkg({'ppt/_rels/p.xml.rels': '<Relationships>'});
      expect(errOf(() => p.rels('ppt/p.xml')), isA<PptxFormatException>());
    });
    test('K4.5 không có file rels ⇒ map rỗng', () {
      expect(pkg({'a.xml': '<a/>'}).rels('ppt/p.xml'), isEmpty);
    });
    test('K4.6 file rels không có phần tử ⇒ map rỗng', () {
      expect(pkg({'ppt/_rels/p.xml.rels': relsXml('')}).rels('ppt/p.xml'), isEmpty);
    });
    test('K4.7 phần tử không phải Relationship bị bỏ', () {
      final p = pkg({'ppt/_rels/p.xml.rels': relsXml('<Other Id="x" Target="y"/>')});
      expect(p.rels('ppt/p.xml'), isEmpty);
    });
    test('K4.8 thiếu Id bị bỏ', () {
      final p = pkg({'ppt/_rels/p.xml.rels': relsXml('<Relationship Type="t" Target="y"/>')});
      expect(p.rels('ppt/p.xml'), isEmpty);
    });
    test('K4.9 thiếu Target bị bỏ', () {
      final p = pkg({'ppt/_rels/p.xml.rels': relsXml('<Relationship Id="r" Type="t"/>')});
      expect(p.rels('ppt/p.xml'), isEmpty);
    });
    test("K4.10 thiếu Type ⇒ type ''", () {
      final p = pkg({'ppt/_rels/p.xml.rels': relsXml('<Relationship Id="r" Target="y.xml"/>')});
      expect(p.rels('ppt/p.xml')['r']!.type, '');
    });
    test('K4.11 TargetMode External ⇒ giữ URL thô, external = true', () {
      final p = pkg({
        'ppt/_rels/p.xml.rels': relsXml(
          '<Relationship Id="r" Type="t" Target="https://example.com/a?b=1" TargetMode="External"/>',
        ),
      });
      final rel = p.rels('ppt/p.xml')['r']!;
      expect(rel.target, 'https://example.com/a?b=1');
      expect(rel.external, isTrue);
    });
  });

  group('K5 resolvePath', () {
    test("K5.1 '..' lên 1 cấp, %20 được giải mã", () {
      expect(OpcPackage.resolvePath('ppt/slides', '../media/my%20image.png'),
          'ppt/media/my image.png');
    });
    test('K5.2 mã % sai ⇒ không ném, giữ chuỗi thô', () {
      expect(OpcPackage.resolvePath('ppt', 'a%zz.xml'), 'ppt/a%zz.xml');
    });
    test("K5.3 đích tuyệt đối '/...' ⇒ bỏ thư mục gốc, bỏ '/' đầu", () {
      expect(OpcPackage.resolvePath('ppt/slides', '/ppt/x.xml'), 'ppt/x.xml');
    });
    test('K5.5 đoạn rỗng (//) bị bỏ', () {
      expect(OpcPackage.resolvePath('ppt', 'a//b.xml'), 'ppt/a/b.xml');
    });
    test("K5.6 đoạn '.' bị bỏ", () {
      expect(OpcPackage.resolvePath('ppt', './x.xml'), 'ppt/x.xml');
    });
    test('K5.7 đường tương đối thường ⇒ nối vào thư mục gốc', () {
      expect(OpcPackage.resolvePath('ppt/slides', 'media/x.png'), 'ppt/slides/media/x.png');
    });
    test("K5.8 '..' vượt gốc ⇒ bị bỏ (RFC 3986)", () {
      expect(OpcPackage.resolvePath('', '../x.xml'), 'x.xml');
    });
  });
}
