// Kiểm thử hộp trắng A19 — lib/src/xml_utils.dart (mã bộ X*, xem
// test-output/whitebox/pptx-reader/xml_utils/buoc-5-du-lieu-thu.md).
// Hàm thuần, không mock: nhánh đã đi được khẳng định qua giá trị phân biệt theo nhánh.
import 'package:pptx_reader/src/xml_utils.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('X1 child', () {
    test('X1.1 con đầu tiên đúng local name (bỏ qua prefix)', () {
      final e = el('<a:r xmlns:a="u"><a:t>x</a:t></a:r>');
      expect(e.child('t')?.innerText, 'x');
    });
    test('X1.2 không có con ⇒ null', () {
      expect(el('<r/>').child('t'), isNull);
    });
    test('X1.3 con không phải element (text) bị bỏ qua', () {
      final e = el('<r>text<t>y</t></r>');
      expect(e.child('t')?.innerText, 'y');
    });
    test('X1.4 element khác tên bị bỏ qua ⇒ null', () {
      expect(el('<r><u/></r>').child('t'), isNull);
    });
  });

  group('X2 at', () {
    test('X2.1 đường rỗng ⇒ chính nó', () {
      final e = el('<r/>');
      expect(identical(e.at([]), e), isTrue);
    });
    test('X2.2 theo chuỗi tên con', () {
      final e = el('<r><a><b v="1"/></a></r>');
      expect(e.at(['a', 'b'])?.attr('v'), '1');
    });
    test('X2.3 đứt giữa chừng ⇒ null', () {
      final e = el('<r><a/></r>');
      expect(e.at(['a', 'zz', 'b']), isNull);
    });
  });

  group('X3 attr', () {
    test('X3.1 không có thuộc tính ⇒ null', () {
      expect(el('<r/>').attr('val'), isNull);
    });
    test('X3.2 thuộc tính không prefix ⇒ giá trị', () {
      expect(el('<r val="x"/>').attr('val'), 'x');
    });
    test('X3.3 tên khác ⇒ null', () {
      expect(el('<r foo="x"/>').attr('val'), isNull);
    });
    test('X3.4 cùng local name nhưng có prefix ⇒ null', () {
      expect(el('<r xmlns:r="u" r:val="x"/>').attr('val'), isNull);
    });
  });

  group('X4 nsAttr', () {
    test('X4.1 không có thuộc tính ⇒ null', () {
      expect(el('<r/>').nsAttr('id'), isNull);
    });
    test('X4.2 thuộc tính có prefix bất kỳ ⇒ giá trị', () {
      expect(el('<r xmlns:q="u" q:id="rId1"/>').nsAttr('id'), 'rId1');
    });
    test('X4.3 tên khác ⇒ null', () {
      expect(el('<r xmlns:q="u" q:embed="rId1"/>').nsAttr('id'), isNull);
    });
    test('X4.4 cùng local name không prefix ⇒ null', () {
      expect(el('<r id="rId1"/>').nsAttr('id'), isNull);
    });
  });

  group('X5 intAttr', () {
    test('X5.1 số nguyên ⇒ int', () {
      expect(el('<r sz="1200"/>').intAttr('sz'), 1200);
    });
    test('X5.2 thiếu thuộc tính ⇒ null', () {
      expect(el('<r/>').intAttr('sz'), isNull);
    });
    test('X5.3 số thập phân ⇒ không ném, trả int hoặc null (*)', () {
      final r = el('<r sz="12.6"/>').intAttr('sz');
      expect(r == null || r is int, isTrue);
    });
    test('X5.4 không phải số ⇒ null', () {
      expect(el('<r sz="abc"/>').intAttr('sz'), isNull);
    });
  });

  group('X6 doubleAttr', () {
    test('X6.1 số thực ⇒ double', () {
      expect(el('<r v="1.5"/>').doubleAttr('v'), 1.5);
    });
    test('X6.2 thiếu thuộc tính ⇒ null', () {
      expect(el('<r/>').doubleAttr('v'), isNull);
    });
  });

  group('X7 boolAttr (ST_OnOff)', () {
    test("X7.1 '1' ⇒ true", () => expect(el('<r b="1"/>').boolAttr('b'), true));
    test('X7.2 thiếu ⇒ null', () => expect(el('<r/>').boolAttr('b'), isNull));
    test("X7.3 'true' ⇒ true", () => expect(el('<r b="true"/>').boolAttr('b'), true));
    test("X7.4 'on' ⇒ true", () => expect(el('<r b="on"/>').boolAttr('b'), true));
    test("X7.5 '0' ⇒ false", () => expect(el('<r b="0"/>').boolAttr('b'), false));
  });
}
