import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/reader/reader_viewer.dart';
import 'package:pdf_office/features/reader/screens/pdf_reader_screen.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Controller giả: ghi lại lệnh thay vì gửi cho plugin native.
class _FakeController extends PdfViewerController {
  final List<int> jumps = [];
  final List<String> searches = [];
  int next = 0, previous = 0;

  @override
  void jumpToPage(int pageNumber) => jumps.add(pageNumber);

  @override
  void nextPage() => next++;

  @override
  void previousPage() => previous++;

  @override
  PdfTextSearchResult searchText(
    String searchText, {
    sf.TextSearchOption? searchOption,
  }) {
    searches.add(searchText);
    return PdfTextSearchResult();
  }
}

class _FakeShortcut extends ShortcutService {
  _FakeShortcut({this.supported = true});
  final bool supported;
  final List<(String, String)> requests = [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> requestPinShortcut({
    required String path,
    required String label,
  }) async {
    requests.add((path, label));
    return true;
  }
}

/// Viewer giả: báo "đã tải" (hoặc "lỗi") ngay sau khung hình đầu.
class _FakeViewer extends StatefulWidget {
  const _FakeViewer({required this.config, required this.failWithoutBytes});
  final ReaderViewerConfig config;
  final bool failWithoutBytes;

  @override
  State<_FakeViewer> createState() => _FakeViewerState();
}

class _FakeViewerState extends State<_FakeViewer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = widget.config;
      if (widget.failWithoutBytes && c.bytes == null) {
        c.onLoadFailed('needs password');
      } else {
        c.onLoaded(10, const []);
        c.onPageChanged(c.initialPage);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Container(key: const Key('fake_viewer'), color: Colors.white);
}

Future<Uint8List> _pdfBytes({String? password}) async {
  final doc = sf.PdfDocument();
  doc.pages.add();
  if (password != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

/// testWidgets + dọn timer của drift stream (tắt cây widget rồi bơm thêm thời gian).
void readerTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _FakeController controller;
  late List<ReaderViewerConfig> configs;
  late List<(Uint8List, String)> printed;
  late _FakeShortcut shortcut;
  var failWithoutBytes = false;
  Object? pdfToImageExtra;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('reader_screen_');
    db = AppDatabase(NativeDatabase.memory());
    controller = _FakeController();
    configs = [];
    printed = [];
    shortcut = _FakeShortcut();
    failWithoutBytes = false;
    pdfToImageExtra = null;
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<String> makePdf({String? password, String name = 'bao cao.pdf'}) async {
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(await _pdfBytes(password: password));
    return file.path;
  }

  /// I/O thật phải chạy ngoài FakeAsync của testWidgets.
  Future<String> mk(WidgetTester t, {String? password}) async =>
      (await t.runAsync(() => makePdf(password: password)))!;

  /// Cho các Future dùng I/O thật (đọc file, sqlite) chạy xong rồi dựng lại khung hình.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpReader(WidgetTester t, OpenFileArgs args) async {
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, _) => PdfReaderScreen(args: args),
        ),
        GoRoute(
          path: Routes.pdfToImage,
          builder: (_, state) {
            pdfToImageExtra = state.extra;
            return const Scaffold(body: Text('PDF TO IMAGE SCREEN'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          readerControllerFactoryProvider.overrideWithValue(() => controller),
          shortcutServiceProvider.overrideWithValue(shortcut),
          pdfPrinterProvider.overrideWithValue(
            (bytes, name) async => printed.add((bytes, name)),
          ),
          readerViewerBuilderProvider.overrideWithValue((context, config) {
            configs.add(config);
            return _FakeViewer(
              config: config,
              failWithoutBytes: failWithoutBytes,
            );
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await settle(t);
  }

  readerTest('mo file: hien ten file, thanh trang 1 / 10', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    expect(find.text('bao cao.pdf'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.byKey(const Key('fake_viewer')), findsOneWidget);
    expect(configs.last.bytes, isNull); // PDF thuong: mo thang tu file
    expect(configs.last.path, path);
  });

  readerTest('initialPage 0-based -> viewer nhan trang 1-based', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path, initialPage: 2));
    expect(configs.last.initialPage, 3);
    expect(find.text('3 / 10'), findsOneWidget);
  });

  readerTest('nhap so trang de nhay: goi jumpToPage dung so', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_pageIndicator')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '7');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(controller.jumps, [7]);

    // Trang vuot tong so: khong nhay.
    await t.tap(find.byKey(const Key('reader_pageIndicator')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '11');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(controller.jumps, [7]);
    await t.tap(find.text('CANCEL'));
    await t.pumpAndSettle();

    await t.tap(find.byIcon(Icons.chevron_right));
    await t.tap(find.byIcon(Icons.chevron_left));
    expect(controller.next, 1);
    expect(controller.previous, 0); // trang 1: nut truoc bi khoa
  });

  readerTest('bookmark trang: luu vao DB (page 0-based), bam lai thi bo', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path, initialPage: 4));
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await t.tap(find.byKey(const Key('reader_bookmarkButton')));
    await settle(t);
    var rows = await t.runAsync(() => db.bookmarksDao.getForPath(path));
    expect(rows!.map((b) => b.page), [4]);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('Bookmark added'), findsOneWidget);

