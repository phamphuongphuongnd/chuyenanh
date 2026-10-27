import 'package:office_reader/src/common.dart';
import 'package:test/test.dart';

void main() {
  group('OoxmlPackage.resolvePath', () {
    test('giải mã %20 và nối thư mục gốc', () {
      expect(
        OoxmlPackage.resolvePath('word', 'media/a%20b.png'),
        'word/media/a b.png',
      );
    });

    test('Target có % trần hoặc UTF-8 sai không ném lỗi', () {
      expect(OoxmlPackage.resolvePath('word', 'media/anh%.png'), 'word/media/anh%.png');
      expect(() => OoxmlPackage.resolvePath('word', 'media/a%FF.png'), returnsNormally);
    });

    test('.. và đường dẫn tuyệt đối', () {
      expect(OoxmlPackage.resolvePath('word/sub', '../media/x.png'), 'word/media/x.png');
      expect(OoxmlPackage.resolvePath('word', '/customXml/i.xml'), 'customXml/i.xml');
    });
  });
}
