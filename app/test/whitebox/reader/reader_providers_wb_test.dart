// Kiểm thử hộp trắng (A09 · reader) — reader_providers.dart (closure của pdfFilePickerProvider).
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/reader_providers/buoc-5-du-lieu-thu.md.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/reader/reader_providers.dart';

final class _File extends PlatformFile {
  _File(this.uri);
  @override
  final Uri uri;
  @override
  String get name => 'a.pdf';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Picker extends FilePickerPlatform {
  _Picker(this.result);
  final PlatformFile? result;
  int calls = 0;
  FileType? type;
  List<String>? exts;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    this.type = type;
    exts = allowedExtensions;
    return result;
  }
}

void main() {
  late FilePickerPlatform original;
  setUp(() => original = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = original);

  Future<String?> pick(_Picker picker) {
    FilePickerPlatform.instance = picker;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c.read(pdfFilePickerProvider)();
  }

  test('RV-1 chọn được file có đường dẫn ⇒ trả đường dẫn (Android/khác: giữ nguyên), lọc chỉ PDF', () async {
    final path = p.join(Directory.systemTemp.path, 'a.pdf');
    final picker = _Picker(_File(Uri.file(path)));
    final r = await pick(picker);
    expect(picker.calls, 1);
    expect(picker.type, FileType.custom);
    expect(picker.exts, ['pdf']);
    expect(r, path);
  });

  test('RV-2 người dùng huỷ (picker trả null) ⇒ null', () async {
    final picker = _Picker(null);
    final r = await pick(picker);
    expect(picker.calls, 1);
    expect(r, isNull);
  });

  test('RV-3 file không có đường dẫn cục bộ (uri không phải file:) ⇒ null', () async {
    final picker = _Picker(_File(Uri.parse('https://example.invalid/a.pdf')));
    final r = await pick(picker);
    expect(picker.calls, 1);
    expect(r, isNull);
  });
}
