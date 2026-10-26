import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../text/line_wrap.dart';
import '../text/script_runs.dart';

/// Các font Noto đóng gói trong `assets/fonts/` (hợp đồng mục 5).
enum FontSlot {
  regular('assets/fonts/NotoSans-Regular.ttf'),
  bold('assets/fonts/NotoSans-Bold.ttf'),
  chinese('assets/fonts/NotoSansSC-Regular.ttf'),
  japanese('assets/fonts/NotoSansJP-Regular.ttf'),
  korean('assets/fonts/NotoSansKR-Regular.ttf');

  const FontSlot(this.assetPath);
  final String assetPath;

  static FontSlot forFace(ScriptFace face) => switch (face) {
        ScriptFace.latin => FontSlot.regular,
        ScriptFace.chinese => FontSlot.chinese,
        ScriptFace.japanese => FontSlot.japanese,
        ScriptFace.korean => FontSlot.korean,
      };
}

/// Nguồn byte font. Trả `null` khi không có (code rơi về font chuẩn).
abstract interface class FontSource {
  Future<Uint8List?> load(FontSlot slot);
}

/// Đọc từ `assets/fonts/`; thiếu file → `null` + log.
class AssetFontSource implements FontSource {
  const AssetFontSource();

  @override
  Future<Uint8List?> load(FontSlot slot) async {
    try {
      final data = await rootBundle.load(slot.assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (e) {
      debugPrint('convert: thiếu font ${slot.assetPath} ($e)');
      return null;
    }
  }
}

/// Đọc từ đường dẫn file (dùng trong test, vd. font Windows).
class FileFontSource implements FontSource {
  const FileFontSource(this.paths);
  final Map<FontSlot, String> paths;

  @override
  Future<Uint8List?> load(FontSlot slot) async {
    final path = paths[slot];
    if (path == null) return null;
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }
}

/// Không có font nào: luôn dùng font chuẩn của PDF.
class NoFontSource implements FontSource {
  const NoFontSource();
  @override
  Future<Uint8List?> load(FontSlot slot) async => null;
}

/// Nạp các font cần cho [scripts] (+ bold nếu [needBold]). Font CJK nặng chỉ nạp khi có chữ đó.
Future<Map<FontSlot, Uint8List>> loadFontBytes(
  FontSource source,
  Set<ScriptFace> scripts, {
  bool needBold = true,
}) async {
  final slots = <FontSlot>{
    FontSlot.regular,
    if (needBold) FontSlot.bold,
    for (final f in scripts) FontSlot.forFace(f),
  };
  final out = <FontSlot, Uint8List>{};
  for (final s in slots) {
    final b = await source.load(s);
    if (b != null) out[s] = b;
  }
  return out;
}

/// Tập font để vẽ PDF; đồng thời là [TextMeasurer]. Chạy được trong isolate (chỉ giữ byte).
class PdfFontSet implements TextMeasurer {
  PdfFontSet(this.bytes);

  final Map<FontSlot, Uint8List> bytes;
  final Map<String, PdfFont> _cache = {};
  final Map<String, double> _widthCache = {};
  final Set<FontSlot> _warned = {};

  /// Slot nào đang dùng font chuẩn (không có chữ ngoài Latin-1).
  bool usesStandard(FontSlot slot) => !bytes.containsKey(_effectiveSlot(slot));

  FontSlot _effectiveSlot(FontSlot slot) {
    if (bytes.containsKey(slot)) return slot;
    if (slot == FontSlot.bold) return FontSlot.regular;
    if (!_warned.contains(slot)) {
      _warned.add(slot);
      debugPrint('convert: không có font ${slot.assetPath}, dùng font thay thế');
    }
    return bytes.containsKey(FontSlot.regular) ? FontSlot.regular : slot;
  }

  PdfFont fontFor(ScriptFace face, StyledSpan style) {
    final size = style.size ?? 12;
    var slot = FontSlot.forFace(face);
    final wantBold = style.bold;
    if (face == ScriptFace.latin && wantBold && bytes.containsKey(FontSlot.bold)) {
      slot = FontSlot.bold;
    }
    final eff = _effectiveSlot(slot);
    final synthBold = wantBold && eff != FontSlot.bold;
    final key = '${eff.name}|$size|$synthBold|${style.italic}';
    return _cache[key] ??= _create(eff, size, synthBold, style.italic);
  }

  PdfFont _create(FontSlot slot, double size, bool bold, bool italic) {
    final styles = <PdfFontStyle>[
      if (bold) PdfFontStyle.bold,
      if (italic) PdfFontStyle.italic,
    ];
    final data = bytes[slot];
    if (data == null) {
      return PdfStandardFont(
        PdfFontFamily.helvetica,
        size,
        multiStyle: styles.isEmpty ? null : styles,
      );
    }
    return PdfTrueTypeFont(data, size, multiStyle: styles.isEmpty ? null : styles);
  }

  /// Chuỗi an toàn để vẽ: font chuẩn chỉ có Latin-1.
  String safeText(ScriptFace face, StyledSpan style, String text) {
    final slot = FontSlot.forFace(face);
    final eff = bytes.containsKey(slot) ? slot : (bytes.containsKey(FontSlot.regular) ? FontSlot.regular : slot);
    if (bytes.containsKey(eff)) return text;
    final b = StringBuffer();
    for (final c in text.runes) {
      b.write(c <= 0xFF ? String.fromCharCode(c) : '?');
    }
    return b.toString();
  }

  @override
  double width(ScriptFace face, StyledSpan style, String text) {
    if (text.isEmpty) return 0;
    final font = fontFor(face, style);
    final t = safeText(face, style, text);
    final key = '${identityHashCode(font)}|$t';
    return _widthCache[key] ??= font.measureString(t).width;
  }

  @override
  double spaceWidth(ScriptFace face, StyledSpan style) {
    final font = fontFor(face, style);
    return font.measureString('x x').width - font.measureString('xx').width;
  }
}
