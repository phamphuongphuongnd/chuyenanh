import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'model.dart';

class Rel {
  const Rel(this.type, this.target, this.external);

  final String type;

  /// Absolute part name inside the zip (no leading '/'), or the raw URL when
  /// [external].
  final String target;
  final bool external;
}

/// OPC package access: lazily decompressed zip entries, cached XML and rels.
class OpcPackage {
  OpcPackage._(this._files);

  factory OpcPackage.open(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const PptxFormatException('Not a zip (pptx) file');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw PptxFormatException('Corrupt zip: $e');
    }
    final files = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.isFile) files[f.name.toLowerCase()] = f;
    }
    return OpcPackage._(files);
  }

  final Map<String, ArchiveFile> _files;
  final _xml = <String, XmlElement?>{};
  final _rels = <String, Map<String, Rel>>{};
  final _media = <String, Uint8List?>{};

  bool exists(String path) => _files.containsKey(path.toLowerCase());

  /// Raw bytes of a binary part (cached so shared images are decoded once).
  Uint8List? media(String path) =>
      _media.putIfAbsent(path, () => _files[path.toLowerCase()]?.readBytes());

  XmlElement? xml(String path) {
    if (_xml.containsKey(path)) return _xml[path];
    final raw = _files[path.toLowerCase()]?.readBytes();
    XmlElement? root;
    if (raw != null) {
      var text = utf8.decode(raw, allowMalformed: true);
      if (text.startsWith('﻿')) text = text.substring(1);
      try {
        root = XmlDocument.parse(text).rootElement;
      } on XmlException catch (e) {
        throw PptxFormatException('Malformed XML in $path: ${e.message}');
      }
    }
    _xml[path] = root;
    return root;
  }

  /// Relationships of [partPath] keyed by Id. '' means the package rels.
  Map<String, Rel> rels(String partPath) {
    return _rels.putIfAbsent(partPath, () {
      final slash = partPath.lastIndexOf('/');
      final dir = slash < 0 ? '' : partPath.substring(0, slash);
      final file = partPath.substring(slash + 1);
      final relsPath = dir.isEmpty
          ? '_rels/$file.rels'
          : '$dir/_rels/$file.rels';
      final root = xml(relsPath);
      final out = <String, Rel>{};
      if (root == null) return out;
      for (final r in root.childElements) {
        if (r.name.local != 'Relationship') continue;
        final id = r.getAttribute('Id');
        final target = r.getAttribute('Target');
        if (id == null || target == null) continue;
        final external = r.getAttribute('TargetMode') == 'External';
        out[id] = Rel(
          r.getAttribute('Type') ?? '',
          external ? target : resolvePath(dir, target),
          external,
        );
      }
      return out;
    });
  }

  static String resolvePath(String baseDir, String target) {
    var t = target;
    try {
      t = Uri.decodeFull(t);
    } catch (_) {}
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
