import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Thrown when the input is not a readable .docx / .xlsx package.
class OfficeFormatException implements Exception {
  final String message;
  final Object? cause;
  const OfficeFormatException(this.message, [this.cause]);

  @override
  String toString() => cause == null
      ? 'OfficeFormatException: $message'
      : 'OfficeFormatException: $message ($cause)';
}

/// Runs [body] and converts any failure into [OfficeFormatException].
T guardFormat<T>(String what, T Function() body) {
  try {
    return body();
  } on OfficeFormatException {
    rethrow;
  } catch (e) {
    throw OfficeFormatException('Cannot read $what', e);
  }
}

/// A decoded OOXML (zip) package with path-normalised lookup.
class OoxmlPackage {
  final Map<String, ArchiveFile> _files = {};

  OoxmlPackage(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const OfficeFormatException('Not a zip (OOXML) package');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw OfficeFormatException('Corrupt zip package', e);
    }
    for (final f in archive.files) {
      if (f.isFile) _files[_norm(f.name)] = f;
    }
  }

  static String _norm(String p) {
    var s = p.replaceAll('\\', '/');
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    return s.toLowerCase();
  }

  bool has(String path) => _files.containsKey(_norm(path));

  Uint8List? bytes(String path) => _files[_norm(path)]?.content;

  XmlDocument? xml(String path) {
    final b = bytes(path);
    if (b == null) return null;
    return XmlDocument.parse(_decodeText(b));
  }

  /// Relationships of [partPath] (e.g. `word/document.xml`), keyed by Id.
  Map<String, Relationship> rels(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final dir = slash < 0 ? '' : partPath.substring(0, slash);
    final name = partPath.substring(slash + 1);
    final relPath = dir.isEmpty ? '_rels/$name.rels' : '$dir/_rels/$name.rels';
    final doc = xml(relPath);
    final out = <String, Relationship>{};
    if (doc == null) return out;
    for (final r in doc.descendantElements) {
      if (r.localName != 'Relationship') continue;
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id == null || target == null) continue;
      final external = r.getAttribute('TargetMode') == 'External';
      out[id] = Relationship(
        id: id,
        type: r.getAttribute('Type') ?? '',
        target: target,
        external: external,
        resolvedPath: external ? target : resolvePath(dir, target),
      );
    }
    return out;
  }

  /// Resolves [target] relative to directory [baseDir] inside the package.
  static String resolvePath(String baseDir, String target) {
    final t = Uri.decodeFull(target.replaceAll('\\', '/'));
    final parts = <String>[];
    if (!t.startsWith('/')) {
      parts.addAll(baseDir.split('/').where((s) => s.isNotEmpty));
    }
    for (final seg in t.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }
}

String _decodeText(Uint8List b) {
  // UTF-16 with BOM is legal for OOXML parts, though rare.
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    final codes = <int>[];
    for (var i = 2; i + 1 < b.length; i += 2) {
      codes.add(b[i] | (b[i + 1] << 8));
    }
    return String.fromCharCodes(codes);
  }
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    final codes = <int>[];
    for (var i = 2; i + 1 < b.length; i += 2) {
      codes.add((b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(codes);
  }
  var start = 0;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) start = 3;
  return utf8.decode(b.sublist(start), allowMalformed: true);
}

class Relationship {
  final String id;
  final String type;
  final String target;
  final bool external;

  /// Package path for internal targets; the raw target for external ones.
  final String resolvedPath;
  const Relationship({
    required this.id,
    required this.type,
    required this.target,
    required this.external,
    required this.resolvedPath,
  });
}

// ---------------------------------------------------------------------------
// XML helpers (namespace-agnostic: match on local names so Strict OOXML works)

extension XmlElementX on XmlElement {
  /// Attribute value by local name (ignores prefix).
  String? attr(String local) {
    for (final a in attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }

  XmlElement? child(String local) {
    for (final n in children) {
      if (n is XmlElement && n.localName == local) return n;
    }
    return null;
  }

  Iterable<XmlElement> childrenNamed(String local) =>
      childElements.where((e) => e.localName == local);

  /// First descendant with [local] name.
  XmlElement? descendant(String local) {
    for (final e in descendantElements) {
      if (e.localName == local) return e;
    }
    return null;
  }

  String? childVal(String local) => child(local)?.attr('val');
}

int? parseIntOrNull(String? s) {
  if (s == null) return null;
  return int.tryParse(s.trim()) ?? double.tryParse(s.trim())?.round();
}

double? parseDoubleOrNull(String? s) =>
    s == null ? null : double.tryParse(s.trim());

/// Parses `RRGGBB` / `AARRGGBB` hex into opaque ARGB. `auto` -> null.
int? parseHexColor(String? hex) {
  if (hex == null) return null;
  final h = hex.trim();
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
  if (h.length == 8) {
    final v = int.tryParse(h.substring(2), radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
  return null;
}

/// OOXML boolean (`1`, `true`, `on`; missing value means true).
bool ooxmlBool(String? v, {bool ifMissing = true}) {
  if (v == null) return ifMissing;
  final s = v.toLowerCase();
  return s == '1' || s == 'true' || s == 'on';
}
