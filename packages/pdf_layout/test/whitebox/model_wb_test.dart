// Kiểm thử hộp trắng (A18) — lib/src/model.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

void main() {
  test('U1-P1 LayoutRect: gốc trên-trái, y tăng xuống; words mặc định rỗng', () {
    const r = LayoutRect(left: 10, top: 20, width: 30, height: 40);
    expect(r.right, 40);
    expect(r.bottom, 60);
    expect(r.centerX, 25);
    expect(r.centerY, 40);
    const l = LayoutLine(pageIndex: 0, text: 'x', bounds: r, fontSize: 10);
    expect(l.words, isEmpty);
    const w = LayoutWord(text: 'x', bounds: r, fontSize: 10);
    expect(w.bold, isFalse);
  });
}
