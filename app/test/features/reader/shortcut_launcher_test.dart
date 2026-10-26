import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_launcher.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';

class _FakeService extends ShortcutService {
  _FakeService(this.initial);
  final String? initial;
  void Function(String)? handler;

  @override
  Future<String?> takeInitialPath() async => initial;

  @override
  void setOpenPathHandler(void Function(String path)? h) => handler = h;
}

void main() {
  late Directory tmp;
  late File pdf;
  late AppDatabase db;
  late List<Object?> pushed;
  late GoRouter router;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('shortcut_launcher_');
    pdf = File('${tmp.path}/a.pdf')..writeAsBytesSync([1, 2, 3]);
    db = AppDatabase(NativeDatabase.memory());
    pushed = [];
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: Routes.pdfReader,
          builder: (_, state) {
            pushed.add(state.extra);
            return const SizedBox();
          },
        ),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  ProviderContainer makeContainer(_FakeService service) {
    final c = ProviderContainer(
      overrides: [
        shortcutServiceProvider.overrideWithValue(service),
        appDatabaseProvider.overrideWithValue(db),
        appRouterProvider.overrideWithValue(router),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('khoi dong tu loi tat: mo reader voi dung duong dan', (t) async {
    final service = _FakeService(pdf.path);
    final c = makeContainer(service);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Builder(
          builder: (context) {
            c.read(shortcutLaunchProvider);
            return MaterialAppRouterHost(router: router);
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(pushed.toSet(), {OpenFileArgs(pdf.path)});
    expect((await db.recentsDao.getRecent()).map((r) => r.path), [pdf.path]);
  });

  testWidgets('onNewIntent khi dang chay: mo reader', (t) async {
    final service = _FakeService(null);
    final c = makeContainer(service);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Builder(
          builder: (context) {
            c.read(shortcutLaunchProvider);
            return MaterialAppRouterHost(router: router);
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(pushed, isEmpty);
    service.handler!(pdf.path);
    await t.pumpAndSettle();
    expect(pushed.toSet(), {OpenFileArgs(pdf.path)});
  });

  test('bo qua file khong con, khong phai PDF', () {
    final c = makeContainer(_FakeService(null));
    final ref = c.read(_refProbe);
    expect(openShortcutPath(ref, '${tmp.path}/missing.pdf'), isFalse);
    File('${tmp.path}/b.txt').writeAsStringSync('x');
    expect(openShortcutPath(ref, '${tmp.path}/b.txt'), isFalse);
    expect(pushed, isEmpty);
  });
}

final _refProbe = Provider<Ref>((ref) => ref);

/// MaterialApp.router tối giản để GoRouter có UI.
class MaterialAppRouterHost extends StatelessWidget {
  const MaterialAppRouterHost({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) => WidgetsApp.router(
    routerConfig: router,
    color: const Color(0xFFFFFFFF),
  );
}
