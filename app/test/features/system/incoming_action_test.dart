import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/features/system/incoming_action.dart';

void main() {
  group('planIncoming', () {
    test('1 PDF -> mo trinh doc PDF', () {
      final plan = planIncoming(['/c/a.pdf']);
      expect(plan.action, const OpenInApp('/c/a.pdf', Routes.pdfReader));
      expect(plan.unsupported, 0);
      expect(plan.notOpened, 0);
    });

    test('1 DOCX / TXT -> viewer tuong ung', () {
      expect(
        planIncoming(['/c/b.DOCX']).action,
        const OpenInApp('/c/b.DOCX', Routes.docxViewer),
      );
      expect(
        planIncoming(['/c/n.txt']).action,
        const OpenInApp('/c/n.txt', Routes.txtViewer),
      );
    });

    test('DOC/XLS/PPT doi cu -> app ngoai', () {
      expect(
        planIncoming(['/c/old.xls']).action,
        const OpenExternal('/c/old.xls'),
      );
    });

    test('3 anh -> Anh sang PDF voi ca 3, giu thu tu', () {
      final plan = planIncoming(['/c/1.jpg', '/c/2.PNG', '/c/3.heic']);
      expect(
        plan.action,
        const ImagesToPdf(['/c/1.jpg', '/c/2.PNG', '/c/3.heic']),
      );
      expect(plan.notOpened, 0);
    });

    test('PDF + anh -> mo PDF, anh tinh vao notOpened', () {
      final plan = planIncoming(['/c/x.jpg', '/c/a.pdf']);
      expect(plan.action, const OpenInApp('/c/a.pdf', Routes.pdfReader));
      expect(plan.notOpened, 1);
    });

    test('nhieu PDF -> man Gop voi file dau', () {
      final plan = planIncoming(['/c/a.pdf', '/c/b.pdf', '/c/c.pdf']);
      expect(
        plan.action,
        const MergePdfs(['/c/a.pdf', '/c/b.pdf', '/c/c.pdf']),
      );
      expect((plan.action as MergePdfs).first, '/c/a.pdf');
      expect(plan.notOpened, 2);
    });

    test('PDF + DOCX (khong phai toan PDF) -> mo tai lieu dau', () {
      final plan = planIncoming(['/c/a.docx', '/c/b.pdf']);
      expect(plan.action, const OpenInApp('/c/a.docx', Routes.docxViewer));
      expect(plan.notOpened, 1);
    });

    test('duoi la -> khong mo gi, dem unsupported', () {
      final plan = planIncoming(['/c/virus.exe', '/c/noext']);
      expect(plan.action, const NothingToOpen());
      expect(plan.unsupported, 2);
    });

    test('duoi la lan voi PDF -> mo PDF, van dem unsupported', () {
      final plan = planIncoming(['/c/a.zip', '/c/b.pdf']);
      expect(plan.action, const OpenInApp('/c/b.pdf', Routes.pdfReader));
      expect(plan.unsupported, 1);
      expect(plan.notOpened, 0);
    });

    test('danh sach rong', () {
      expect(planIncoming(const []).action, const NothingToOpen());
    });
  });
}
