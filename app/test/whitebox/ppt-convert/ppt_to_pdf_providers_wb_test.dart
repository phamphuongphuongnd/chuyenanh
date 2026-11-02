// Kiểm thử hộp trắng A14 — ppt_to_pdf_providers.dart (SystemPptxFilePicker.pickPresentation).
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_to_pdf_providers.dart';

final class _PF extends PlatformFile {
  _PF(this.uri);
  @override
  final Uri uri;
  @override
  String get name => uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  @override
  get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => null;
  @override
  Future<int?> length() async => null;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

class _Picker extends FilePickerPlatform {
  _Picker(this.result);
  final PlatformFile? result;
  FileType? type;
  List<String>? exts;
  int calls = 0;

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
  late FilePickerPlatform saved;
  setUp(() => saved = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = saved);

  test('U1.P1 chọn file cục bộ ⇒ trả đường dẫn (Android/khác: giữ nguyên), lọc pptx + ppt', () async {
    final f = Uri.file(r'C:\docs\Bao cao.pptx', windows: true);
    final picker = _Picker(_PF(f));
    FilePickerPlatform.instance = picker;
    final r = await const SystemPptxFilePicker().pickPresentation();
    expect(picker.calls, 1);
    expect(picker.type, FileType.custom);
    expect(picker.exts, ['pptx', 'ppt']);
    expect(r, f.toFilePath());
  });

  test('U1.P2 huỷ bộ chọn (file null) ⇒ null', () async {
    final picker = _Picker(null);
    FilePickerPlatform.instance = picker;
    final r = await const SystemPptxFilePicker().pickPresentation();
    expect(picker.calls, 1);
    expect(r, isNull);
  });

  test('U1.P3 file không có đường dẫn cục bộ (content://) ⇒ null', () async {
    final picker = _Picker(_PF(Uri.parse('content://media/x.pptx')));
    FilePickerPlatform.instance = picker;
    final r = await const SystemPptxFilePicker().pickPresentation();
    expect(picker.calls, 1);
    expect(r, isNull);
  });
}
