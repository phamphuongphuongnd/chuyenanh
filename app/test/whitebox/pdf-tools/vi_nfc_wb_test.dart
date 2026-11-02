// Kiểm thử hộp trắng (A03) cho lib/features/pdf_tools/logic/vi_nfc.dart.
// Thiết kế: test-output/whitebox/pdf-tools/vi_nfc/buoc-5-du-lieu-thu.md — expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/vi_nfc.dart';

void main() {
  group('U1 _isShape', () {
    test('U1.1 Z1Đ: dấu mũ', () {
      expect(composeVietnamese('â'), 'â');
      expect(composeVietnamese('Â'), 'Â');
    });
    test('U1.2 Z2Đ: dấu trăng', () => expect(composeVietnamese('ă'), 'ă'));
    test('U1.3 Z3Đ: dấu râu', () {
      expect(composeVietnamese('ư'), 'ư');
      expect(composeVietnamese('Ơ'), 'Ơ');
    });
    test('U1.4 Z3S: dấu thanh không phải dấu hình', () {
      expect(composeVietnamese('à'), 'à');
    });
  });

  test('U2.1 _isTone: đủ 5 dấu thanh', () {
    expect(
      [for (final t in ['̀', '́', '̃', '̉', '̣']) composeVietnamese('a$t')],
      ['à', 'á', 'ã', 'ả', 'ạ'],
    );
  });

  group('U3 composeVietnamese', () {
    test('U3.1 dấu hình rồi dấu thanh ⇒ ệ', () {
      expect(composeVietnamese('ệ'), 'ệ');
    });
    test('U3.2 V1S: rỗng', () => expect(composeVietnamese(''), ''));
    test('U3.3 V2S V7S: 1 chữ', () => expect(composeVietnamese('a'), 'a'));
    test('U3.4 V4S: chữ thường liền nhau', () => expect(composeVietnamese('ab'), 'ab'));
    test('U3.5 V6Đ: dấu hình không ghép được ⇒ giữ nguyên', () {
      final r = composeVietnamese('b̂');
      expect(r.runes.length, 2); // đi nhánh break: không ghép
      expect(r, 'b̂');
    });
    test('U3.6 V8Đ: dấu thanh không ghép được ⇒ giữ nguyên', () {
      expect(composeVietnamese('b́'), 'b́');
    });
    test('U3.7 dấu thanh trước dấu hình ⇒ ệ', () {
      expect(composeVietnamese('ệ'), 'ệ');
    });
    test('U3.8 V7S sau ghép dấu hình ⇒ ơ', () {
      expect(composeVietnamese('ơ'), 'ơ');
    });
    test('U3.9 câu thật; chuỗi đã NFC giữ nguyên', () {
      expect(composeVietnamese('Hà Nội'), 'Hà Nội');
      expect(composeVietnamese('Hà Nội 河内 hello'), 'Hà Nội 河内 hello');
    });
  });
}
