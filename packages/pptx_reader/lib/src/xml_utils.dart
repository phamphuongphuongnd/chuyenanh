import 'package:xml/xml.dart';

/// Namespace-prefix-agnostic helpers: OOXML files use varying prefixes, so
/// elements are matched by local name only.
extension XmlLocal on XmlElement {
  XmlElement? child(String local) {
    for (final n in children) {
      if (n is XmlElement && n.name.local == local) return n;
    }
    return null;
  }

  Iterable<XmlElement> kids(String local) =>
      childElements.where((e) => e.name.local == local);

  /// Follows a chain of child local names.
  XmlElement? at(List<String> path) {
    XmlElement? e = this;
    for (final p in path) {
      e = e?.child(p);
      if (e == null) return null;
    }
    return e;
  }

  /// Unprefixed attribute (e.g. `type`, `idx`, `val`).
  String? attr(String local) {
    for (final a in attributes) {
      if (a.name.local == local && a.name.prefix == null) return a.value;
    }
    return null;
  }

  /// Prefixed attribute such as `r:embed` / `r:id` (any prefix).
  String? nsAttr(String local) {
    for (final a in attributes) {
      if (a.name.local == local && a.name.prefix != null) return a.value;
    }
    return null;
  }

  int? intAttr(String local) {
    final v = attr(local);
    if (v == null) return null;
    return int.tryParse(v) ?? double.tryParse(v)?.round();
  }

  double? doubleAttr(String local) {
    final v = attr(local);
    return v == null ? null : double.tryParse(v);
  }

  bool? boolAttr(String local) {
    final v = attr(local);
    if (v == null) return null;
    return v == '1' || v == 'true' || v == 'on';
  }
}
