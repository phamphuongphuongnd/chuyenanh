// Third-party license inventory (SPDX ids) for every package in the resolved
// dependency graph. Writes THIRD_PARTY_LICENSES.md at the repo root.
//
// Run in app/ (after `flutter pub get`):  dart run tool/license_report.dart
//
// Inputs: .dart_tool/package_config.json (package roots) and pubspec.lock
// (version, `dependency:` kind, source). No dependencies beyond dart:io/convert.
//
// Exit code 1 if a GPL/AGPL/LGPL or UNKNOWN license is found among packages
// that are not `direct dev` dependencies.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// The app itself — never listed.
const _selfPackage = 'pdf_office';

/// Our own workspace packages (repo `packages/`), not third-party.
const _ownPackages = {'office_reader', 'pptx_reader', 'pdf_layout', 'image_ops'};

const _ownLicense = 'LicenseRef-Proprietary';

/// License ids that block a release when found in a shipped package.
const _blockingIds = {'GPL', 'AGPL', 'LGPL', 'UNKNOWN'};

const _licenseFileNames = [
  'license',
  'license.md',
  'license.txt',
  'licence',
  'licence.md',
  'licence.txt',
  'copying',
  'copying.md',
  'copying.txt',
];

/// Classifies a license text into an SPDX-ish id.
///
/// Order matters: MPL-2.0 text itself mentions the GNU (Affero/Lesser) GPL,
/// and the LGPL/AGPL texts mention the GNU GPL, so the more specific checks
/// run first.
String classifyLicense(String text) {
  final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (t.contains('syncfusion') && t.contains('license')) {
    return 'LicenseRef-Syncfusion';
  }
  if (t.contains('mozilla public license')) return 'MPL-2.0';
  if (t.contains('gnu affero general public license')) return 'AGPL';
  if (t.contains('gnu lesser general public license') ||
      t.contains('gnu library general public license')) {
    return 'LGPL';
  }
  if (t.contains('gnu general public license')) return 'GPL';
  if (t.contains('apache license') && t.contains('version 2.0')) {
    return 'Apache-2.0';
  }
  if (t.contains('sil open font license')) return 'OFL-1.1';
  if (t.contains('redistribution and use in source and binary forms')) {
    final third = t.contains('neither the name') ||
        t.contains('may be used to endorse or promote');
    return third ? 'BSD-3-Clause' : 'BSD-2-Clause';
  }
  if (t.contains('permission is hereby granted, free of charge')) return 'MIT';
  return 'UNKNOWN';
}

class _LockEntry {
  _LockEntry(this.dependency, this.source, this.version);
  final String dependency;
  final String source;
  final String? version;
}

class _Row {
  _Row(this.name, this.version, this.dependency, this.license, this.display);
  final String name;
  final String version;
  final String dependency;
  final String license;
  final String display;
}

/// Minimal line parser for the `packages:` section of pubspec.lock.
Map<String, _LockEntry> _parseLock(String content) {
  final result = <String, _LockEntry>{};
  String? current;
  var dependency = '';
  var source = '';
  String? version;
  var inPackages = false;

  void flush() {
    if (current != null) {
      result[current!] = _LockEntry(dependency, source, version);
    }
    current = null;
    dependency = '';
    source = '';
    version = null;
  }

  String unquote(String v) => v.trim().replaceAll('"', '');

  for (final line in const LineSplitter().convert(content)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      flush();
      inPackages = line.startsWith('packages:');
      continue;
    }
    if (!inPackages) continue;
    final pkg = RegExp(r'^  ([A-Za-z0-9_]+):\s*$').firstMatch(line);
    if (pkg != null) {
      flush();
      current = pkg.group(1);
      continue;
    }
    final field = RegExp(r'^    (dependency|source|version):\s*(.*)$')
        .firstMatch(line);
    if (field != null) {
      final value = unquote(field.group(2)!);
      switch (field.group(1)) {
        case 'dependency':
          dependency = value;
        case 'source':
          source = value;
        case 'version':
          version = value;
      }
    }
  }
  flush();
  return result;
}

