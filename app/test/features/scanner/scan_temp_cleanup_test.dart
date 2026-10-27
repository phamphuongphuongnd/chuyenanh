import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/scanner/capture/scan_temp_cleanup.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('scan_cleanup_'));
  tearDown(() => temp.deleteSync(recursive: true));

  File make(String rel, {required Duration age}) {
    final f = File(p.join(temp.path, rel))..createSync(recursive: true);
    f.writeAsStringSync('x');
    f.setLastModifiedSync(DateTime.now().subtract(age));
    return f;
  }

  test('xoá ảnh quét/ảnh cắt cũ, giữ ảnh mới và file không liên quan', () async {
    final oldPage = make('scan_pages/p1_0.jpg', age: const Duration(days: 2));
    final newPage = make('scan_pages/p2_0.jpg', age: const Duration(minutes: 5));
    final oldCrop = make('crop_1.jpg', age: const Duration(hours: 20));
    final newCrop = make('crop_2.jpg', age: const Duration(minutes: 1));
    final other = make('other.txt', age: const Duration(days: 30));

    final removed = await cleanupStaleScanFiles(temp);

    expect(removed, 2);
    expect(oldPage.existsSync(), isFalse);
    expect(oldCrop.existsSync(), isFalse);
    expect(newPage.existsSync(), isTrue);
    expect(newCrop.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
  });

  test('thư mục tạm không có gì → 0, không ném lỗi', () async {
    expect(await cleanupStaleScanFiles(temp), 0);
  });
}
