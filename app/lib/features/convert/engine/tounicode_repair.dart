// Sửa CMap ToUnicode lệch chuẩn để Syncfusion trích chữ được. PDF do MuPDF / PyMuPDF tạo (nhiều app
// Android) ghi đích bfrange / bfchar là code point thẳng 5–7 chữ số hex (vd. `<0f0d> <0f1a> <1df00>`)
// thay vì UTF-16BE 4 hoặc 8 chữ số; Syncfusion 35.x gặp đích > 4 chữ số trong bfrange thì cắt
// `substring(5, 8)` → RangeError, cả trang (và cả tài liệu) không trích được dù trình xem vẫn hiện.
// Chỉ sửa trong bộ nhớ của tài liệu đang mở để ĐỌC (không ghi lại file).
//
// Phải dùng lớp nội bộ của Syncfusion (từ điển trang / font, PdfStream) vì API công khai không cho
// đọc / thay luồng ToUnicode.
// ignore_for_file: implementation_imports
import 'dart:collection';
import 'dart:convert';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/pages/pdf_page.dart'
    show PdfPageHelper;
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_number.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_reference_holder.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_stream.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/interfaces/pdf_interface.dart';

final _bfrangeBlock = RegExp(r'(?:\d+\s+)?beginbfrange(.*?)endbfrange', dotAll: true);
final _bfcharBlock = RegExp(r'(?:\d+\s+)?beginbfchar(.*?)endbfchar', dotAll: true);
final _rangeEntry = RegExp(
  r'<([0-9A-Fa-f\s]*)>\s*<([0-9A-Fa-f\s]*)>\s*(?:<([0-9A-Fa-f\s]*)>|\[([^\]]*)\])',
);
final _charEntry = RegExp(r'<([0-9A-Fa-f\s]*)>\s*<([0-9A-Fa-f\s]*)>');
final _hexString = RegExp(r'<([0-9A-Fa-f\s]*)>');
final _space = RegExp(r'\s+');

/// Số mã tối đa của một bfrange được bung thành bfchar (chuẩn chỉ cho ≤ 256; chặn file dị dạng).
const _maxRangeSpan = 0x10000;

/// Số mục tối đa mỗi khối bfchar (giới hạn của chuẩn CMap).
const _bfcharChunk = 100;

String _strip(String hex) => hex.replaceAll(_space, '');

/// Đích hex của CMap → các code point. 5–7 chữ số = code point ghi thẳng (kiểu MuPDF); ≤ 4 = một
/// đơn vị UTF-16; bội của 4 = chuỗi UTF-16BE (cặp surrogate được ghép). `null` = không hiểu.
List<int>? _codePoints(String hex) {
  if (hex.isEmpty) return null;
  if (hex.length >= 5 && hex.length <= 7) {
    final cp = int.parse(hex, radix: 16);
    return (cp <= 0x10FFFF && (cp < 0xD800 || cp > 0xDFFF)) ? [cp] : null;
  }
  if (hex.length <= 4) return [int.parse(hex, radix: 16)];
  if (hex.length % 4 != 0) return null;
  final units = [
    for (var i = 0; i < hex.length; i += 4) int.parse(hex.substring(i, i + 4), radix: 16),
  ];
  return String.fromCharCodes(units).runes.toList();
}

/// Code point → hex UTF-16BE (mỗi đơn vị 4 chữ số).
String _utf16Hex(List<int> codePoints) => [
  for (final u in String.fromCharCodes(codePoints).codeUnits) u.toRadixString(16).padLeft(4, '0'),
].join();

bool _validCodePoint(int cp) => cp >= 0 && cp <= 0x10FFFF && (cp < 0xD800 || cp > 0xDFFF);

