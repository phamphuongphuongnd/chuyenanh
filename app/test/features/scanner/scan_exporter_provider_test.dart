import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/image_to_pdf/image_to_pdf_providers.dart';
import 'package:pdf_office/features/scanner/export/scan_export_providers.dart';
import 'package:pdf_office/features/scanner/scanner_providers.dart';

class _NoPdf implements ImageToPdfEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoOcr implements OcrEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'scanExporterProvider đọc bằng ref.read (không ai watch) vẫn dựng xong, '
    'dù chờ thư mục lưu/thư mục tạm bất đồng bộ',
    () async {
      final dir = Directory.systemTemp.createTempSync('scan_prov_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final c = ProviderContainer(
        overrides: [
          imageToPdfEngineProvider.overrideWithValue(_NoPdf()),
          ocrEngineProvider.overrideWithValue(_NoOcr()),
          outputDirectoryProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return dir.path;
          }),
          scanTempDirProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return '${dir.path}/tmp';
          }),
        ],
      );
      addTearDown(c.dispose);

      final exporter = await c.read(scanExporterProvider.future);

      expect(exporter.outputDir, dir.path);
      expect(exporter.tempDir, '${dir.path}/tmp');
    },
  );
}
