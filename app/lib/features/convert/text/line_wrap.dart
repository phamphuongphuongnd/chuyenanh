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
  });

  final String text;
  final ScriptFace face;
  final StyledSpan style;

  /// Toạ độ x so với mép trái của đoạn văn (đã gồm thụt dòng đầu), chưa tính căn lề.
  final double x;
  final double width;
}

class WrappedLine {
  const WrappedLine(this.runs, this.width);
  final List<PlacedRun> runs;

  /// Toạ độ x cuối của chữ thấy được (không tính dấu cách cuối dòng).
  final double width;

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
  LayoutToken? prev; // token chữ ngay trước trên dòng, còn gộp được

  void flush() {
    lines.add(WrappedLine(runs, end));
    runs = <PlacedRun>[];
    x = 0;
    end = 0;
    prev = null;
  }

  for (final t in tokens) {
    if (t.text.isNotEmpty) {
      if (runs.isNotEmpty && x + t.width > maxWidth + 0.01) flush();
      final p = prev;
      if (p != null && p.face == t.face && p.style.sameStyle(t.style)) {
        final last = runs.last;
        runs[runs.length - 1] = PlacedRun(
          text: '${last.text}${' ' * p.spaces}${t.text}',
          face: last.face,
          style: last.style,
          x: last.x,
          width: last.width + p.trailingSpace + t.width,
        );
      } else {
        runs.add(PlacedRun(text: t.text, face: t.face, style: t.style, x: x, width: t.width));
      }
      end = x + t.width;
      x = end + t.trailingSpace;
      prev = t;
    } else if (!t.forceBreak) {
      x += t.trailingSpace; // chỉ có dấu cách
      prev = null;
    }
    if (t.forceBreak) flush();
  }
  if (runs.isNotEmpty || lines.isEmpty) flush();
  return lines;
}