/// Viết lại CMap ToUnicode [cmap] theo dạng Syncfusion đọc đúng; `null` = không cần sửa.
///
/// - bfrange có đích nhiều đơn vị UTF-16 (code point ngoài BMP hoặc chữ ghép) → bung thành các mục
///   bfchar (Syncfusion đọc bfchar theo từng 4 chữ số nên ghép surrogate đúng); mã sau = đơn vị
///   cuối + k như chuẩn.
/// - Đích 5–7 chữ số trong bfchar / mảng bfrange → UTF-16BE chuẩn; phần tử mảng < 4 chữ số được đệm
///   0; mảng ngắn hơn khoảng mã → thu khoảng lại cho khớp.
String? repairToUnicodeCMap(String cmap) {
  var changed = false;
  final extraChars = <String>[];

  var out = cmap.replaceAllMapped(_bfrangeBlock, (block) {
    final kept = <String>[];
    for (final m in _rangeEntry.allMatches(block[1]!)) {
      final loHex = _strip(m[1]!);
      final hiHex = _strip(m[2]!);
      final lo = int.tryParse(loHex, radix: 16);
      final hi = int.tryParse(hiHex, radix: 16);
      if (lo == null || hi == null || hi < lo || hi - lo >= _maxRangeSpan) {
        kept.add(m[0]!);
        continue;
      }
      String code(int c) => c.toRadixString(16).padLeft(loHex.length, '0');
      if (m[3] != null) {
        final dst = _strip(m[3]!);
        final cps = dst.length > 4 ? _codePoints(dst) : null;
        if (cps == null) {
          kept.add('<$loHex> <$hiHex> <$dst>');
          continue;
        }
        changed = true;
        for (var c = lo; c <= hi; c++) {
          final shifted = [...cps];
          shifted[shifted.length - 1] += c - lo;
          if (!_validCodePoint(shifted.last)) continue;
          extraChars.add('<${code(c)}> <${_utf16Hex(shifted)}>');
        }
      } else {
        final items = <String>[];
        for (final e in _hexString.allMatches(m[4]!)) {
          final raw = _strip(e[1]!);
          final cps = _codePoints(raw);
          final norm = cps == null ? raw : _utf16Hex(cps);
          if (norm != raw) changed = true;
          items.add('<$norm>');
        }
        if (items.isEmpty) {
          changed = true;
          continue;
        }
        var top = hiHex;
        if (hi - lo + 1 > items.length) {
          changed = true;
          top = code(lo + items.length - 1);
        }
        kept.add('<$loHex> <$top> [${items.join(' ')}]');
      }
    }
    return kept.isEmpty ? '' : '${kept.length} beginbfrange\n${kept.join('\n')}\nendbfrange';
  });

  out = out.replaceAllMapped(_bfcharBlock, (block) {
    final entries = <String>[];
    for (final m in _charEntry.allMatches(block[1]!)) {
      final src = _strip(m[1]!);
      final dst = _strip(m[2]!);
      final cps = (dst.length >= 5 && dst.length <= 7) ? _codePoints(dst) : null;
      if (cps != null) changed = true;
      entries.add('<$src> <${cps == null ? dst : _utf16Hex(cps)}>');
    }
    return '${entries.length} beginbfchar\n${entries.join('\n')}\nendbfchar';
  });

  if (!changed) return null;
  if (extraChars.isNotEmpty) {
    final extra = StringBuffer();
    for (var i = 0; i < extraChars.length; i += _bfcharChunk) {
      final chunk = extraChars.sublist(i, (i + _bfcharChunk).clamp(0, extraChars.length));
      extra.write('${chunk.length} beginbfchar\n${chunk.join('\n')}\nendbfchar\n');
    }
    final at = out.indexOf('endcmap');
    out = at < 0 ? '$out\n$extra' : '${out.substring(0, at)}$extra${out.substring(at)}';
  }
  return out;
}

IPdfPrimitive? _deref(IPdfPrimitive? p) => p is PdfReferenceHolder ? p.object : p;

/// Sửa (trong bộ nhớ) CMap ToUnicode lệch chuẩn của mọi font trang [page] dùng: tài nguyên của trang,
/// của các nút cha (thừa kế) và của Form XObject lồng nhau. Trả số CMap đã sửa (0 = không có gì để
/// sửa). Chỉ dùng cho tài liệu mở để trích chữ — không lưu lại tài liệu sau khi sửa.
int repairPageToUnicode(sf.PdfPage page) {
  final seen = HashSet<Object>.identity();
  var repaired = 0;

  void visitResources(IPdfPrimitive? value, int depth) {
    final res = _deref(value);
    if (res is! PdfDictionary || depth > 16 || !seen.add(res)) return;
    final fonts = _deref(res['Font']);
    if (fonts is PdfDictionary) {
      for (final f in [...?fonts.items?.values]) {
        final font = _deref(f);
        if (font is! PdfDictionary) continue;
        final map = _deref(font['ToUnicode']);
        if (map is PdfStream && seen.add(map) && _repairStream(map)) repaired++;
      }
    }
    final xobjects = _deref(res['XObject']);
    if (xobjects is PdfDictionary) {
      for (final x in [...?xobjects.items?.values]) {
        final xo = _deref(x);
        if (xo is PdfDictionary && seen.add(xo)) visitResources(xo['Resources'], depth + 1);
      }
    }
  }

  IPdfPrimitive? node = PdfPageHelper.getHelper(page).dictionary;
  for (var depth = 0; node is PdfDictionary && depth < 32; depth++) {
    visitResources(node['Resources'], 0);
    node = _deref(node['Parent']);
  }
  return repaired;
}

/// Giải nén luồng CMap (như Syncfusion tự làm khi đọc) rồi thay bằng bản đã sửa nếu cần.
bool _repairStream(PdfStream stream) {
  stream.decompress();
  final data = stream.dataStream;
  if (data == null || data.isEmpty) return false;
  final fixed = repairToUnicodeCMap(latin1.decode(data));
  if (fixed == null) return false;
  final bytes = latin1.encode(fixed);
  stream.data = bytes;
  stream['Length'] = PdfNumber(bytes.length);
  stream.changed = false;
  return true;
}
