// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/file_paths.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/file_paths/buoc-5-du-lieu-thu.md
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/utils/file_paths.dart';

/// Hệ thống file giả cho writeAtomically (chỉ dùng qua IOOverrides.createFile).
class _FakeFs {
  _FakeFs(this.parentDir, {required this.renameFails});
  final Directory parentDir;
  final Map<String, List<int>> files = {};
  final List<bool> renameFails;
  final log = <String>[];
}

class _FakeFile extends Fake implements File {
  _FakeFile(this.fs, this.path);
  final _FakeFs fs;
  @override
  final String path;

  @override
  Directory get parent => fs.parentDir;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    fs.log.add('write ${p.basename(path)}');
    fs.files[path] = bytes;
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    fs.log.add('rename ${p.basename(path)}');
    if (fs.renameFails.removeAt(0)) {
      throw FileSystemException('rename failed', newPath);
    }
    fs.files[newPath] = fs.files.remove(path)!;
    return _FakeFile(fs, newPath);
  }

  @override
  Future<bool> exists() async => fs.files.containsKey(path);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    fs.log.add('delete ${p.basename(path)}');
    fs.files.remove(path);
    return this;
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('wb_paths_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('U1 uniqueOutputPath', () {
    test('1.1 đuôi "pdf", chưa có gì ⇒ dir/report.pdf', () async {
      expect(await uniqueOutputPath(dir.path, 'report', 'pdf'), p.join(dir.path, 'report.pdf'));
    });
    test('1.2 đuôi rỗng ⇒ dir/report (không dấu chấm)', () async {
      expect(await uniqueOutputPath(dir.path, 'report', ''), p.join(dir.path, 'report'));
    });
    test('1.3 đuôi ".pdf" có dấu chấm ⇒ không nhân đôi dấu chấm', () async {
      expect(await uniqueOutputPath(dir.path, 'report', '.pdf'), p.join(dir.path, 'report.pdf'));
    });
    test('1.4 đã có FILE report.pdf ⇒ report (1).pdf', () async {
      File(p.join(dir.path, 'report.pdf')).writeAsStringSync('x');
      expect(await uniqueOutputPath(dir.path, 'report', 'pdf'), p.join(dir.path, 'report (1).pdf'));
    });
    test('1.5 đã có THƯ MỤC report, đuôi rỗng ⇒ report (1)', () async {
      Directory(p.join(dir.path, 'report')).createSync();
      expect(await uniqueOutputPath(dir.path, 'report', ''), p.join(dir.path, 'report (1)'));
    });
    test('1.6 (bảo mật) tên "../../evil" ⇒ kết quả nằm ngay trong dir', () async {
      final r = await uniqueOutputPath(dir.path, '../../evil', 'pdf');
      expect(p.dirname(r), dir.path, reason: r);
      expect(p.isWithin(dir.path, r), isTrue, reason: r);
    });
    test('1.7 (bảo mật) tên "..", đuôi rỗng ⇒ không trỏ ra thư mục cha', () async {
      final r = await uniqueOutputPath(dir.path, '..', '');
      expect(p.isWithin(dir.path, p.normalize(r)), isTrue, reason: r);
    });
  });

  group('U2 _capUtf8 (qua uniqueOutputPath)', () {
    test('2.1 tên ngắn ⇒ giữ nguyên', () async {
      final r = await uniqueOutputPath(dir.path, 'Báo cáo', 'pdf');
      expect(p.basename(r), 'Báo cáo.pdf');
    });
    test('2.2 tên tiếng Việt 300 byte ⇒ cắt ≤150 byte, là tiền tố, không vỡ ký tự', () async {
      final long = 'ệ' * 100; // 3 byte mỗi ký tự
      final r = await uniqueOutputPath(dir.path, long, 'pdf');
      final base = p.basenameWithoutExtension(r);
      expect(utf8.encode(base).length, lessThanOrEqualTo(150));
      expect(base, 'ệ' * 50);
      expect(long.startsWith(base), isTrue);
      expect(p.extension(r), '.pdf');
    });
  });

  group('U3 sanitizeFileName', () {
    test('3.1 ký tự cấm và ký tự điều khiển ⇒ "_"', () {
      expect(sanitizeFileName('a/b\\c:d*e?f"g<h>i|j\x01k'), 'a_b_c_d_e_f_g_h_i_j_k');
    });
    test('3.2 rỗng / toàn khoảng trắng ⇒ "untitled"', () {
      expect(sanitizeFileName(''), 'untitled');
      expect(sanitizeFileName('   '), 'untitled');
    });
    test('3.3 (bảo mật) "../../etc/passwd" ⇒ không còn dấu phân cách', () {
      final r = sanitizeFileName('../../etc/passwd');
      expect(r.contains('/') || r.contains('\\'), isFalse, reason: r);
      expect(r, '.._.._etc_passwd');
    });
  });

  group('U4 writeAtomically', () {
    test('4.1 file mới, thư mục cha chưa có ⇒ ghi đúng, tạo thư mục, không để .tmp', () async {
      final path = p.join(dir.path, 'sub', 'a.pdf');
      final f = await writeAtomically(path, [1, 2, 3]);
      expect(File('$path.tmp').existsSync(), isFalse);
      expect(f.path, path);
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
    });

    test('4.2 ghi .tmp lỗi (".tmp" là thư mục) ⇒ ném FileSystemException, không tạo đích', () async {
      final path = p.join(dir.path, 'w.pdf');
      Directory('$path.tmp').createSync();
      final r = await writeAtomically(path, [1]).then<Object?>((_) => 'ok', onError: (Object e) => e);
      expect(File(path).existsSync(), isFalse);
      expect(r, isA<FileSystemException>());
    });

    test('4.3 đích là thư mục (đổi tên 2 lần đều lỗi) ⇒ ném lỗi, xoá .tmp', () async {
      final path = p.join(dir.path, 'd.pdf');
      Directory(path).createSync();
      final r = await writeAtomically(path, [1]).then<Object?>((_) => 'ok', onError: (Object e) => e);
      expect(File('$path.tmp').existsSync(), isFalse);
      expect(Directory(path).existsSync(), isTrue);
      expect(r, isA<FileSystemException>());
    });

    Future<(Object?, _FakeFs)> runFake(List<bool> renameFails, {bool targetExists = false}) async {
      final fs = _FakeFs(dir, renameFails: renameFails);
      final path = p.join(dir.path, 'x.pdf');
      if (targetExists) fs.files[path] = [9];
      final r = await IOOverrides.runZoned(
        () => writeAtomically(path, [1, 2]).then<Object?>((f) => f.path, onError: (Object e) => e),
        createFile: (pth) => _FakeFile(fs, pth),
      );
      return (r, fs);
    }

    test('4.4 đổi tên lần 1 lỗi, đích đã có ⇒ xoá đích, đổi tên lần 2, trả file đích', () async {
      final (r, fs) = await runFake([true, false], targetExists: true);
      expect(fs.log, ['write x.pdf.tmp', 'rename x.pdf.tmp', 'delete x.pdf', 'rename x.pdf.tmp']);
      expect(fs.files[p.join(dir.path, 'x.pdf')], [1, 2]);
      expect(r, p.join(dir.path, 'x.pdf'));
    });

    test('4.5 đổi tên lần 1 lỗi, đích chưa có ⇒ không xoá, đổi tên lần 2, trả file đích', () async {
      final (r, fs) = await runFake([true, false]);
      expect(fs.log, ['write x.pdf.tmp', 'rename x.pdf.tmp', 'rename x.pdf.tmp']);
      expect(r, p.join(dir.path, 'x.pdf'));
    });

    test('4.6 đổi tên lần 1 lỗi, đích đã có, đổi tên lần 2 lỗi ⇒ xoá .tmp, ném lại lỗi', () async {
      final (r, fs) = await runFake([true, true], targetExists: true);
      expect(fs.log, [
        'write x.pdf.tmp',
        'rename x.pdf.tmp',
        'delete x.pdf',
        'rename x.pdf.tmp',
        'delete x.pdf.tmp',
      ]);
      expect(fs.files.containsKey(p.join(dir.path, 'x.pdf.tmp')), isFalse);
      expect(r, isA<FileSystemException>());
    });
  });
}
