// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/doc_type.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/doc_type/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/doc_type.dart';

void main() {
  group('U1 extensionOf', () {
    test('1.1 có đuôi hoa ⇒ chữ thường, bỏ dấu chấm', () {
      expect(extensionOf('a/b.PDF'), 'pdf');
    });
    test('1.2 không đuôi ⇒ chuỗi rỗng', () {
      expect(extensionOf('a/README'), '');
    });
  });

  group('U2 docTypeFromExtension', () {
    const cases = <(String, String, DocType)>[
      ('2.1', 'pdf', DocType.pdf),
      ('2.2', 'doc', DocType.doc),
      ('2.3', 'DOCX', DocType.docx),
      ('2.4', 'xls', DocType.xls),
      ('2.5', 'xlsx', DocType.xlsx),
      ('2.6', 'ppt', DocType.ppt),
      ('2.7', 'pptx', DocType.pptx),
      ('2.8', '.txt', DocType.txt),
      ('2.9', 'JPG', DocType.image),
      ('2.10', 'zip', DocType.other),
    ];
    for (final (code, ext, want) in cases) {
      test('$code "$ext" ⇒ $want', () {
        expect(docTypeFromExtension(ext), want);
      });
    }
  });

  group('U3 category', () {
    const cases = <(String, DocType, DocCategory?)>[
      ('3.1', DocType.pdf, DocCategory.pdf),
      ('3.2', DocType.doc, DocCategory.doc),
      ('3.3', DocType.docx, DocCategory.doc),
      ('3.4', DocType.xls, DocCategory.xls),
      ('3.5', DocType.xlsx, DocCategory.xls),
      ('3.6', DocType.ppt, DocCategory.ppt),
      ('3.7', DocType.pptx, DocCategory.ppt),
      ('3.8', DocType.txt, DocCategory.txt),
      ('3.9', DocType.image, null),
      ('3.10', DocType.other, null),
    ];
    for (final (code, type, want) in cases) {
      test('$code $type ⇒ $want', () {
        expect(type.category, want);
      });
    }
  });

  group('U4 isLegacyOffice', () {
    const cases = <(String, DocType, bool)>[
      ('4.1', DocType.doc, true),
      ('4.2', DocType.xls, true),
      ('4.3', DocType.ppt, true),
      ('4.4', DocType.docx, false),
    ];
    for (final (code, type, want) in cases) {
      test('$code $type ⇒ $want', () {
        expect(type.isLegacyOffice, want);
      });
    }
  });

  group('U5 label', () {
    const cases = <(String, DocType, String)>[
      ('5.1', DocType.pdf, 'PDF'),
      ('5.2', DocType.doc, 'DOC'),
      ('5.3', DocType.docx, 'DOC'),
      ('5.4', DocType.xls, 'XLS'),
      ('5.5', DocType.xlsx, 'XLS'),
      ('5.6', DocType.ppt, 'PPT'),
      ('5.7', DocType.pptx, 'PPT'),
      ('5.8', DocType.txt, 'TXT'),
      ('5.9', DocType.image, 'IMG'),
      ('5.10', DocType.other, 'FILE'),
    ];
    for (final (code, type, want) in cases) {
      test('$code $type ⇒ $want', () {
        expect(type.label, want);
      });
    }
  });
}
