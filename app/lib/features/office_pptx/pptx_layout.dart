// Logic thuần (không widget) của bộ xem PPTX: quy đổi EMU → px, khung chữ, căn lề,
// bullet, bảng, crop ảnh, đường vẽ hình. Có test ở test/features/office_pptx/.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:pptx_reader/pptx_reader.dart';

/// 1 point = 12700 EMU. Canvas slide dùng đơn vị point (1 pt = 1 logical px trên canvas),
/// rồi `FittedBox` co lại theo màn hình — nên cỡ chữ (pt) dùng thẳng, không nhân hệ số.
const double kEmuPerPt = 12700;

double emuToPt(num emu) => emu / kEmuPerPt;

/// Kích thước canvas (pt) của một slide.
Size slideCanvasSize(PptxDeck deck) =>
    Size(emuToPt(deck.slideWidthEmu), emuToPt(deck.slideHeightEmu));

/// Khung hình theo pt (gốc trên-trái slide).
Rect rectOfFrame(PptxRect f) =>
    Rect.fromLTWH(emuToPt(f.x), emuToPt(f.y), emuToPt(f.cx), emuToPt(f.cy));

double rotationRadians(PptxShape s) => s.rotationDeg * math.pi / 180;

TextAlign textAlignOf(PptxAlign a) => switch (a) {
  PptxAlign.left => TextAlign.left,
  PptxAlign.center => TextAlign.center,
  PptxAlign.right => TextAlign.right,
  PptxAlign.justify => TextAlign.justify,
};

/// Vị trí khối chữ theo chiều dọc trong khung hình.
Alignment alignmentOfAnchor(PptxAnchor a) => switch (a) {
  PptxAnchor.top => Alignment.topCenter,
  PptxAnchor.middle => Alignment.center,
  PptxAnchor.bottom => Alignment.bottomCenter,
};

/// Lề trong của khung chữ (pt).
EdgeInsets insetsOf(PptxInsets i) => EdgeInsets.fromLTRB(
  emuToPt(i.left),
  emuToPt(i.top),
  emuToPt(i.right),
  emuToPt(i.bottom),
);

/// Chỉ số các slide được hiển thị (bỏ slide ẩn trừ khi [showHidden]).
List<int> visibleSlideIndexes(PptxDeck deck, {bool showHidden = false}) => [
  for (var i = 0; i < deck.slides.length; i++)
    if (showHidden || !deck.slides[i].hidden) i,
];

/// Hệ số `height` của TextStyle cho một đoạn. PowerPoint "single" ≈ 1.2 × cỡ chữ.
double lineHeightFactor(PptxParagraph p, double fontSizePt) {
  if (p.lineSpacingPt != null && fontSizePt > 0) {
    return p.lineSpacingPt! / fontSizePt;
  }
  if (p.lineSpacingPct != null) return p.lineSpacingPct! / 100 * 1.2;
  return 1.2;
}

/// Vùng đặt ảnh gốc (không crop) so với khung hiển thị [frame], sao cho phần giữ lại
/// khớp khung. [crop] là tỉ lệ cắt mỗi cạnh (có thể âm = đệm).
Rect cropImageRect(Size frame, PptxCrop? crop) {
  if (crop == null) return Offset.zero & frame;
  final keepW = 1 - crop.left - crop.right;
  final keepH = 1 - crop.top - crop.bottom;
  if (keepW <= 0.001 || keepH <= 0.001) return Offset.zero & frame;
  final fullW = frame.width / keepW;
  final fullH = frame.height / keepH;
  return Rect.fromLTWH(-crop.left * fullW, -crop.top * fullH, fullW, fullH);
}

// ---------------------------------------------------------------- bullet

/// Nhãn bullet/đánh số cho từng đoạn (null = không bullet). Đánh số liên tiếp theo cấp;
/// đoạn không đánh số cùng cấp hoặc sâu hơn làm đếm lại từ đầu.
List<String?> bulletLabels(List<PptxParagraph> paragraphs) {
  final counters = <int, int>{};
  final out = <String?>[];
  for (final p in paragraphs) {
    if (p.numbered) {
      counters.removeWhere((level, _) => level > p.level);
      final n = (counters[p.level] ?? 0) + 1;
      counters[p.level] = n;
      out.add(numberLabel(n, p.numberingScheme));
    } else {
      counters.removeWhere((level, _) => level >= p.level);
      out.add(bulletGlyph(p));
    }
  }
  return out;
}

final RegExp _schemeRe = RegExp(
  r'^(arabic|alphaLc|alphaUc|romanLc|romanUc)(Period|ParenR|ParenBoth|Plain)?',
);

/// "1." / "a)" / "(iv)" … theo `a:buAutoNum/@type`.
String numberLabel(int n, String? scheme) {
  final m = _schemeRe.firstMatch(scheme ?? 'arabicPeriod');
  final kind = m?.group(1) ?? 'arabic';
  final suffix = m?.group(2) ?? 'Period';
  final core = switch (kind) {
    'alphaLc' => alphaNumber(n),
    'alphaUc' => alphaNumber(n).toUpperCase(),
    'romanLc' => romanNumber(n).toLowerCase(),
    'romanUc' => romanNumber(n),
    _ => '$n',
  };
  return switch (suffix) {
    'ParenR' => '$core)',
    'ParenBoth' => '($core)',
    'Plain' => core,
    _ => '$core.',
  };
}

