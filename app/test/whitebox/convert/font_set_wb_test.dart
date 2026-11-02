// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/font_set.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/font_set/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
// ignore_for_file: implementation_imports
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/graphics/fonts/pdf_font.dart' show PdfFontHelper;

const _dir = r'C:\Windows\Fonts\';
final _regular = File('${_dir}arial.ttf').readAsBytesSync();
final _bold = File('${_dir}arialbd.ttf').readAsBytesSync();

bool _isBold(PdfFont f) => PdfFontHelper.getHelper(f).isBold;
bool _isItalic(PdfFont f) => PdfFontHelper.getHelper(f).isItalic;

/// Nguồn font giả: trả byte cho slot có trong map, ghi lại slot được hỏi.
class _Src implements FontSource {
  _Src(this.map);
  final Map<FontSlot, Uint8List> map;
  final asked = <FontSlot>[];
  @override
  Future<Uint8List?> load(FontSlot slot) async {
    asked.add(slot);
    return map[slot];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = <String>[];
  final origPrint = debugPrint;
  setUp(() {
    logs.clear();
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  });
  tearDown(() => debugPrint = origPrint);

  group('U1 FontSlot.forFace', () {
    test('U1-P1 latin ⇒ regular', () => expect(FontSlot.forFace(ScriptFace.latin), FontSlot.regular));
    test('U1-P2 chinese ⇒ chinese', () => expect(FontSlot.forFace(ScriptFace.chinese), FontSlot.chinese));
    test('U1-P3 japanese ⇒ japanese', () => expect(FontSlot.forFace(ScriptFace.japanese), FontSlot.japanese));
    test('U1-P4 korean ⇒ korean', () => expect(FontSlot.forFace(ScriptFace.korean), FontSlot.korean));
  });

  group('U2 AssetFontSource.load', () {
    test('U2-P1 có asset NotoSans-Regular ⇒ trả byte, không log', () async {
      final b = await const AssetFontSource().load(FontSlot.regular);
      expect(logs, isEmpty);
      expect(b, isNotNull);
      expect(b!.length, greaterThan(100000));
    });

    test('U2-P2 thiếu asset (kênh flutter/assets trả null) ⇒ null + log "thiếu font"', () async {
      final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMessageHandler('flutter/assets', (_) async => null);
      try {
        final b = await const AssetFontSource().load(FontSlot.korean);
        expect(logs.join('\n'), contains('NotoSansKR-Regular.ttf'));
        expect(b, isNull);
      } finally {
        m.setMockMessageHandler('flutter/assets', null);
      }
    });
  });

  group('U3 FileFontSource.load', () {
    test('U3-P1 có đường dẫn, file tồn tại ⇒ byte của file', () async {
      final b = await const FileFontSource({FontSlot.regular: '${_dir}arial.ttf'}).load(FontSlot.regular);
      expect(b, isNotNull);
      expect(b!.length, _regular.length);
    });
    test('U3-P2 slot không có đường dẫn ⇒ null', () async {
      expect(await const FileFontSource({}).load(FontSlot.bold), isNull);
    });
    test('U3-P3 đường dẫn không tồn tại ⇒ null', () async {
      expect(await const FileFontSource({FontSlot.bold: r'C:\khong\co\font.ttf'}).load(FontSlot.bold), isNull);
    });
  });

  group('U4 loadFontBytes', () {
    test('U4-P1 needBold, chữ Latin, nguồn có đủ ⇒ {regular, bold}', () async {
      final src = _Src({FontSlot.regular: _regular, FontSlot.bold: _bold});
      final r = await loadFontBytes(src, {ScriptFace.latin});
      expect(src.asked.toSet(), {FontSlot.regular, FontSlot.bold}); // không hỏi font CJK
      expect(r.keys.toSet(), {FontSlot.regular, FontSlot.bold});
    });
    test('U4-P2 needBold=false ⇒ không nạp bold', () async {
      final src = _Src({FontSlot.regular: _regular, FontSlot.bold: _bold});
      final r = await loadFontBytes(src, {ScriptFace.latin}, needBold: false);
      expect(src.asked, isNot(contains(FontSlot.bold)));
      expect(r.keys.toSet(), {FontSlot.regular});
    });
    test('U4-P4 nguồn không có font nào ⇒ map rỗng (rơi về font chuẩn)', () async {
      final r = await loadFontBytes(const NoFontSource(), {ScriptFace.latin, ScriptFace.chinese});
      expect(r, isEmpty);
    });
    test('U4-P1b chữ Trung + Hàn ⇒ hỏi thêm đúng 2 font CJK đó', () async {
      final src = _Src({});
      await loadFontBytes(src, {ScriptFace.chinese, ScriptFace.korean}, needBold: false);
      expect(src.asked.toSet(), {FontSlot.regular, FontSlot.chinese, FontSlot.korean});
    });
  });

  group('U5 _effectiveSlot (qua usesStandard)', () {
    test('U5-P1 slot có byte ⇒ dùng chính nó (không font chuẩn), không log', () {
      final s = PdfFontSet({FontSlot.chinese: _regular});
      expect(s.usesStandard(FontSlot.chinese), isFalse);
      expect(logs, isEmpty);
    });
    test('U5-P2 thiếu bold ⇒ dùng regular, không cảnh báo', () {
      final s = PdfFontSet({FontSlot.regular: _regular});
      expect(s.usesStandard(FontSlot.bold), isFalse);
      expect(logs, isEmpty);
    });
    test('U5-P3 thiếu CJK, có regular ⇒ dùng regular + cảnh báo 1 lần', () {
      final s = PdfFontSet({FontSlot.regular: _regular});
      expect(s.usesStandard(FontSlot.japanese), isFalse);
      expect(logs.where((l) => l.contains('NotoSansJP')), hasLength(1));
    });
    test('U5-P4 gọi lại cùng slot thiếu ⇒ không cảnh báo lần 2', () {
      final s = PdfFontSet({FontSlot.regular: _regular});
      s.usesStandard(FontSlot.japanese);
      s.usesStandard(FontSlot.japanese);
      expect(logs.where((l) => l.contains('NotoSansJP')), hasLength(1));
    });
    test('U5-P5 không có font nào ⇒ font chuẩn', () {
      final s = PdfFontSet(const {});
      expect(s.usesStandard(FontSlot.korean), isTrue);
    });
  });

  group('U6 fontFor / U7 _create', () {
    test('U6-P1 / U7-P1 Latin thường, size 10, có regular ⇒ TrueType 10pt không đậm/nghiêng', () {
      final f = PdfFontSet({FontSlot.regular: _regular}).fontFor(ScriptFace.latin, const StyledSpan('a', size: 10));
      expect(f, isA<PdfTrueTypeFont>());
      expect(f.size, 10);
      expect(_isBold(f), isFalse);
      expect(_isItalic(f), isFalse);
    });
    test('U6-P2 size null ⇒ 12pt', () {
      final f = PdfFontSet({FontSlot.regular: _regular}).fontFor(ScriptFace.latin, const StyledSpan('a'));
      expect(f.size, 12);
    });
    test('U6-P3 chữ Trung, có font Trung ⇒ TrueType riêng (khác font Latin)', () {
      final s = PdfFontSet({FontSlot.regular: _regular, FontSlot.chinese: _bold});
      final zh = s.fontFor(ScriptFace.chinese, const StyledSpan('汉'));
      final la = s.fontFor(ScriptFace.latin, const StyledSpan('a'));
      expect(zh, isA<PdfTrueTypeFont>());
      expect(identical(zh, la), isFalse);
    });
    test('U6-P4 Latin đậm, có file bold ⇒ dùng file bold, không giả lập đậm', () {
      final s = PdfFontSet({FontSlot.regular: _regular, FontSlot.bold: _bold});
      final b = s.fontFor(ScriptFace.latin, const StyledSpan('Wide', bold: true, size: 12));
      final r = s.fontFor(ScriptFace.latin, const StyledSpan('Wide', size: 12));
      expect(_isBold(b), isFalse); // đậm thật từ file, không cờ giả lập
      expect(b.measureString('Wide text').width, greaterThan(r.measureString('Wide text').width));
    });
    test('U6-P5 / U7-P2 Latin đậm, thiếu file bold ⇒ regular + giả lập đậm', () {
      final f = PdfFontSet({FontSlot.regular: _regular}).fontFor(ScriptFace.latin, const StyledSpan('a', bold: true));
      expect(f, isA<PdfTrueTypeFont>());
      expect(_isBold(f), isTrue);
    });
    test('U6-P6 CJK đậm ⇒ giả lập đậm (CJK không có bản Bold)', () {
      final f = PdfFontSet({FontSlot.regular: _regular, FontSlot.korean: _regular})
          .fontFor(ScriptFace.korean, const StyledSpan('한', bold: true));
      expect(_isBold(f), isTrue);
    });
    test('U6-P7 gọi lại cùng kiểu ⇒ trả đúng đối tượng đã cache', () {
      final s = PdfFontSet({FontSlot.regular: _regular});
      final a = s.fontFor(ScriptFace.latin, const StyledSpan('a', size: 11));
      final b = s.fontFor(ScriptFace.latin, const StyledSpan('b', size: 11));
      expect(identical(a, b), isTrue);
    });
    test('U7-P3 nghiêng ⇒ TrueType có cờ nghiêng', () {
      final f = PdfFontSet({FontSlot.regular: _regular}).fontFor(ScriptFace.latin, const StyledSpan('a', italic: true));
      expect(_isItalic(f), isTrue);
      expect(_isBold(f), isFalse);
    });
    test('U7-P4 không có byte ⇒ font chuẩn Helvetica không style', () {
      final f = PdfFontSet(const {}).fontFor(ScriptFace.latin, const StyledSpan('a'));
      expect(f, isA<PdfStandardFont>());
      expect((f as PdfStandardFont).fontFamily, PdfFontFamily.helvetica);
      expect(_isBold(f), isFalse);
    });
    test('U7-P5 không có byte, nghiêng ⇒ font chuẩn có cờ nghiêng', () {
      final f = PdfFontSet(const {}).fontFor(ScriptFace.latin, const StyledSpan('a', italic: true));
      expect(f, isA<PdfStandardFont>());
      expect(_isItalic(f), isTrue);
    });
    test('U7-P6 không có byte, đậm + nghiêng ⇒ font chuẩn đậm nghiêng', () {
      final f = PdfFontSet(const {}).fontFor(ScriptFace.latin, const StyledSpan('a', bold: true, italic: true));
      expect(f, isA<PdfStandardFont>());
      expect(_isBold(f), isTrue);
      expect(_isItalic(f), isTrue);
    });
  });

  group('U8 safeText', () {
    test('U8-P1 Latin có regular ⇒ giữ nguyên chữ Việt', () {
      expect(PdfFontSet({FontSlot.regular: _regular}).safeText(ScriptFace.latin, const StyledSpan(''), 'Tiếng Việt'),
          'Tiếng Việt');
    });
    test('U8-P2 CJK thiếu font riêng, có regular ⇒ giữ nguyên (vẽ bằng regular)', () {
      expect(PdfFontSet({FontSlot.regular: _regular}).safeText(ScriptFace.chinese, const StyledSpan(''), '汉字'), '汉字');
    });
    test('U8-P3 không font nào ⇒ ký tự ngoài Latin-1 thành "?", giữ Latin-1', () {
      expect(PdfFontSet(const {}).safeText(ScriptFace.latin, const StyledSpan(''), 'Hà ở 河'), 'Hà ? ?');
    });
    test('U8-P4 không font nào, chuỗi rỗng ⇒ rỗng', () {
      expect(PdfFontSet(const {}).safeText(ScriptFace.latin, const StyledSpan(''), ''), '');
    });
    test('U8-P5 không font nào, toàn Latin-1 ⇒ giữ nguyên', () {
      expect(PdfFontSet(const {}).safeText(ScriptFace.latin, const StyledSpan(''), 'café'), 'café');
    });
  });

  group('U9 width', () {
    test('U9-P1 chuỗi có chữ ⇒ > 0', () {
      final s = PdfFontSet({FontSlot.regular: _regular});
      expect(s.width(ScriptFace.latin, const StyledSpan('', size: 12), 'Hello'), greaterThan(0));
    });
    test('U9-P2 chuỗi rỗng ⇒ 0', () {
      expect(PdfFontSet(const {}).width(ScriptFace.latin, const StyledSpan('', size: 12), ''), 0);
    });
    test('U9-P3 đo lại cùng chuỗi ⇒ cùng giá trị (cache)', () {
      final s = PdfFontSet(const {});
      final a = s.width(ScriptFace.latin, const StyledSpan('', size: 12), 'Hello');
      final b = s.width(ScriptFace.latin, const StyledSpan('', size: 12), 'Hello');
      expect(b, a);
      expect(s.width(ScriptFace.latin, const StyledSpan('', size: 12), 'Hello world'), greaterThan(a));
    });
  });
}
