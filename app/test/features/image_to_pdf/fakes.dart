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
import 'package:pdf_office/features/image_to_pdf/services/gallery_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG 1x1 hợp lệ cho ảnh thu nhỏ / xem trước giả.
final Uint8List tinyPng = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2)),
);

class FakeGallery implements GalleryService {
  FakeGallery({
    this.access = GalleryAccess.granted,
    this.count = 6,
    this.albumList,
  });

  GalleryAccess access;
  final int count;
  final List<GalleryAlbum>? albumList;
  int requestCount = 0;
  int openSettingsCount = 0;
  final List<String> resolved = [];

  @override
  Future<GalleryAccess> requestAccess() async {
    requestCount++;
    return access;
  }

  @override
  Future<List<GalleryAlbum>> albums() async =>
      albumList ?? [GalleryAlbum(id: 'all', name: 'Recent', count: count)];

  @override
  Future<List<GalleryAsset>> assets(
    GalleryAlbum album, {
    required int page,
    required int pageSize,
  }) async {
    if (page > 0) return const [];
    return [
      for (var i = 0; i < count; i++)
        GalleryAsset(id: '${album.id}_$i', width: 400, height: 300),
    ];
  }

  @override
  Future<Uint8List?> thumbnail(GalleryAsset asset, {int size = 256}) async =>
      tinyPng;

  @override
  Future<String?> resolveFile(GalleryAsset asset, Directory workDir) async {
    resolved.add(asset.id);
    return '/fake/${asset.id}.jpg';
  }

  @override
  Future<void> openSettings() async => openSettingsCount++;
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
    FakeGallery? gallery,
    FakeCamera? camera,
    FakeCrop? crop,
    FakeProcessor? processor,
    FakeEngine? engine,
    required this.tmp,
  }) : gallery = gallery ?? FakeGallery(),
       camera = camera ?? FakeCamera(),
       crop = crop ?? FakeCrop(),
       processor = processor ?? FakeProcessor(),
       engine = engine ?? FakeEngine();

  final Directory tmp;
  final FakeGallery gallery;
  final FakeCamera camera;
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
          galleryServiceProvider.overrideWithValue(gallery),
          cameraServiceProvider.overrideWithValue(camera),
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
