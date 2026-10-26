import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/engines/pdf/pdf_security.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:pdf_office/features/reader/reader_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine giả: ghi lại lời gọi, trả kết quả ngay, không đụng Syncfusion / isolate.
class FakeToolsEngine implements PdfToolsEngine {
  FakeToolsEngine({Map<String, int>? pageCounts, Map<String, String>? passwords})
    : pageCounts = pageCounts ?? {},
      requiredPasswords = passwords ?? {};

  final Map<String, int> pageCounts;

  /// path → mật khẩu đúng (file khoá).
  final Map<String, String> requiredPasswords;

  final List<Map<String, Object?>> merges = [];
  final List<Map<String, Object?>> splits = [];
  final List<Map<String, Object?>> organizes = [];
  final List<Map<String, Object?>> watermarks = [];
  final List<Map<String, Object?>> blanks = [];

  @override
  Future<int> pageCount(String inputPath, {String? password}) async {
    final need = requiredPasswords[inputPath];
    if (need != null) {
      if (password == null) throw const PasswordRequired();
      if (password != need) throw const WrongPassword();
    }
    final n = pageCounts[inputPath];
    if (n == null) throw const CorruptFile('missing');
    return n;
  }

  @override
  Future<String> merge(
    List<String> inputPaths,
    String outputPath, {
    Map<String, String> passwords = const {},
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    merges.add({'inputs': inputPaths, 'out': outputPath, 'passwords': passwords});
    onProgress?.call(1);
    return outputPath;
  }

  @override
  Future<List<String>> split(
    String inputPath,
    SplitMode mode,
    String outputDir,
    String baseName, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    splits.add({
      'input': inputPath,
      'mode': mode,
      'dir': outputDir,
      'base': baseName,
      'password': password,
    });
    return ['$outputDir/$baseName (1).pdf', '$outputDir/$baseName (2).pdf'];
  }

  @override
  Future<String> organize(
    String inputPath,
    List<PageOp> pages,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    organizes.add({
      'input': inputPath,
      'ops': pages,
      'out': outputPath,
      'password': password,
    });
    return outputPath;
  }

  @override
  Future<String> watermark(
    String inputPath,
    WatermarkSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    watermarks.add({'input': inputPath, 'spec': spec, 'out': outputPath});
    return outputPath;
  }

  @override
  Future<String> createBlank(
    BlankDocSpec spec,
    String outputPath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    blanks.add({'spec': spec, 'out': outputPath});
    return outputPath;
  }
}

class FakePicker implements PdfFilePicker {
  FakePicker({this.pdfs = const [], this.image});

  List<String> pdfs;
  Uint8List? image;
  int pdfCalls = 0;
  bool? lastMultiple;

  @override
  Future<List<String>> pickPdfs({bool multiple = false}) async {
    pdfCalls++;
    lastMultiple = multiple;
    return pdfs;
  }

  @override
  Future<Uint8List?> pickImageBytes() async => image;
}

/// Bảo mật giả: "mã hoá" = thêm tiền tố, để test kiểm được luồng mà không cần Syncfusion.
class FakeSecurity implements PdfSecurityEngine {
  FakeSecurity({this.encrypted = false, this.password = 'secret'});

  bool encrypted;
  String password;
  final List<String> encryptCalls = [];

  @override
  Future<bool> isEncrypted(Uint8List bytes) async => encrypted;

  @override
  Future<Uint8List> decrypt(Uint8List bytes, String pw) async {
    if (pw != password) throw const WrongPassword();
    return Uint8List.fromList([...'PLAIN:'.codeUnits, ...bytes]);
  }

  @override
  Future<Uint8List> encrypt(
    Uint8List bytes,
    String userPassword, {
    String? ownerPassword,
  }) async {
    encryptCalls.add(userPassword);
    return Uint8List.fromList([...'LOCKED:'.codeUnits, ...bytes]);
  }
}

class FakeRender implements PdfRenderEngine {
  FakeRender(this.png);
  final Uint8List png;
  int opened = 0;
  int closed = 0;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    opened++;
    return _Doc(this);
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => openFile('');
}

class _Doc implements PdfRenderDocument {
  _Doc(this.owner);
  final FakeRender owner;

  @override
  int get pageCount => 99;
  @override
  Future<PdfPageSize> pageSize(int pageIndex) async =>
      const PdfPageSize(595, 842);
  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async => owner.png;
  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async =>
      owner.png;
  @override
  Future<void> close() async => owner.closed++;
}

/// Dựng [child] trong MaterialApp có l10n (tiếng Anh) + ProviderScope với bản giả.
Future<ProviderContainer> pumpTool(
  WidgetTester tester,
  Widget child, {
  FakeToolsEngine? engine,
  FakePicker? picker,
  FakeSecurity? security,
  FakeRender? render,
  required Directory outDir,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        outputDirectoryProvider.overrideWith((ref) async => outDir.path),
        if (engine != null) pdfToolsEngineProvider.overrideWithValue(engine),
        if (picker != null) pdfFilePickerProvider.overrideWithValue(picker),
        if (security != null) pdfSecurityProvider.overrideWithValue(security),
        if (render != null) pdfRenderEngineProvider.overrideWithValue(render),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// Cho phép I/O thật (File, sqlite) chạy xong rồi dựng lại khung hình. Mỗi lần `await` I/O
/// trong code cần một vòng (chờ thật + pump) nên mặc định chạy nhiều vòng.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Như [settle] nhưng dừng ngay khi [finder] xuất hiện (tối đa ~3 giây).
Future<void> settleUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}
