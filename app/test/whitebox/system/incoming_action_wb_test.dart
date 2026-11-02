// Kiểm thử hộp trắng A13 — app/lib/features/system/incoming_action.dart
// Thiết kế: test-output/whitebox/system/incoming_action/buoc-1..5. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/features/system/incoming_action.dart';

void main() {
  group('U1 OpenInApp.==', () {
    const a = OpenInApp('/a.pdf', '/r');
    test('1-1 cùng path + route ⇒ true', () => expect(a == const OpenInApp('/a.pdf', '/r'), isTrue));
    test('1-2 khác kiểu ⇒ false', () => expect(a == const OpenExternal('/a.pdf') as Object, isFalse));
    test('1-3 khác path ⇒ false', () => expect(a == const OpenInApp('/b.pdf', '/r'), isFalse));
    test('1-4 khác route ⇒ false', () => expect(a == const OpenInApp('/a.pdf', '/q'), isFalse));
  });

  group('U2 OpenExternal.==', () {
    const a = OpenExternal('/a.doc');
    test('2-1 cùng ⇒ true', () => expect(a == const OpenExternal('/a.doc'), isTrue));
    test('2-2 khác kiểu ⇒ false', () => expect(a == const NothingToOpen() as Object, isFalse));
    test('2-3 khác path ⇒ false', () => expect(a == const OpenExternal('/b.doc'), isFalse));
  });

  group('U3 ImagesToPdf.==', () {
    const a = ImagesToPdf(['a', 'b']);
    test('3-1 cùng list ⇒ true', () => expect(a == const ImagesToPdf(['a', 'b']), isTrue));
    test('3-2 khác kiểu ⇒ false', () => expect(a == const MergePdfs(['a', 'b']) as Object, isFalse));
    test('3-3 khác phần tử ⇒ false', () => expect(a == const ImagesToPdf(['a', 'c']), isFalse));
  });

  group('U4 MergePdfs.==', () {
    const a = MergePdfs(['a', 'b']);
    test('4-1 cùng ⇒ true', () => expect(a == const MergePdfs(['a', 'b']), isTrue));
    test('4-2 khác kiểu ⇒ false', () => expect(a == const ImagesToPdf(['a', 'b']) as Object, isFalse));
    test('4-3 khác thứ tự ⇒ false', () => expect(a == const MergePdfs(['b', 'a']), isFalse));
  });

  group('U5 isSupportedIncomingPath', () {
    test('5-1 PDF chữ hoa ⇒ true', () => expect(isSupportedIncomingPath('/x/A.PDF'), isTrue));
    test('5-2 ảnh HEIC ⇒ true', () => expect(isSupportedIncomingPath('/x/p.HEIC'), isTrue));
    test('5-3 đuôi lạ / đuôi kép / file ẩn / không đuôi ⇒ false', () {
      for (final p in ['/x/a.exe', '/x/a.pdf.exe', '/x/.pdf', '/x/noext', '/x/a.svg', '/x/a.html', '/x/a.apk']) {
        expect(isSupportedIncomingPath(p), isFalse, reason: p);
      }
    });
  });

  group('U6 planIncoming', () {
    test('6-1 không file hợp lệ ⇒ NothingToOpen, unsupported 2', () {
      final r = planIncoming(['/a.exe', '/b.zip']);
      expect(r.action, const NothingToOpen());
      expect(r.unsupported, 2);
      expect(r.notOpened, 0);
    });
    test('6-2 chỉ ảnh ⇒ ImagesToPdf giữ thứ tự', () {
      final r = planIncoming(['/1.jpg', '/2.png']);
      expect(r.action, const ImagesToPdf(['/1.jpg', '/2.png']));
      expect(r.notOpened, 0);
    });
    test('6-3 1 TXT + ảnh ⇒ mở TXT, notOpened 1', () {
      final r = planIncoming(['/a.txt', '/x.jpg']);
      expect(r.action, const OpenInApp('/a.txt', Routes.txtViewer));
      expect(r.notOpened, 1);
    });
    test('6-4 PPT đời cũ ⇒ OpenExternal', () {
      expect(planIncoming(['/o.ppt']).action, const OpenExternal('/o.ppt'));
    });
    test('6-5 2 PDF + ảnh ⇒ MergePdfs, notOpened 2', () {
      final r = planIncoming(['/a.pdf', '/x.jpg', '/b.PDF']);
      expect(r.action, const MergePdfs(['/a.pdf', '/b.PDF']));
      expect(r.notOpened, 2);
    });
    test('6-6 PDF + XLSX ⇒ mở PDF đầu', () {
      final r = planIncoming(['/a.pdf', '/b.xlsx']);
      expect(r.action, const OpenInApp('/a.pdf', Routes.pdfReader));
      expect(r.notOpened, 1);
    });
  });

  group('U7 _listEquals (qua ImagesToPdf.==)', () {
    test('7-1 khác độ dài ⇒ false', () => expect(const ImagesToPdf(['a']) == const ImagesToPdf(['a', 'b']), isFalse));
    test('7-2 hai list rỗng ⇒ true', () => expect(const ImagesToPdf([]) == const ImagesToPdf([]), isTrue));
    test('7-3 cùng phần tử ⇒ true', () => expect(const ImagesToPdf(['a', 'b']) == const ImagesToPdf(['a', 'b']), isTrue));
    test('7-4 khác phần tử cuối ⇒ false', () => expect(const ImagesToPdf(['a', 'b']) == const ImagesToPdf(['a', 'x']), isFalse));
  });
}
