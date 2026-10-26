// Gộp mọi file ARB của core + feature thành lib/l10n/app_<locale>.arb.
//
// Chạy trong app/:  dart run tool/merge_arb.dart [--strict]
//
// Nguồn: lib/core/l10n/*_<locale>.arb và lib/features/*/l10n/*_<locale>.arb
// (tên file: <prefix>_<locale>.arb). Luật:
//  - Mọi key (trừ @@locale và @key metadata) phải bắt đầu bằng `<prefix>_`.
//  - Trùng key giữa các file → lỗi, exit 1.
//  - Thiếu bản dịch so với template `en` → cảnh báo (`--strict`: lỗi, exit 1).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const locales = ['en', 'vi', 'zh', 'ja', 'ko', 'id'];
const templateLocale = 'en';

void main(List<String> args) {
  final strict = args.contains('--strict');
  final root = Directory.current.path;
  final sourceDirs =
      <Directory>[
          Directory('$root/lib/core/l10n'),
          ...Directory('$root/lib/features')
              .listSync()
              .whereType<Directory>()
              .map((d) => Directory('${d.path}/l10n')),
        ].where((d) => d.existsSync()).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final errors = <String>[];
  final warnings = <String>[];
  // locale -> key -> value ; key -> source file (cho báo trùng)
  final merged = {for (final l in locales) l: <String, dynamic>{}};
  final owners = {for (final l in locales) l: <String, String>{}};

  final fileRe = RegExp(r'^(.+)_([a-z]{2,3})\.arb$');
  for (final dir in sourceDirs) {
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final m = fileRe.firstMatch(name);
      if (m == null) continue;
      final prefix = m.group(1)!;
      final locale = m.group(2)!;
      final rel = file.path.substring(root.length + 1).replaceAll('\\', '/');
      if (!locales.contains(locale)) {
        errors.add('$rel: locale "$locale" không thuộc $locales');
        continue;
      }
      Map<String, dynamic> json;
      try {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (e) {
        errors.add('$rel: JSON lỗi: $e');
        continue;
      }
      final declared = json['@@locale'];
      if (declared != null && declared != locale) {
        errors.add('$rel: @@locale="$declared" khác tên file ($locale)');
      }
      for (final entry in json.entries) {
        final key = entry.key;
        if (key == '@@locale') continue;
        final bare = key.startsWith('@') ? key.substring(1) : key;
        if (!bare.startsWith('${prefix}_')) {
          errors.add('$rel: key "$key" phải bắt đầu bằng "${prefix}_"');
          continue;
        }
        final prev = owners[locale]![key];
        if (prev != null) {
          errors.add('$rel: key "$key" trùng với $prev');
          continue;
        }
        owners[locale]![key] = rel;
        merged[locale]![key] = entry.value;
      }
    }
  }

  final template = merged[templateLocale]!;
  final templateKeys = template.keys.where((k) => !k.startsWith('@')).toSet();
  for (final l in locales) {
    if (l == templateLocale) continue;
    final keys = merged[l]!.keys.where((k) => !k.startsWith('@')).toSet();
    final missing = templateKeys.difference(keys);
    final extra = keys.difference(templateKeys);
    if (missing.isNotEmpty) {
      warnings.add(
        '[$l] thiếu ${missing.length} key: ${(missing.toList()..sort()).join(', ')}',
      );
    }
    if (extra.isNotEmpty) {
      errors.add(
        '[$l] có key không có trong template en: ${(extra.toList()..sort()).join(', ')}',
      );
    }
  }

  for (final w in warnings) {
    stderr.writeln('WARN  $w');
  }
  for (final e in errors) {
    stderr.writeln('ERROR $e');
  }
  if (errors.isNotEmpty || (strict && warnings.isNotEmpty)) {
    stderr.writeln(
      'merge_arb: thất bại (${errors.length} lỗi, ${warnings.length} cảnh báo).',
    );
    exit(1);
  }

  final outDir = Directory('$root/lib/l10n')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final l in locales) {
    final entries = merged[l]!.entries.toList()
      ..sort((a, b) {
        String base(String k) => k.startsWith('@') ? k.substring(1) : k;
        final c = base(a.key).compareTo(base(b.key));
        if (c != 0) return c;
        return a.key.startsWith('@') ? 1 : -1;
      });
    final out = <String, dynamic>{
      '@@locale': l,
      for (final e in entries) e.key: e.value,
    };
    File('${outDir.path}/app_$l.arb')
        .writeAsStringSync('${encoder.convert(out)}\n');
  }
  print(
    'merge_arb: ${sourceDirs.length} thư mục nguồn, '
    '${templateKeys.length} key → lib/l10n/app_<locale>.arb '
    '(${warnings.length} cảnh báo).',
  );
}
