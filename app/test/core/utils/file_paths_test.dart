import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/utils/file_paths.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pdf_office_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('uniqueOutputPath', () {
    test('chưa có file → tên gốc', () async {
      expect(
        await uniqueOutputPath(dir.path, 'a', 'pdf'),
        p.join(dir.path, 'a.pdf'),
      );
      expect(
        await uniqueOutputPath(dir.path, 'a', '.pdf'),
        p.join(dir.path, 'a.pdf'),
      );
    });

    test('trùng → thêm (1), (2)', () async {
      await File(p.join(dir.path, 'a.pdf')).writeAsString('x');
      expect(
        await uniqueOutputPath(dir.path, 'a', 'pdf'),
        p.join(dir.path, 'a (1).pdf'),
      );
      await File(p.join(dir.path, 'a (1).pdf')).writeAsString('x');
      expect(
        await uniqueOutputPath(dir.path, 'a', 'pdf'),
        p.join(dir.path, 'a (2).pdf'),
      );
    });

    test('lọc ký tự cấm', () async {
      expect(
        await uniqueOutputPath(dir.path, 'a/b:c', 'pdf'),
        p.join(dir.path, 'a_b_c.pdf'),
      );
    });
  });

  test('sanitizeFileName', () {
    expect(sanitizeFileName('   '), 'untitled');
    expect(sanitizeFileName('A & B to PDF'), 'A & B to PDF');
    expect(sanitizeFileName('x?*<>|'), 'x_____');
  });

  group('writeAtomically', () {
    test('ghi file, không để lại .tmp, tạo thư mục cha', () async {
      final path = p.join(dir.path, 'sub', 'out.pdf');
      final f = await writeAtomically(path, [1, 2, 3]);
      expect(f.path, path);
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      expect(await File('$path.tmp').exists(), isFalse);
    });

    test('ghi đè file đã có', () async {
      final path = p.join(dir.path, 'out.txt');
      await File(path).writeAsString('old');
      await writeAtomically(path, 'new'.codeUnits);
      expect(await File(path).readAsString(), 'new');
    });
  });

  test('parentFolderName / baseNameWithoutExtension', () {
    expect(
      parentFolderName(p.join('storage', 'Download', 'a.pdf')),
      'Download',
    );
    expect(baseNameWithoutExtension('report.final.pdf'), 'report.final');
  });
}
