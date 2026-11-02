// Kiểm thử hộp trắng A13 — app/lib/features/documents/documents_logic.dart
// Thiết kế: test-output/whitebox/documents/documents_logic/buoc-1..5. Expected chép từ Bước 5.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/utils/doc_type.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';

DocItem _d(String name, {int size = 1, int day = 1}) => DocItem(
  path: '/r/$name',
  name: name,
  ext: extensionOf(name),
  size: size,
  modified: DateTime(2026, 1, day),
  folder: 'r',
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_doclogic_'));
  tearDown(() => tmp.deleteSync(recursive: true));
  String file(String n, List<int> b) => (File(p.join(tmp.path, n))..writeAsBytesSync(b)).path;
  final marker = '/Encrypt'.codeUnits;

  group('U1 fromFileSync', () {
    test('1-1 file có ⇒ DocItem', () {
      final dir = Directory(p.join(tmp.path, 'Docs'))..createSync();
      final f = File(p.join(dir.path, 'a.PDF'))..writeAsBytesSync([1, 2, 3]);
      final d = DocItem.fromFileSync(f.path)!;
      expect([d.name, d.ext, d.size, d.folder], ['a.PDF', 'pdf', 3, 'Docs']);
    });
    test('1-2 không có ⇒ null', () => expect(DocItem.fromFileSync(p.join(tmp.path, 'x.pdf')), isNull));
  });

  group('U2 DocSort.fromName', () {
    test('2-1 tên đúng', () => expect(DocSort.fromName('nameAsc'), DocSort.nameAsc));
    test('2-2 sai / null ⇒ dateDesc', () {
      expect(DocSort.fromName('xx'), DocSort.dateDesc);
      expect(DocSort.fromName(null), DocSort.dateDesc);
    });
  });

  group('U3 filterDocuments', () {
    final items = [_d('a.pdf'), _d('b.docx'), _d('Bao cao.PDF')];
    test('3-1 tab + từ khoá', () {
      expect(filterDocuments(items), hasLength(3));
      expect(filterDocuments(items, category: DocCategory.pdf).map((e) => e.name), ['a.pdf', 'Bao cao.PDF']);
      expect(filterDocuments(items, category: DocCategory.pdf, query: ' BAO ').map((e) => e.name), ['Bao cao.PDF']);
      expect(filterDocuments(items, query: 'zzz'), isEmpty);
    });
  });

  group('U4 sortDocuments', () {
    final items = [_d('b', size: 3, day: 2), _d('a', size: 1, day: 3), _d('c', size: 2, day: 1)];
    List<String> s(DocSort k) => sortDocuments(items, k).map((e) => e.name).toList();
    test('4-1 nameAsc', () => expect(s(DocSort.nameAsc), ['a', 'b', 'c']));
    test('4-2 nameDesc', () => expect(s(DocSort.nameDesc), ['c', 'b', 'a']));
    test('4-3 dateDesc', () => expect(s(DocSort.dateDesc), ['a', 'b', 'c']));
    test('4-4 dateAsc', () => expect(s(DocSort.dateAsc), ['c', 'b', 'a']));
    test('4-5 sizeDesc', () => expect(s(DocSort.sizeDesc), ['b', 'c', 'a']));
    test('4-6 sizeAsc', () => expect(s(DocSort.sizeAsc), ['a', 'c', 'b']));
    test('4-T hoà ⇒ theo tên không phân biệt hoa thường', () {
      expect(sortDocuments([_d('b'), _d('A')], DocSort.sizeAsc).map((e) => e.name), ['A', 'b']);
    });
  });

  group('U5 validateRename', () {
    RenameProblem? v(String n, {bool ex = false}) =>
        validateRename(oldPath: p.join('/d', 'a.pdf'), newBaseName: n, exists: (_) => ex);
    test('5-1 hợp lệ ⇒ null', () => expect(v('b'), isNull));
    test('5-2 rỗng ⇒ empty', () => expect(v('   '), RenameProblem.empty));
    test('5-3 không đổi ⇒ null', () => expect(v(' a ', ex: true), isNull));
    test('5-4 đã có ⇒ exists', () => expect(v('b', ex: true), RenameProblem.exists));
  });

  group('U6/U7 pdfHasEncryptMarker + _indexOf', () {
    const big = 300 * 1024;
    test('6-1 nhỏ không marker ⇒ false', () async => expect(await pdfHasEncryptMarker(file('a.pdf', 'abc'.codeUnits)), isFalse));
    test('6-2 file rỗng ⇒ false', () async => expect(await pdfHasEncryptMarker(file('e.pdf', [])), isFalse));
    test('6-3 lớn, marker đầu ⇒ true', () async {
      expect(await pdfHasEncryptMarker(file('h.pdf', [...marker, ...List.filled(big, 0x20)])), isTrue);
    });
    test('6-4 lớn, marker cuối / không có', () async {
      expect(await pdfHasEncryptMarker(file('t.pdf', [...List.filled(big, 0x20), ...marker])), isTrue);
      expect(await pdfHasEncryptMarker(file('n.pdf', List.filled(big, 0x20))), isFalse);
    });
    test('6-5 không tồn tại ⇒ false', () async => expect(await pdfHasEncryptMarker(p.join(tmp.path, 'x.pdf')), isFalse));
    test('7-1 ngắn hơn mẫu ⇒ false', () async => expect(await pdfHasEncryptMarker(file('s.pdf', '/En'.codeUnits)), isFalse));
    test('7-2 không byte đầu khớp ⇒ false', () async => expect(await pdfHasEncryptMarker(file('x.pdf', 'xxxxxxxxxx'.codeUnits)), isFalse));
    test('7-3 khớp một phần ⇒ false', () async => expect(await pdfHasEncryptMarker(file('p.pdf', '/Encrypx'.codeUnits)), isFalse));
    test('7-4 khớp đủ ⇒ true', () async => expect(await pdfHasEncryptMarker(file('f.pdf', 'aa/Encrypt'.codeUnits)), isTrue));
    test('7-5 marker sát cuối file lớn ⇒ true', () async {
      expect(await pdfHasEncryptMarker(file('z.pdf', [...List.filled(big - 4, 0x20), ...marker])), isTrue);
    });
  });
}
