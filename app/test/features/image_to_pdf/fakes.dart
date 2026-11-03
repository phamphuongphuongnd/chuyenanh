import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/permissions/camera_permission.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/image_to_pdf/image_to_pdf_providers.dart';
import 'package:pdf_office/features/image_to_pdf/image_to_pdf_routes.dart';
import 'package:pdf_office/features/image_to_pdf/services/camera_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/crop_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';
import 'package:pdf_office/features/image_to_pdf/services/photo_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/permissions/fake_camera_permission.dart';

/// PNG 2x2 hợp lệ cho ảnh xem trước giả.
final Uint8List tinyPng = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2)),
);

/// Trình chọn ảnh hệ thống giả: mỗi lần mở trả về lô kế tiếp trong [batches]
/// (hết lô → rỗng = huỷ). [prepareFile] trả đường dẫn đã "đổi" theo [converted].
class FakePhotoPicker implements PhotoPickerService {
  FakePhotoPicker([List<List<String>>? batches])
    : batches = batches ?? [];

  final List<List<String>> batches;
  Object? error;
  final List<int?> limits = [];
  final List<String> prepared = [];

  /// Đường dẫn gốc → đường dẫn sau khi đổi định dạng (`null` = không đọc được).
  final Map<String, String?> converted = {};

  int get calls => limits.length;

  @override
  Future<List<String>> pickImages({int? limit}) async {
    limits.add(limit);
    if (error != null) throw error!;
    return batches.isEmpty ? const [] : batches.removeAt(0);
  }

  @override
  Future<String?> prepareFile(String path, Directory workDir) async {
    prepared.add(path);
    return converted.containsKey(path) ? converted[path] : path;
  }
}

class FakeCamera implements CameraService {
  FakeCamera([this.path]);

  String? path;
  PermissionDenied? error;
  int calls = 0;

  @override
  Future<String?> capture() async {
    calls++;
    if (error != null) throw error!;
    return path;
  }
}

class FakeCrop implements CropService {
  String? result;
  final List<String> sources = [];

  @override
  Future<String?> crop(
    String sourcePath, {
    required String title,
    required Color toolbarColor,
  }) async {
    sources.add(sourcePath);
    return result;
  }
}

class FakeProcessor implements ImageProcessor {
  FakeProcessor({this.width = 400, this.height = 300, this.badPaths = const {}});

  final int width;
  final int height;
  final Set<String> badPaths;
  final List<(String, ops.ImageEdit, int)> previews = [];
  final List<(String, ops.ImageEdit)> bakes = [];

  @override
  Future<ops.ImageInfoLite?> probe(String path) async {
    if (badPaths.contains(path)) return null;
    return ops.ImageInfoLite(
      width: width,
      height: height,
      format: ops.ImageSourceFormat.jpeg,
      hasAlpha: false,
    );
  }

  @override
  Future<Uint8List> renderPreview(
    String path,
    ops.ImageEdit edit, {
    int maxSide = 1024,
  }) async {
    previews.add((path, edit, maxSide));
    return tinyPng;
  }

  @override
  Future<String> bake(
    String path,
    ops.ImageEdit edit, {
    required Directory outDir,
    required String name,
    int jpegQuality = 95,
  }) async {
    bakes.add((path, edit));
    return p.join(outDir.path, '$name.jpg');
  }
}

/// Engine giả: ghi một file PDF giả thật ra đĩa và nhớ tham số.
class FakeEngine implements ImageToPdfEngine {
  List<String>? imagePaths;
  ImageToPdfOptions? options;
  String? outputPath;
  AppError? error;

  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (error != null) throw error!;
    this.imagePaths = imagePaths;
    this.options = options;
    this.outputPath = outputPath;
    onProgress?.call(1);
    File(outputPath).writeAsBytesSync(List.filled(2048, 7));
    return ImageToPdfResult(
      outputPath: outputPath,
      pageCount: imagePaths.length,
    );
  }
}

/// Dựng app thử: router thật của feature + trang chủ giả ở `/`.
class Harness {
  Harness({
    FakePhotoPicker? picker,
    FakeCamera? camera,
    FakeCrop? crop,
    FakeProcessor? processor,
    FakeEngine? engine,
    FakeCameraPermission? cameraPermission,
    required this.tmp,
  }) : picker = picker ?? FakePhotoPicker(),
       camera = camera ?? FakeCamera(),
       cameraPermission = cameraPermission ?? FakeCameraPermission(),
       crop = crop ?? FakeCrop(),
       processor = processor ?? FakeProcessor(),
       engine = engine ?? FakeEngine();

  final Directory tmp;
  final FakePhotoPicker picker;
  final FakeCamera camera;
  final FakeCameraPermission cameraPermission;
  final FakeCrop crop;
  final FakeProcessor processor;
  final FakeEngine engine;
  late final GoRouter router;
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  int cleanerCalls = 0;

  Future<void> pump(
    WidgetTester tester, {
    String initialLocation = Routes.imageToPdf,
    Object? extra,
  }) async {
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Center(child: Text('HOME'))),
        ),
        ...imageToPdfRoutes,
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          photoPickerServiceProvider.overrideWithValue(picker),
          cameraServiceProvider.overrideWithValue(camera),
          cameraPermissionProvider.overrideWithValue(cameraPermission),
          cropServiceProvider.overrideWithValue(crop),
          imageProcessorProvider.overrideWithValue(processor),
          imageToPdfEngineProvider.overrideWithValue(engine),
          workDirProvider.overrideWithValue(
            () async => Directory(p.join(tmp.path, 'work')),
          ),
          workDirCleanerProvider.overrideWithValue(() async => cleanerCalls++),
          outputDirectoryProvider.overrideWith((ref) async => tmp.path),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(initialLocation, extra: extra));
    await tester.pumpAndSettle();
  }
}
