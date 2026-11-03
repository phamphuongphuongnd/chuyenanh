// Ngắt dòng thuần (không phụ thuộc Syncfusion): chuỗi có định dạng → token → các dòng.
// Phép đo chiều rộng đi qua [TextMeasurer] nên test được bằng đo giả.
import 'script_runs.dart';

/// Định dạng của một đoạn chữ.
class StyledSpan {
  const StyledSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.size,
    this.colorArgb,
    this.highlightArgb,
    this.rise = 0,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Point; null = cỡ chữ cơ sở của đoạn.
  final double? size;
  final int? colorArgb;
  final int? highlightArgb;

  /// 1 = chỉ số trên, -1 = chỉ số dưới, 0 = thường.
  final int rise;

  /// Hai span có cùng định dạng (bỏ qua nội dung chữ).
  bool sameStyle(StyledSpan o) =>
      bold == o.bold &&
      italic == o.italic &&
      underline == o.underline &&
      strike == o.strike &&
      size == o.size &&
      colorArgb == o.colorArgb &&
      highlightArgb == o.highlightArgb &&
      rise == o.rise;
}

/// Đo chữ. Cỡ chữ lấy từ `style.size` (đã được người gọi điền đủ).
abstract interface class TextMeasurer {
  double width(ScriptFace face, StyledSpan style, String text);

  /// Bề rộng một dấu cách (vì `measureString` của Syncfusion cắt dấu cách cuối chuỗi).
  double spaceWidth(ScriptFace face, StyledSpan style);
}

/// Một từ (hoặc một chữ CJK) kèm dấu cách theo sau.
class LayoutToken {
  const LayoutToken({
    required this.text,
    required this.face,
    required this.style,
    required this.width,
    this.spaces = 0,
    this.spaceWidth = 0,
    this.forceBreak = false,
  });

  final String text;
  final ScriptFace face;
  final StyledSpan style;

  /// Bề rộng phần chữ (không tính dấu cách cuối).
  final double width;

  /// Số dấu cách theo sau và bề rộng của một dấu cách.
  final int spaces;
  final double spaceWidth;

  /// Xuống dòng cứng sau token này (ký tự `\n`).
  final bool forceBreak;

  double get trailingSpace => spaces * spaceWidth;

  LayoutToken withSpaces(int n, double w) => LayoutToken(
        text: text,
        face: face,
        style: style,
        width: width,
        spaces: n,
        spaceWidth: w,
        forceBreak: forceBreak,
      );
}

/// Một đoạn chữ đã đặt trên dòng.
class PlacedRun {
  const PlacedRun({
    required this.text,
    required this.face,
    required this.style,
    required this.x,
    required this.width,
    this.spacesBefore = 0,
  });

  final String text;
  final ScriptFace face;
  final StyledSpan style;

  /// Toạ độ x so với mép trái của đoạn văn (đã gồm thụt dòng đầu), chưa tính căn lề.
  final double x;
  final double width;

  /// Số dấu cách giữa run trước trên cùng dòng và run này (run đầu dòng luôn 0) — chỗ giãn khi căn đều.
  final int spacesBefore;
}

class WrappedLine {
  const WrappedLine(this.runs, this.width, {this.hardBreak = false, this.wordSpacing = 0});
  final List<PlacedRun> runs;

  /// Toạ độ x cuối của chữ thấy được (không tính dấu cách cuối dòng).
  final double width;

  /// Dòng kết thúc bằng xuống dòng cứng (`\n`, tức `<w:br/>`) — không giãn khi căn đều.
  final bool hardBreak;

  /// Khoảng cộng thêm cho mỗi dấu cách U+0020 bên trong một run (point) — [justifyLine] đặt, người vẽ
  /// truyền vào `PdfStringFormat.wordSpacing`. 0 = không giãn.
  final double wordSpacing;

  String get text => runs.map((r) => r.text).join();
}

bool _isSpace(int c) => c == 0x20 || c == 0xA0 || c == 0x3000;

/// Tách các [spans] thành token. Từ dài hơn [maxWidth] bị cắt theo ký tự.
List<LayoutToken> tokenize(
  List<StyledSpan> spans,
  TextMeasurer measurer, {
  required double maxWidth,
}) {
  final tokens = <LayoutToken>[];

  LayoutToken textToken(ScriptFace face, StyledSpan span, String s) => LayoutToken(
        text: s,
        face: face,
        style: span,
        width: measurer.width(face, span, s),
      );

  for (final span in spans) {
    for (final run in splitScriptRuns(span.text)) {
      final chars = run.text.runes.toList();
      var i = 0;
      while (i < chars.length) {
        final c = chars[i];
        if (c == 0x0A) {
          tokens.add(LayoutToken(
            text: '',
            face: run.face,
            style: span,
            width: 0,
            forceBreak: true,
          ));
          i++;
        } else if (_isSpace(c)) {
          var n = 0;
          while (i < chars.length && _isSpace(chars[i])) {
            n++;
            i++;
          }
          final sw = measurer.spaceWidth(run.face, span);
          if (tokens.isNotEmpty &&
              !tokens.last.forceBreak &&
              tokens.last.text.isNotEmpty &&
              tokens.last.spaces == 0) {
            tokens.add(tokens.removeLast().withSpaces(n, sw));
          } else {
            tokens.add(LayoutToken(
              text: '',
              face: run.face,
              style: span,
              width: 0,
              spaces: n,
              spaceWidth: sw,
            ));
          }
        } else if (isBreakableCjk(c)) {
          tokens.add(textToken(run.face, span, String.fromCharCode(c)));
          i++;
        } else {
          final start = i;
          while (i < chars.length &&
              !_isSpace(chars[i]) &&
              chars[i] != 0x0A &&
              !isBreakableCjk(chars[i])) {
            i++;
          }
          final word = String.fromCharCodes(chars.sublist(start, i));
          final t = textToken(run.face, span, word);
          if (t.width <= maxWidth || maxWidth <= 0) {
            tokens.add(t);
          } else {
            for (final ch in word.runes) {
              tokens.add(textToken(run.face, span, String.fromCharCode(ch)));
            }
          }
        }
      }
    }
  }
  return tokens;
}

