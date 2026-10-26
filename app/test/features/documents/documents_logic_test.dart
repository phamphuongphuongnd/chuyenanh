import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/utils/doc_type.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';

DocItem item(String name, {int size = 1, int day = 1}) => DocItem(
  path: '/s/$name',
  name: name,
  ext: name.contains('.') ? name.split('.').last.toLowerCase() : '',
  size: size,
  modified: DateTime(2026, 1, day),
  folder: 's',
);

void main() {
  final all = [
    item('b.pdf', size: 300, day: 3),
    item('A.docx', size: 100, day: 1),
    item('c.xlsx', size: 200, day: 5),
    item('d.PPTX', size: 50, day: 4),
    item('e.txt', size: 400, day: 2),
    item('f.doc', size: 10, day: 6),
    item('g.xls', size: 20, day: 7),
  ];

  group('filterDocuments', () {
    test('All giữ hết', () {
      expect(filterDocuments(all).length, 7);
    });
    test('theo tab', () {
      expect(
        filterDocuments(
          all,
          category: DocCategory.pdf,
        ).map((d) => d.name).toList(),
        ['b.pdf'],
      );
      expect(
        filterDocuments(
          all,
          category: DocCategory.doc,
        ).map((d) => d.name).toSet(),
        {'A.docx', 'f.doc'},
      );
      expect(
        filterDocuments(
          all,
          category: DocCategory.xls,
        ).map((d) => d.name).toSet(),
        {'c.xlsx', 'g.xls'},
      );
      expect(
        filterDocuments(
          all,
          category: DocCategory.ppt,
        ).map((d) => d.name).toList(),
        ['d.PPTX'],
      );
      expect(
        filterDocuments(
          all,
          category: DocCategory.txt,
        ).map((d) => d.name).toList(),
        ['e.txt'],
      );
    });
    test('theo từ khoá, không phân biệt hoa thường, kết hợp tab', () {
      expect(filterDocuments(all, query: 'a.').map((d) => d.name), ['A.docx']);
      expect(filterDocuments(all, query: '  C.X ').map((d) => d.name), [
        'c.xlsx',
      ]);
      expect(
        filterDocuments(all, category: DocCategory.pdf, query: 'zzz'),
        isEmpty,
      );
    });
  });

  group('sortDocuments', () {
    List<String> names(DocSort s) =>
        sortDocuments(all, s).map((d) => d.name).toList();

    test('tên tăng / giảm (không phân biệt hoa thường)', () {
      expect(names(DocSort.nameAsc), [
        'A.docx',
        'b.pdf',
        'c.xlsx',
        'd.PPTX',
        'e.txt',
        'f.doc',
        'g.xls',
      ]);
      expect(names(DocSort.nameDesc).first, 'g.xls');
    });
    test('ngày', () {
      expect(names(DocSort.dateDesc).first, 'g.xls');
      expect(names(DocSort.dateAsc).first, 'A.docx');
    });
    test('dung lượng', () {
      expect(names(DocSort.sizeDesc).first, 'e.txt');
      expect(names(DocSort.sizeAsc).first, 'f.doc');
    });
    test('bằng nhau thì theo tên; không đổi danh sách gốc', () {
      final same = [item('z.pdf', size: 5), item('a.pdf', size: 5)];
      expect(sortDocuments(same, DocSort.sizeAsc).map((d) => d.name), [
        'a.pdf',
        'z.pdf',
      ]);
      expect(same.first.name, 'z.pdf');
    });
    test('fromName', () {
      expect(DocSort.fromName('sizeAsc'), DocSort.sizeAsc);
      expect(DocSort.fromName('lạ'), DocSort.dateDesc);
      expect(DocSort.fromName(null), DocSort.dateDesc);
    });
  });

  group('đổi tên', () {
    test('renameTarget giữ đuôi, làm sạch ký tự cấm', () {
      expect(
        p.normalize(renameTarget('/a/b/x.pdf', 'moi')),
        p.normalize('/a/b/moi.pdf'),
      );
      expect(p.basename(renameTarget('/a/b/x.docx', 'a/b:c')), 'a_b_c.docx');
    });
    test('validateRename', () {
      expect(
        validateRename(
          oldPath: '/a/x.pdf',
          newBaseName: '  ',
          exists: (_) => false,
        ),
        RenameProblem.empty,
      );
      expect(
        validateRename(
          oldPath: '/a/x.pdf',
          newBaseName: 'y',
          exists: (path) => p.basename(path) == 'y.pdf',
        ),
        RenameProblem.exists,
      );
      expect(
        validateRename(
          oldPath: '/a/x.pdf',
          newBaseName: 'x',
          exists: (_) => true,
        ),
        isNull,
        reason: 'giữ nguyên tên không phải lỗi',
      );
      expect(
        validateRename(
          oldPath: '/a/x.pdf',
          newBaseName: 'z',
          exists: (_) => false,
        ),
        isNull,
      );
    });
  });

  group('pdfHasEncryptMarker', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('enc_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<bool> check(List<int> bytes) async {
      final f = File(p.join(dir.path, 'x.pdf'))..writeAsBytesSync(bytes);
      return pdfHasEncryptMarker(f.path);
    }

    test('thấy / không thấy', () async {
      expect(
        await check('%PDF-1.4 trailer << /Encrypt 5 0 R >>'.codeUnits),
        isTrue,
      );
      expect(await check('%PDF-1.4 trailer << /Size 5 >>'.codeUnits), isFalse);
      expect(await check(const []), isFalse);
    });

    test('marker nằm vắt qua ranh giới khối đọc', () async {
      const chunk = 256 * 1024;
      final bytes = [
        ...List<int>.filled(chunk - 3, 0x20),
        ...'/Encrypt'.codeUnits,
      ];
      expect(await check(bytes), isTrue);
    });

    test('file không tồn tại → false', () async {
      expect(await pdfHasEncryptMarker(p.join(dir.path, 'none.pdf')), isFalse);
    });
  });
}
