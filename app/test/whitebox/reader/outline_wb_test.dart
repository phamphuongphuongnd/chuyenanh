// Kiểm thử hộp trắng (A09 · reader) — outline.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/outline/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/logic/outline.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

// ---------- Đối tượng giả (chỉ các thành viên flattenOutline dùng) ----------
class _FakePage implements sf.PdfPage {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePages implements sf.PdfPageCollection {
  _FakePages(this.items);
  final List<sf.PdfPage> items;
  int indexOfCalls = 0;
  @override
  int indexOf(sf.PdfPage page) {
    indexOfCalls++;
    return items.indexWhere((p) => identical(p, page));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDest implements sf.PdfDestination {
  _FakeDest(this.page);
  @override
  final sf.PdfPage page;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBm implements sf.PdfBookmark {
  _FakeBm(this.title, {this.dest, this.destThrows = false, List<_FakeBm>? children})
    : children = children ?? [];
  @override
  final String title;
  final sf.PdfDestination? dest;
  final bool destThrows;
  final List<_FakeBm> children;
  int destinationReads = 0;

  @override
  sf.PdfDestination? get destination {
    destinationReads++;
    if (destThrows) throw StateError('đích hỏng');
    return dest;
  }

  @override
  int get count => children.length;
  @override
  sf.PdfBookmark operator [](int index) => children[index];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeRoot implements sf.PdfBookmarkBase {
  _FakeRoot(this.items, {this.throwAt});
  final List<sf.PdfBookmark> items;
  final int? throwAt;
  @override
  int get count => items.length;
  @override
  sf.PdfBookmark operator [](int index) {
    if (index == throwAt) throw StateError('mục lục hỏng');
    return items[index];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDoc implements sf.PdfDocument {
  _FakeDoc(this.bookmarks, this.pages);
  @override
  final sf.PdfBookmarkBase bookmarks;
  @override
  final sf.PdfPageCollection pages;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------- PDF thật ----------
sf.PdfDocument _realDoc(void Function(sf.PdfDocument d) build, {int pages = 4}) {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    doc.pages.add();
  }
  build(doc);
  final bytes = doc.saveSync();
  doc.dispose();
  return sf.PdfDocument(inputBytes: bytes);
}

// PDF 4 trang; bookmark "Chuong ten" có /Dest (Trang3) trỏ tên tới trang 3 (cây tên /Names /Dests).
List<int> _namedDestPdf() {
  final objs = <String>[
    '<< /Type /Catalog /Pages 2 0 R /Outlines 7 0 R /Names << /Dests << /Names [(Trang3) [5 0 R /XYZ 0 0 null]] >> >> >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R 6 0 R] /Count 4 >>',
    for (var i = 0; i < 4; i++)
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>',
    '<< /Type /Outlines /First 8 0 R /Last 8 0 R /Count 1 >>',
    '<< /Title (Chuong ten) /Parent 7 0 R /Dest (Trang3) >>',
  ];
  final sb = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offsets.add(sb.length);
    sb.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = sb.length;
  sb.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    sb.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  sb.write(
    'trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return sb.toString().codeUnits;
}

void main() {
  group('pageOf (qua flattenOutline)', () {
    test('O1-1 đích tới trang index 2 ⇒ pageNumber = 3', () {
      final loaded = _realDoc((d) {
        d.bookmarks.add('Chuong 1').destination =
            sf.PdfDestination(d.pages[2], const Offset(0, 0));
      });
      final r = flattenOutline(loaded);
      expect(r.map((e) => e.pageNumber), [3]);
      loaded.dispose();
    });

    test('O1-2 đọc đích ném ⇒ pageNumber null, không ném, mục vẫn có', () {
      final bm = _FakeBm('Hong', destThrows: true);
      final pages = _FakePages([_FakePage()]);
      final r = flattenOutline(_FakeDoc(_FakeRoot([bm]), pages));
      expect(bm.destinationReads, 1);
      expect(pages.indexOfCalls, 0); // dừng ở catch, không tới indexOf
      expect(r.length, 1);
      expect(r.single.pageNumber, isNull);
    });

    test('O1-3 bookmark không có đích ⇒ pageNumber null', () {
      final loaded = _realDoc((d) => d.bookmarks.add('Khong dich'));
      final r = flattenOutline(loaded);
      expect(r.map((e) => e.title), ['Khong dich']);
      expect(r.single.pageNumber, isNull);
      loaded.dispose();
    });

    test('O1-5 trang đích không thuộc tài liệu (indexOf = -1) ⇒ pageNumber null', () {
      final pages = _FakePages([_FakePage()]);
      final bm = _FakeBm('Lac', dest: _FakeDest(_FakePage()));
      final r = flattenOutline(_FakeDoc(_FakeRoot([bm]), pages));
      expect(pages.indexOfCalls, 1);
      expect(r.single.pageNumber, isNull);
    });

    test('O1-6 (bổ sung) bookmark dùng named destination tới trang 3 ⇒ pageNumber = 3', () {
      // Setter namedDestination của Syncfusion không ghi đích vào bookmark ⇒ dựng PDF bằng bytes.
      final loaded = sf.PdfDocument(inputBytes: _namedDestPdf());
      final r = flattenOutline(loaded);
      expect(r.map((e) => e.title), ['Chuong ten']);
      expect(r.single.pageNumber, 3);
      loaded.dispose();
    });
  });

  group('walk', () {
    test('O2-1 một mục gốc có tiêu đề ⇒ 1 mục, depth 0, tiêu đề giữ nguyên (bỏ khoảng trắng đầu cuối)', () {
      final loaded = _realDoc((d) {
        d.bookmarks.add('  Chuong 1 ').destination =
            sf.PdfDestination(d.pages[0], const Offset(0, 0));
      });
      final r = flattenOutline(loaded);
      expect(r.map((e) => e.title), ['Chuong 1']);
      expect(r.map((e) => e.depth), [0]);
      loaded.dispose();
    });

    test('O2-2 không có mục lục ⇒ danh sách rỗng', () {
      final loaded = _realDoc((_) {}, pages: 1);
      expect(flattenOutline(loaded), isEmpty);
      loaded.dispose();
    });

    test('O2-3 tiêu đề chỉ khoảng trắng ⇒ vẫn có mục, tiêu đề hiển thị không rỗng; con có depth 1', () {
      final root = _FakeBm('   ', children: [_FakeBm('Con')]);
      final r = flattenOutline(_FakeDoc(_FakeRoot([root]), _FakePages([])));
      expect(r.length, 2);
      expect(r.first.title.trim(), isNotEmpty);
      expect(r.map((e) => e.depth), [0, 1]);
      expect(r.last.title, 'Con');
    });
  });

  group('flattenOutline', () {
    test('O3-1 cây hợp lệ 2 cấp ⇒ duyệt đúng thứ tự đọc', () {
      final loaded = _realDoc((d) {
        final c1 = d.bookmarks.add('C1');
        c1.destination = sf.PdfDestination(d.pages[0], const Offset(0, 0));
        c1.add('C1.1').destination =
            sf.PdfDestination(d.pages[1], const Offset(0, 0));
        d.bookmarks.add('C2').destination =
            sf.PdfDestination(d.pages[3], const Offset(0, 0));
      });
      final r = flattenOutline(loaded);
      expect(r.map((e) => e.title), ['C1', 'C1.1', 'C2']);
      expect(r.map((e) => e.depth), [0, 1, 0]);
      expect(r.map((e) => e.pageNumber), [1, 2, 4]);
      loaded.dispose();
    });

    test('O3-2 đọc cây mục lục ném giữa chừng ⇒ không ném, trả về danh sách', () {
      final root = _FakeRoot([_FakeBm('A'), _FakeBm('B')], throwAt: 1);
      final Object r = (() {
        try {
          return flattenOutline(_FakeDoc(root, _FakePages([])));
        } catch (e) {
          return e;
        }
      })();
      expect(r, isA<List<OutlineEntry>>());
    });
  });
}