/// Xếp token vào dòng, chiều rộng tối đa [maxWidth]; dòng đầu thụt [firstLineIndent] (có thể âm).
/// Dòng nào cũng có ít nhất một token (token quá rộng vẫn đứng một mình). Token `forceBreak` luôn
/// kết thúc dòng. Đoạn rỗng vẫn cho đúng một dòng rỗng. Các từ liền nhau cùng định dạng gộp thành
/// một [PlacedRun] (có cả dấu cách giữa) để PDF trích chữ ra đúng khoảng trắng.
List<WrappedLine> wrapTokens(
  List<LayoutToken> tokens, {
  required double maxWidth,
  double firstLineIndent = 0,
}) {
  final lines = <WrappedLine>[];
  var runs = <PlacedRun>[];
  var x = firstLineIndent;
  var end = firstLineIndent;
  var start = firstLineIndent; // x đầu dòng hiện tại
  LayoutToken? prev; // token chữ ngay trước trên dòng, còn gộp được
  var gap = 0; // số dấu cách sau `prev` (gồm cả token chỉ có dấu cách)
  var gapWidth = 0.0;

  void flush({bool hard = false}) {
    lines.add(WrappedLine(runs, end, hardBreak: hard));
    runs = <PlacedRun>[];
    x = 0;
    end = 0;
    start = 0;
    prev = null;
  }

  for (final t in tokens) {
    if (t.text.isNotEmpty) {
      // Dòng chỉ mới có dấu cách đầu dòng mà từ không còn vừa ⇒ cũng xuống dòng.
      if ((runs.isNotEmpty || x > start + 0.01) && x + t.width > maxWidth + 0.01) flush();
      final p = prev;
      if (p != null && p.face == t.face && p.style.sameStyle(t.style)) {
        final last = runs.last;
        runs[runs.length - 1] = PlacedRun(
          text: '${last.text}${' ' * gap}${t.text}',
          face: last.face,
          style: last.style,
          x: last.x,
          width: last.width + gapWidth + t.width,
          spacesBefore: last.spacesBefore,
        );
      } else {
        runs.add(PlacedRun(
          text: t.text,
          face: t.face,
          style: t.style,
          x: x,
          width: t.width,
          spacesBefore: runs.isEmpty ? 0 : gap,
        ));
      }
      end = x + t.width;
      x = end + t.trailingSpace;
      prev = t;
      gap = t.spaces;
      gapWidth = t.trailingSpace;
    } else if (!t.forceBreak) {
      x += t.trailingSpace; // chỉ có dấu cách: vẫn giữ `prev` để gộp tiếp, cộng dồn khoảng trắng
      gap += t.spaces;
      gapWidth += t.trailingSpace;
    }
    if (t.forceBreak) flush(hard: true);
  }
  if (runs.isNotEmpty || lines.isEmpty) flush();
  return lines;
}

/// Số dấu cách U+0020 trong [text] — chỗ Syncfusion giãn theo `wordSpacing` (run gộp chỉ chứa U+0020).
int _innerSpaces(String text) {
  var n = 0;
  for (final c in text.codeUnits) {
    if (c == 0x20) n++;
  }
  return n;
}

/// Căn đều một dòng cho chạm [maxWidth]: phần dư chia đều cho mọi dấu cách giữa các từ (như Word giãn
/// mỗi dấu cách bằng nhau) — cả dấu cách bên trong run (vẽ bằng [WrappedLine.wordSpacing]) lẫn khoảng
/// giữa hai run (dời `x` của run sau). Dòng xuống dòng cứng, dòng không có dấu cách giữa từ, hoặc đã
/// đầy/tràn thì giữ nguyên. Người gọi tự bỏ qua dòng cuối của đoạn.
WrappedLine justifyLine(WrappedLine line, double maxWidth) {
  if (line.hardBreak || line.runs.isEmpty) return line;
  var spaces = 0;
  for (var i = 0; i < line.runs.length; i++) {
    final r = line.runs[i];
    spaces += _innerSpaces(r.text) + (i > 0 ? r.spacesBefore : 0);
  }
  final extra = maxWidth - line.width;
  if (spaces == 0 || extra <= 0.01) return line;
  final per = extra / spaces;
  var acc = 0; // số dấu cách đã giãn tính tới đầu run hiện tại
  final runs = <PlacedRun>[];
  for (var i = 0; i < line.runs.length; i++) {
    final r = line.runs[i];
    if (i > 0) acc += r.spacesBefore;
    final inner = _innerSpaces(r.text);
    runs.add(PlacedRun(
      text: r.text,
      face: r.face,
      style: r.style,
      x: r.x + acc * per,
      width: r.width + inner * per,
      spacesBefore: r.spacesBefore,
    ));
    acc += inner;
  }
  return WrappedLine(runs, line.width + extra, hardBreak: line.hardBreak, wordSpacing: per);
}