File? _findLicenseFile(Directory root) {
  if (!root.existsSync()) return null;
  final byName = <String, File>{};
  for (final e in root.listSync(followLinks: false)) {
    if (e is File) {
      byName[e.uri.pathSegments.last.toLowerCase()] = e;
    }
  }
  for (final n in _licenseFileNames) {
    final f = byName[n];
    if (f != null) return f;
  }
  return null;
}

String _readText(File f) {
  final bytes = f.readAsBytesSync();
  return utf8.decode(bytes, allowMalformed: true);
}

/// A license file with at least this many `-----`-separated notices is an
/// aggregate (e.g. sky_engine bundles every Flutter engine third-party notice).
const _aggregateMinSections = 10;

/// Row for an aggregate notice file: id `MULTIPLE`, unless some notice is
/// copyleft, in which case that copyleft id is reported (and blocks).
_Row _aggregateRow(
    String name, String version, String dependency, List<String> sections) {
  final counts = <String, int>{};
  for (final s in sections) {
    final id = classifyLicense(s);
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final copyleft = const ['AGPL', 'GPL', 'LGPL'].where(counts.containsKey);
  final known = counts.keys.where((k) => k != 'UNKNOWN').toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final other = counts['UNKNOWN'] ?? 0;
  final parts = [
    for (final k in known) '$k ×${counts[k]}',
    if (other > 0) 'unclassified ×$other',
  ];
  final id = copyleft.isNotEmpty ? copyleft.first : 'MULTIPLE';
  final noCopyleft = copyleft.isEmpty && !counts.containsKey('MPL-2.0')
      ? '; no GPL/LGPL/AGPL/MPL text'
      : '';
  return _Row(name, version, dependency, id,
      '$id — aggregate of ${sections.length} notices: ${parts.join(', ')}'
      '$noCopyleft');
}

/// Packages (among [roots]) whose pubspec.yaml lists [dep] as a dependency.
List<String> _dependentsOf(String dep, Map<String, Directory> roots) {
  final out = <String>[];
  final pattern = RegExp('^\\s+$dep:', multiLine: true);
  roots.forEach((name, dir) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (name != dep &&
        pubspec.existsSync() &&
        pattern.hasMatch(pubspec.readAsStringSync())) {
      out.add(name);
    }
  });
  out.sort();
  return out;
}