    await t.tap(find.byKey(const Key('reader_bookmarkButton')));
    await settle(t);
    rows = await t.runAsync(() => db.bookmarksDao.getForPath(path));
    expect(rows, isEmpty);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  readerTest('danh sach bookmark: hien trang va cho nhay toi trang do', (t) async {
    final path = await mk(t);
    await t.runAsync(() async {
      await db.bookmarksDao.add(path, 5);
      await db.bookmarksDao.add(path, wholeDocumentPage);
    });
    await pumpReader(t, OpenFileArgs(path));

    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    await t.tap(find.text('Bookmarks'));
    await settle(t);
    expect(find.text('Page 6'), findsOneWidget);
    expect(find.text('Whole document'), findsOneWidget);

    await t.tap(find.text('Page 6'));
    await t.pumpAndSettle();
    expect(controller.jumps, [6]);
  });

  readerTest('che do toi: dao mau va nho lua chon', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    expect(find.byKey(const Key('reader_darkFilter')), findsNothing);

    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    await t.tap(find.text('Dark mode'));
    await settle(t);
    expect(find.byKey(const Key('reader_darkFilter')), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool('reader.darkMode'),
      isTrue,
    );
  });

  readerTest('tim kiem: mo thanh tim, gui tu khoa cho viewer', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_searchButton')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader_searchField')), findsOneWidget);

    await t.enterText(find.byKey(const Key('reader_searchField')), '  xin chao ');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(controller.searches, ['xin chao']);

    // Nut quay lai dong thanh tim, khong roi man doc.
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader_searchField')), findsNothing);
    expect(find.text('bao cao.pdf'), findsOneWidget);
  });

  readerTest('in: gui bytes cua file cho may in', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    await t.tap(find.text('Print'));
    await settle(t);
    expect(printed, hasLength(1));
    expect(printed.single.$2, 'bao cao.pdf');
    expect(printed.single.$1, (await t.runAsync(() => File(path).readAsBytes()))!);
  });

  readerTest('loi tat: yeu cau ghim co ten file khong duoi', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to home screen'));
    await settle(t);
    expect(shortcut.requests, [(path, 'bao cao')]);
    expect(
      find.text('Confirm adding the shortcut on your home screen.'),
      findsOneWidget,
    );
  });

  readerTest('may khong ho tro ghim loi tat: an muc menu', (t) async {
    shortcut = _FakeShortcut(supported: false);
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    expect(find.text('Add to home screen'), findsNothing);
    expect(find.text('Print'), findsOneWidget);
  });

  readerTest('PDF -> anh: mo man chuyen doi voi duong dan file', (t) async {
    final path = await mk(t);
    await pumpReader(t, OpenFileArgs(path));
    await t.tap(find.byKey(const Key('reader_menuButton')));
    await t.pumpAndSettle();
    await t.tap(find.text('PDF to image'));
    await t.pumpAndSettle();
    expect(find.text('PDF TO IMAGE SCREEN'), findsOneWidget);
    expect(pdfToImageExtra, path);
  });

  readerTest('file khong ton tai: bao loi, khong dung viewer', (t) async {
    await pumpReader(t, OpenFileArgs('${tmp.path}/missing.pdf'));
    expect(find.text('The file is damaged or cannot be read.'), findsOneWidget);
    expect(find.byKey(const Key('fake_viewer')), findsNothing);
  });

  group('PDF co mat khau', () {
    readerTest('viewer bao loi -> hoi mat khau, sai thi hoi lai, dung thi mo bang bytes', (t) async {
      failWithoutBytes = true;
      final path = await mk(t, password: 'abc123');
      await pumpReader(t, OpenFileArgs(path));

      expect(find.text('Enter password'), findsOneWidget);
      expect(find.text('"bao cao.pdf" is password protected.'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'sai-roi');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.text('Incorrect password.'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'abc123');
      await t.tap(find.text('OK'));
      await settle(t);
      await t.pumpAndSettle();

      expect(find.text('Enter password'), findsNothing);
      expect(configs.last.bytes, isNotNull);
      expect(find.text('1 / 10'), findsOneWidget);
    });

    readerTest('huy nhap mat khau -> roi man doc', (t) async {
      failWithoutBytes = true;
      final path = await mk(t, password: 'abc123');
      await pumpReader(t, OpenFileArgs(path));
      expect(find.text('Enter password'), findsOneWidget);
      await t.tap(find.text('CANCEL'));
      await settle(t);
      // Man doc la man duy nhat -> maybePop khong lam gi, nhung hop thoai da dong.
      expect(find.text('Enter password'), findsNothing);
    });

    readerTest('OpenFileArgs.password dung: giai ma ngay, khong hoi', (t) async {
      final path = await mk(t, password: 'abc123');
      await pumpReader(t, OpenFileArgs(path, password: 'abc123'));
      expect(find.text('Enter password'), findsNothing);
      expect(configs.last.bytes, isNotNull);
    });

    readerTest('file hong (khong phai ma hoa) -> thong bao loi file', (t) async {
      failWithoutBytes = true;
      final file = File('${tmp.path}/hong.pdf')..writeAsStringSync('not a pdf');
      await pumpReader(t, OpenFileArgs(file.path));
      expect(find.text('Enter password'), findsNothing);
      expect(find.text('The file is damaged or cannot be read.'), findsOneWidget);
    });
  });
}