/// 1→a, 26→z, 27→aa …
String alphaNumber(int n) {
  var v = math.max(n, 1);
  final chars = <String>[];
  while (v > 0) {
    v -= 1;
    chars.add(String.fromCharCode(0x61 + v % 26));
    v ~/= 26;
  }
  return chars.reversed.join();
}

String romanNumber(int n) {
  const table = <(int, String)>[
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  var v = math.min(math.max(n, 1), 3999);
  final sb = StringBuffer();
  for (final (value, sym) in table) {
    while (v >= value) {
      sb.write(sym);
      v -= value;
    }
  }
  return sb.toString();
}

const Map<int, String> _symbolBullets = {
  0xA7: '▪',
  0x76: '❖',
  0xD8: '➢',
  0xFC: '✓',
  0x6C: '●',
  0x6E: '■',
  0x71: '❑',
  0x77: '◆',
  0xA8: '◻',
  0x9F: '•',
  0xB7: '•',
  0x6F: '○',
  0xE0: '→',
};

/// Ký tự bullet hiển thị được. Wingdings/Symbol (mã vùng riêng U+F0xx) đổi sang ký tự
/// Unicode gần nhất vì máy không có font đó.
String? bulletGlyph(PptxParagraph p) {
  final c = p.bulletChar;
  if (c == null || c.isEmpty) return null;
  final family = (p.bulletFontFamily ?? '').toLowerCase();
  final symbolFont =
      family.contains('wingdings') ||
      family.contains('symbol') ||
      family.contains('webdings');
  var code = c.runes.first;
  final privateUse = code >= 0xF000 && code <= 0xF0FF;
  if (privateUse) code -= 0xF000;
  if (symbolFont || privateUse) return _symbolBullets[code] ?? '•';
  return c;
}

// ---------------------------------------------------------------- bảng

/// Một ô bảng đã tính vị trí (pt, gốc tại góc trên-trái bảng), đã gộp ô.
class TableCellBox {
  const TableCellBox(this.row, this.col, this.rect, this.cell);
  final int row;
  final int col;
  final Rect rect;
  final PptxTableCell cell;
}

/// Bỏ các ô bị gộp (`hMerge`/`vMerge`), ô gốc phủ `gridSpan × rowSpan`.
List<TableCellBox> layoutTable(PptxTableShape t) {
  final colX = <double>[0];
  for (final w in t.columnWidthsEmu) {
    colX.add(colX.last + emuToPt(w));
  }
  final rowY = <double>[0];
  for (final r in t.rows) {
    rowY.add(rowY.last + emuToPt(r.heightEmu));
  }
  final cols = t.columnWidthsEmu.length;
  final out = <TableCellBox>[];
  for (var r = 0; r < t.rows.length; r++) {
    final cells = t.rows[r].cells;
    for (var c = 0; c < cells.length && c < cols; c++) {
      final cell = cells[c];
      if (cell.hMerge || cell.vMerge) continue;
      final int c2 = math.min(c + math.max(cell.gridSpan, 1), cols);
      final int r2 = math.min(r + math.max(cell.rowSpan, 1), t.rows.length);
      out.add(
        TableCellBox(
          r,
          c,
          Rect.fromLTRB(colX[c], rowY[r], colX[c2], rowY[r2]),
          cell,
        ),
      );
    }
  }
  return out;
}

Size tableSize(PptxTableShape t) => Size(
  t.columnWidthsEmu.fold<double>(0, (s, w) => s + emuToPt(w)),
  t.rows.fold<double>(0, (s, r) => s + emuToPt(r.heightEmu)),
);

// ---------------------------------------------------------------- đường vẽ

/// Đổi một `a:path` của hình tự vẽ sang [Path] co về [target].
Path customPathToFlutter(PptxCustomPath cp, Size target) {
  final sx = cp.widthEmu > 0 ? target.width / cp.widthEmu : 1.0;
  final sy = cp.heightEmu > 0 ? target.height / cp.heightEmu : 1.0;
  final path = Path();
  var cur = Offset.zero;
  var start = Offset.zero;
  for (final cmd in cp.commands) {
    final a = cmd.args;
    switch (cmd.kind) {
      case PptxPathOp.moveTo:
        if (a.length < 2) continue;
        cur = Offset(a[0] * sx, a[1] * sy);
        start = cur;
        path.moveTo(cur.dx, cur.dy);
      case PptxPathOp.lineTo:
        if (a.length < 2) continue;
        cur = Offset(a[0] * sx, a[1] * sy);
        path.lineTo(cur.dx, cur.dy);
      case PptxPathOp.cubicTo:
        if (a.length < 6) continue;
        path.cubicTo(
          a[0] * sx,
          a[1] * sy,
          a[2] * sx,
          a[3] * sy,
          a[4] * sx,
          a[5] * sy,
        );
        cur = Offset(a[4] * sx, a[5] * sy);
      case PptxPathOp.quadTo:
        if (a.length < 4) continue;
        path.quadraticBezierTo(a[0] * sx, a[1] * sy, a[2] * sx, a[3] * sy);
        cur = Offset(a[2] * sx, a[3] * sy);
      case PptxPathOp.arcTo:
        if (a.length < 4) continue;
        cur = _arcTo(path, cur, a[0] * sx, a[1] * sy, a[2], a[3]);
      case PptxPathOp.close:
        path.close();
        cur = start;
    }
  }
  return path;
}

/// `a:arcTo`: cung elip bán kính [wR]×[hR] bắt đầu tại điểm hiện tại, góc bắt đầu
/// [stDeg] (góc nhìn thấy, theo chiều kim đồng hồ), quét [swDeg]. Trả điểm cuối.
Offset _arcTo(
  Path path,
  Offset cur,
  double wR,
  double hR,
  double stDeg,
  double swDeg,
) {
  if (wR <= 0 || hR <= 0) return cur;
  double toParam(double deg) {
    final r = deg * math.pi / 180;
    return math.atan2(wR * math.sin(r), hR * math.cos(r));
  }

  final t0 = toParam(stDeg);
  final t1raw = toParam(stDeg + swDeg);
  var sweep = t1raw - t0;
  if (swDeg.abs() >= 360) {
    sweep = swDeg * math.pi / 180;
  } else {
    while (swDeg > 0 && sweep < 0) {
      sweep += 2 * math.pi;
    }
    while (swDeg < 0 && sweep > 0) {
      sweep -= 2 * math.pi;
    }
  }
  final t1 = t0 + sweep;
  final center = Offset(cur.dx - wR * math.cos(t0), cur.dy - hR * math.sin(t0));
  path.arcTo(
    Rect.fromCenter(center: center, width: wR * 2, height: hR * 2),
    t0,
    sweep,
    false,
  );
  return Offset(center.dx + wR * math.cos(t1), center.dy + hR * math.sin(t1));
}

/// Đường viền của hình preset trong khung [size]. Hình chưa hỗ trợ → chữ nhật.
Path presetPath(PptxGeometry g, String? presetName, Size size) {
  final w = size.width;
  final h = size.height;
  final path = Path();
  switch (g) {
    case PptxGeometry.rect:
      path.addRect(Offset.zero & size);
    case PptxGeometry.roundRect:
      final r = math.min(w, h) * 0.16667;
      path.addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
      );
    case PptxGeometry.ellipse:
      path.addOval(Offset.zero & size);
    case PptxGeometry.triangle:
      path
        ..moveTo(w / 2, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case PptxGeometry.line:
      path
        ..moveTo(0, 0)
        ..lineTo(w, h);
    case PptxGeometry.other:
      _extraPreset(path, presetName, size);
  }
  return path;
}

void _extraPreset(Path path, String? name, Size size) {
  final w = size.width;
  final h = size.height;
  switch (name) {
    case 'diamond':
      path
        ..moveTo(w / 2, 0)
        ..lineTo(w, h / 2)
        ..lineTo(w / 2, h)
        ..lineTo(0, h / 2)
        ..close();
    case 'rightArrow':
      _polygon(path, _rightArrow(w, h));
    case 'leftArrow':
      _polygon(path, [
        for (final p in _rightArrow(w, h)) Offset(w - p.dx, p.dy),
      ]);
    case 'downArrow':
      _polygon(path, [for (final p in _rightArrow(h, w)) Offset(p.dy, p.dx)]);
    case 'upArrow':
      _polygon(path, [
        for (final p in _rightArrow(h, w)) Offset(p.dy, h - p.dx),
      ]);
    case 'hexagon':
      final dx = math.min(w, h) * 0.25;
      path
        ..moveTo(dx, 0)
        ..lineTo(w - dx, 0)
        ..lineTo(w, h / 2)
        ..lineTo(w - dx, h)
        ..lineTo(dx, h)
        ..lineTo(0, h / 2)
        ..close();
    case 'parallelogram':
      final dx = math.min(w, h) * 0.25;
      path
        ..moveTo(dx, 0)
        ..lineTo(w, 0)
        ..lineTo(w - dx, h)
        ..lineTo(0, h)
        ..close();
    default:
      path.addRect(Offset.zero & size);
  }
}

void _polygon(Path path, List<Offset> pts) {
  path.moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();
}

List<Offset> _rightArrow(double w, double h) {
  final head = math.min(w, h) * 0.5;
  final shaftTop = h * 0.25;
  final shaftBottom = h * 0.75;
  return [
    Offset(0, shaftTop),
    Offset(w - head, shaftTop),
    Offset(w - head, 0),
    Offset(w, h / 2),
    Offset(w - head, h),
    Offset(w - head, shaftBottom),
    Offset(0, shaftBottom),
  ];
}
