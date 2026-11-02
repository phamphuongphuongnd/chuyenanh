// Kiểm thử hộp trắng A08 — data/office_io.dart. Mã bộ theo
// test-output/whitebox/office-viewer/office_io/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/office_viewer/data/office_io.dart';

Future<Object?> _run(Object? Function() body) =>
    runParsing(body).then((v) => v, onError: (Object e) => e);

FileSystemException _fse([int? code]) => FileSystemException(
  'x',
  'p',
  code == null ? null : OSError('os', code),
);

void main() {
  group('U1 runParsing (phần ngoài)', () {
    test('U1-P1 không lỗi ⇒ trả kết quả', () async {
      final r = await _run(() => 42);
      expect(r, 42);
    });
    test('U1-P2 Isolate.run ném lỗi không phải AppError ⇒ AppError', () async {
      final port = ReceivePort();
      try {
        final r = await _run(() => port.sendPort.hashCode + port.hashCode);
        // nhánh: catch (e) → AppError.from ⇒ Unknown
        expect(r, isA<Unknown>());
        expect(r, isA<AppError>());
      } finally {
        port.close();
      }
    });
    test('U1-P3 isolate ném AppError ⇒ rethrow nguyên AppError', () async {
      final r = await _run(() => throw const CorruptFile('x'));
      expect(r, isA<CorruptFile>());
    });
  });

  group('U2 closure trong Isolate.run', () {
    test('U2-P1 body bình thường ⇒ giá trị', () async {
      expect(await _run(() => 'ok'), 'ok');
    });
    test('U2-P2 lỗi lạ (StateError) ⇒ CorruptFile', () async {
      final r = await _run(() => throw StateError('boom'));
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, contains('boom'));
    });
    test('U2-P3 FileSystemException mã 13 ⇒ PermissionDenied', () async {
      final r = await _run(() => throw _fse(13));
      // nhánh: C3Đ N1S D1S D2S D3S → AppError.from
      expect(r, isA<PermissionDenied>());
    });
    test('U2-P4 FileSystemException không osError ⇒ AppError (CorruptFile "not found")', () async {
      final r = await _run(() => throw _fse());
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, 'not found');
      expect(r, isA<AppError>());
    });
    test('U2-P5 FileSystemException mã 2 ⇒ AppError (CorruptFile "not found")', () async {
      final r = await _run(() => throw _fse(2));
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, 'not found');
    });
    test('U2-P6 FileSystemException mã 3 ⇒ AppError (CorruptFile "not found")', () async {
      final r = await _run(() => throw _fse(3));
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, 'not found');
    });
    test('U2-P8 ném AppError (Cancelled) ⇒ giữ nguyên Cancelled', () async {
      final r = await _run(() => throw const Cancelled());
      expect(r, isA<Cancelled>());
    });
    test('U2-P9 OfficeFormatException ⇒ CorruptFile mang message', () async {
      final r = await _run(() => throw const rd.OfficeFormatException('bad zip'));
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, 'bad zip');
    });
    test('U2-P10 (bổ sung) FileSystemException mã 28 (ENOSPC) ⇒ NoSpace', () async {
      final r = await _run(() => throw _fse(28));
      expect(r, isA<NoSpace>());
    });
  });
}
