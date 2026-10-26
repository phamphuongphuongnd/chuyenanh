import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/logic/outline.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  test('flattenOutline: duyet cay muc luc theo thu tu, kem do sau va so trang', () {
    final doc = sf.PdfDocument();
    for (var i = 0; i < 4; i++) {
      doc.pages.add();
    }
    final ch1 = doc.bookmarks.add('Chuong 1');
    ch1.destination = sf.PdfDestination(doc.pages[0], const Offset(0, 0));
    final sec = ch1.add('Muc 1.1');
    sec.destination = sf.PdfDestination(doc.pages[2], const Offset(0, 0));
    final ch2 = doc.bookmarks.add('Chuong 2');
    ch2.destination = sf.PdfDestination(doc.pages[3], const Offset(0, 0));

    final bytes = doc.saveSync();
    doc.dispose();
    final loaded = sf.PdfDocument(inputBytes: bytes);

    final entries = flattenOutline(loaded);
    expect(entries.map((e) => e.title), ['Chuong 1', 'Muc 1.1', 'Chuong 2']);
    expect(entries.map((e) => e.depth), [0, 1, 0]);
    expect(entries.map((e) => e.pageNumber), [1, 3, 4]);
    loaded.dispose();
  });

  test('flattenOutline: tai lieu khong co muc luc tra ve rong', () {
    final doc = sf.PdfDocument();
    doc.pages.add();
    final loaded = sf.PdfDocument(inputBytes: doc.saveSync());
    doc.dispose();
    expect(flattenOutline(loaded), isEmpty);
    loaded.dispose();
  });
}
