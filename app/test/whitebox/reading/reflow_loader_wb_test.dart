// Kiểm thử hộp trắng (A15) — reflow_loader.dart. Mã bộ theo
// test-output/whitebox/reading/reflow_loader/buoc-5-du-lieu-thu.md. PDF tạo bằng Syncfusion trong thư mục tạm
// (không dùng PDF có mật khẩu).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/reading/data/reflow_loader.dart';
import 'package:pdf_office/features/reading/logic/reflow_document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<Uint8List> _pdfPages(List<String?> texts) async {
  final doc = sf.PdfDocument();
  for (final t in texts) {
    final page = doc.pages.add();
    if (t != null) {
      page.graphics.drawString(
        t,
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
      );
    }
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

Future<Uint8List> _pdf({String? text}) async {
  final doc = sf.PdfDocument();
  final page = doc.pages.add();
  if (text != null) {
    page.graphics.drawString(
      text,
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
    );
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_reflow_'));
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<Object> run(String path) =>
      loadReflowDocument(path).then((d) => d as Object, onError: (Object e) => e);

  test('1-1 PDF có chữ ⇒ ReflowDocument có đoạn chữ', () async {
    final f = File('${tmp.path}/text.pdf')
      ..writeAsBytesSync(await _pdf(text: 'Hello PDF Office'));
    final r = await run(f.path);
    expect(r, isA<ReflowDocument>());
    final doc = r as ReflowDocument;
    expect(doc.hasText, isTrue); // nhánh D4 S (có chữ ⇒ dựng khối)
    expect(doc.paragraphs.join(' '), contains('Hello PDF Office'));
  });

  test('1-6 đệm: lần 2 đọc từ JSON, kết quả y hệt; đệm hỏng ⇒ dàn lại; có mật khẩu ⇒ không ghi đệm', () async {
    final f = File('${tmp.path}/cache.pdf')
      ..writeAsBytesSync(await _pdf(text: 'Hello cache'));
    final cacheDir = Directory('${tmp.path}/c')..createSync();
    final first = await loadReflowDocument(f.path, cacheDir: cacheDir);
    final files = cacheDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    final second = await loadReflowDocument(f.path, cacheDir: cacheDir);
    expect(second.paragraphs, first.paragraphs);
    expect(second.pageCount, first.pageCount);
    expect(second.items.length, first.items.length);

    files.single.writeAsStringSync('{hỏng');
    final third = await loadReflowDocument(f.path, cacheDir: cacheDir);
    expect(third.paragraphs, first.paragraphs);

    final other = Directory('${tmp.path}/c2')..createSync();
    await loadReflowDocument(f.path, password: 'x', cacheDir: other)
        .then((_) {}, onError: (_) {});
    expect(other.listSync(), isEmpty);
  });

  test('1-7 JSON khứ hồi giữ đủ trường các loại dòng', () {
    const doc = ReflowDocument.empty(pageCount: 3);
    expect(reflowDocumentFromJson(reflowDocumentToJson(doc)).pageCount, 3);
    final full = ReflowDocument(pageCount: 1, items: const [
      ReflowItem(kind: ReflowKind.heading, page: 0, text: 'T', level: 2, bold: true),
      ReflowItem(kind: ReflowKind.listItem, page: 0, text: 'x', marker: '1.', ordered: true),
      ReflowItem(kind: ReflowKind.tableRow, page: 0, text: 'a · b', cells: ['a', 'b']),
    ]);
    final back = reflowDocumentFromJson(reflowDocumentToJson(full));
    expect(back.paragraphs, full.paragraphs);
    expect(back.items[0].level, 2);
    expect(back.items[1].ordered, isTrue);
    expect(back.items[2].cells, ['a', 'b']);
  });

  test('1-2 file không tồn tại ⇒ CorruptFile', () async {
    final r = await run('${tmp.path}/khong-co.pdf');
    expect(r, isA<CorruptFile>());
  });

  test('1-3 đường dẫn là thư mục (Windows: Access denied, errno 5) ⇒ PermissionDenied', () async {
    final dir = Directory('${tmp.path}/thu-muc')..createSync();
    final r = await run(dir.path);
    expect(r, isA<PermissionDenied>());
  });

  test('1-4 bytes không phải PDF ⇒ CorruptFile', () async {
    final f = File('${tmp.path}/rac.pdf')..writeAsStringSync('không phải pdf');
    final r = await run(f.path);
    expect(r, isA<CorruptFile>());
  });

  test('1-5 PDF trang trắng (như bản quét) ⇒ ReflowDocument.empty giữ số trang', () async {
    final f = File('${tmp.path}/blank.pdf')..writeAsBytesSync(await _pdf());
    final r = await run(f.path);
    expect(r, isA<ReflowDocument>());
    final doc = r as ReflowDocument;
    expect(doc.items, isEmpty); // nhánh D4 Đ
    expect(doc.hasText, isFalse);
    expect(doc.pageCount, 1);
  });

  group('streamReflowDocument (dàn tiến dần theo trang)', () {
    test('2-1 PDF 4 trang: lô 1, 2 rồi 1 trang; mỗi lần phát nối thêm; trang 1 có sớm', () async {
      final f = File('${tmp.path}/four.pdf')
        ..writeAsBytesSync(
          await _pdfPages(['Alpha one', 'Beta two', 'Gamma three', 'Delta four']),
        );
      final cacheDir = Directory('${tmp.path}/c')..createSync();
      final progress = await streamReflowDocument(
        f.path,
        cacheDir: cacheDir,
      ).toList();
      expect(progress.map((p) => p.pagesDone), [1, 3, 4]);
      expect(progress.map((p) => p.done), [false, false, true]);
      expect(progress.every((p) => p.doc.pageCount == 4), isTrue);
      // Lần phát đầu đã có chữ trang 1 và chưa có trang 2.
      expect(progress.first.doc.paragraphs.join(' '), contains('Alpha one'));
      expect(progress.first.doc.paragraphs.join(' '), isNot(contains('Beta')));
      // Mỗi lần phát chỉ nối thêm vào cuối: các dòng cũ giữ nguyên chỉ số.
      for (var i = 1; i < progress.length; i++) {
        final prev = progress[i - 1].doc.items, cur = progress[i].doc.items;
        expect(cur.length, greaterThan(prev.length));
        for (var k = 0; k < prev.length; k++) {
          expect(cur[k].text, prev[k].text);
          expect(cur[k].kind, prev[k].kind);
        }
      }
      final last = progress.last.doc;
      final all = last.paragraphs.join(' ');
      for (final w in ['Alpha one', 'Beta two', 'Gamma three', 'Delta four']) {
        expect(all, contains(w));
      }
      // Ngăn trang và số trang đúng như dàn một lần.
      expect(
        last.items.where((i) => i.kind == ReflowKind.pageMarker).map((i) => i.page),
        [0, 1, 2, 3],
      );
      expect(last.items.every((i) => i.page >= 0 && i.page < 4), isTrue);
      // Dàn xong thì ghi đệm; lần sau phát MỘT lần đủ tài liệu.
      expect(cacheDir.listSync().whereType<File>(), hasLength(1));
      final again = await streamReflowDocument(f.path, cacheDir: cacheDir).toList();
      expect(again, hasLength(1));
      expect(again.single.done, isTrue);
      expect(again.single.doc.paragraphs, last.paragraphs);
    });

    test('2-2 trang giữa trắng ⇒ trang ảnh đúng chỗ; loadReflowDocument = bản cuối', () async {
      final f = File('${tmp.path}/gap.pdf')
        ..writeAsBytesSync(await _pdfPages(['First page', null, 'Third page']));
      final streamed = await streamReflowDocument(f.path, cacheDir: Directory('${tmp.path}/a')..createSync()).toList();
      final loaded = await loadReflowDocument(f.path, cacheDir: Directory('${tmp.path}/b')..createSync());
      expect(loaded.paragraphs, streamed.last.doc.paragraphs);
      expect(
        loaded.items.where((i) => i.kind == ReflowKind.imagePage).map((i) => i.page),
        [1],
      );
    });

    test('2-3 toàn trang trắng ⇒ phát cuối là tài liệu rỗng giữ số trang', () async {
      final f = File('${tmp.path}/blank3.pdf')
        ..writeAsBytesSync(await _pdfPages([null, null, null]));
      final progress = await streamReflowDocument(f.path, cacheDir: Directory('${tmp.path}/c')..createSync()).toList();
      expect(progress.last.done, isTrue);
      expect(progress.last.doc.hasText, isFalse);
      expect(progress.last.doc.items, isEmpty);
      expect(progress.last.doc.pageCount, 3);
    });

    test('2-4 file hỏng ⇒ luồng báo CorruptFile, không phát gì', () async {
      final f = File('${tmp.path}/rac.pdf')..writeAsStringSync('không phải pdf');
      final got = <ReflowProgress>[];
      Object? error;
      try {
        await for (final p in streamReflowDocument(f.path, cacheDir: Directory('${tmp.path}/c')..createSync())) {
          got.add(p);
        }
      } catch (e) {
        error = e;
      }
      expect(error, isA<CorruptFile>());
      expect(got, isEmpty);
    });

    test('2-5 huỷ đăng ký sau lần phát đầu ⇒ kết thúc sạch, không ghi đệm', () async {
      final f = File('${tmp.path}/cancel.pdf')
        ..writeAsBytesSync(await _pdfPages(['One', 'Two', 'Three']));
      final cacheDir = Directory('${tmp.path}/c')..createSync();
      final first = await streamReflowDocument(f.path, cacheDir: cacheDir).first;
      expect(first.done, isFalse);
      expect(first.pagesDone, 1);
      expect(cacheDir.listSync(), isEmpty);
    });
  });
}