void main(List<String> args) {
  final appDir = Directory.current;
  final configFile = File('${appDir.path}/.dart_tool/package_config.json');
  final lockFile = File('${appDir.path}/pubspec.lock');
  if (!configFile.existsSync() || !lockFile.existsSync()) {
    stderr.writeln('Run in app/ after `flutter pub get` '
        '(.dart_tool/package_config.json and pubspec.lock required).');
    exit(2);
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final lock = _parseLock(lockFile.readAsStringSync());
  final configUri = configFile.absolute.uri;

  final roots = <String, Directory>{};
  for (final p in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    final name = p['name'] as String;
    var rootUri = p['rootUri'] as String;
    if (!rootUri.endsWith('/')) rootUri = '$rootUri/';
    roots[name] = Directory.fromUri(configUri.resolve(rootUri));
  }

  final rows = <_Row>[];
  final names = roots.keys.toList()..sort();
  for (final name in names) {
    if (name == _selfPackage) continue;
    final entry = lock[name];
    final dependency = entry?.dependency ?? 'unknown';
    final version = entry?.version ?? '(${entry?.source ?? 'not in lock'})';
    final licenseFile = _findLicenseFile(roots[name]!);

    if (_ownPackages.contains(name)) {
      rows.add(_Row(name, version, dependency, _ownLicense,
          'own code ($_ownLicense)'));
      continue;
    }
    if (licenseFile == null) {
      // Flutter SDK packages without their own license file are covered by
      // the Flutter SDK license (see the `flutter` / `sky_engine` rows).
      if (entry?.source == 'sdk') continue;
      rows.add(_Row(name, version, dependency, 'UNKNOWN',
          'UNKNOWN (no license file)'));
      continue;
    }
    final text = _readText(licenseFile);
    final sections = text
        .split(RegExp(r'^-{40,}\s*$', multiLine: true))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sections.length >= _aggregateMinSections) {
      rows.add(_aggregateRow(name, version, dependency, sections));
      continue;
    }
    final id = classifyLicense(text);
    rows.add(_Row(name, version, dependency, id, id));
  }

  // Summary counts.
  final counts = <String, int>{};
  for (final r in rows) {
    counts[r.license] = (counts[r.license] ?? 0) + 1;
  }
  final countKeys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });

  final copyleft =
      rows.where((r) => const {'GPL', 'AGPL', 'LGPL'}.contains(r.license));
  final blocking = rows
      .where((r) =>
          r.dependency != 'direct dev' && _blockingIds.contains(r.license))
      .toList();

  final b = StringBuffer()
    ..writeln('# Third-party licenses — Phiotron PDF')
    ..writeln()
    ..writeln('Generated by app/tool/license_report.dart — run '
        '`dart run tool/license_report.dart` in app/ after changing '
        'dependencies.')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| License | Packages |')
    ..writeln('|---|---|');
  for (final k in countKeys) {
    b.writeln('| $k | ${counts[k]} |');
  }
  b
    ..writeln('| **Total** | **${rows.length}** |')
    ..writeln()
    ..writeln('## Dart / Flutter packages (pub)')
    ..writeln()
    ..writeln('| Package | Version | Dependency | License |')
    ..writeln('|---|---|---|---|');
  for (final r in rows) {
    b.writeln('| ${r.name} | ${r.version} | ${r.dependency} | ${r.display} |');
  }
  b
    ..writeln()
    ..writeln('## Native / bundled (not from pub)')
    ..writeln()
    ..writeln('| Component | Platform | License |')
    ..writeln('|---|---|---|')
    ..writeln('| uCrop (via image_cropper) | Android | Apache-2.0, '
        'Copyright 2017 Yalantis |')
    ..writeln('| Google ML Kit | Android / iOS | Google APIs Terms of Service / '
        'ML Kit terms (proprietary, free) |')
    ..writeln('| Noto Sans, Noto Sans SC/JP/KR fonts | all | OFL-1.1 '
        '(app/assets/fonts/OFL-Noto.txt) |')
    ..writeln('| Be Vietnam Pro font | all | OFL-1.1 '
        '(app/assets/ui_fonts/OFL.txt) |')
    ..writeln('| Syncfusion Flutter packages | all | Syncfusion Community '
        'License (application submitted 30/10/2026, ticket #886739, pending '
        'approval) |')
    ..writeln();

  // Notes — only state what the data confirms.
  final notes = <String>[];
  if (copyleft.isEmpty) notes.add('No GPL/AGPL/LGPL packages.');
  final dbus = rows.where((r) => r.name == 'dbus').toList();
  if (dbus.isNotEmpty && dbus.first.license == 'MPL-2.0') {
    final dependents = _dependentsOf('dbus', roots);
    if (dependents.isNotEmpty &&
        dependents.every((d) => d.endsWith('_linux'))) {
      notes.add('dbus (MPL-2.0) is Linux-only (used only by '
          '${dependents.join(', ')}) and not shipped in the Android/iOS app.');
    }
  }
  if (notes.isNotEmpty) {
    b
      ..writeln('## Notes')
      ..writeln()
      ..writeln(notes.join(' '));
  }

  final outFile = File('${appDir.parent.path}/THIRD_PARTY_LICENSES.md');
  outFile.writeAsStringSync(b.toString());
  print('Wrote ${outFile.path} (${rows.length} packages).');
  for (final k in countKeys) {
    print('  $k: ${counts[k]}');
  }

  if (blocking.isNotEmpty) {
    stderr.writeln('Blocking licenses among non-dev packages:');
    for (final r in blocking) {
      stderr.writeln('  ${r.name} ${r.version} (${r.dependency}): ${r.display}');
    }
    exit(1);
  }
}
