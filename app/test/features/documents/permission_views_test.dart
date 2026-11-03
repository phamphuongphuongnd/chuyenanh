import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/widgets/document_list.dart';
import 'package:pdf_office/features/documents/widgets/permission_views.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NeedsPermission extends ScanController {
  int requests = 0;

  @override
  ScanState build() => const ScanState(phase: ScanPhase.needsPermission);

  @override
  Future<bool> requestPermissionAndScan() async {
    requests++;
    return false;
  }
}

final _doc = DocItem(
  path: '/storage/a.pdf',
  name: 'a.pdf',
  ext: 'pdf',
  size: 1000,
  modified: DateTime(2026, 1, 2),
  folder: 'Download',
);

Future<(_NeedsPermission, SharedPreferences)> _pump(
  WidgetTester tester, {
  List<DocItem> docs = const [],
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final scan = _NeedsPermission();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        scanControllerProvider.overrideWith(() => scan),
        documentsProvider.overrideWith((ref) => Stream.value(docs)),
        favoritePathsProvider.overrideWith((ref) => Stream.value(<String>{})),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: DocumentList(category: null)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (scan, prefs);
}

final _dialog = find.byKey(const ValueKey('storage_permission_dialog'));

void main() {
  group('hộp thoại giải thích quyền', () {
    testWidgets('bấm Cấp quyền → hiện hộp thoại, chưa xin quyền', (t) async {
      final (scan, _) = await _pump(t);
      await t.tap(find.text('Grant access'));
      await t.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
      expect(find.textContaining('Choose file'), findsWidgets);
      expect(find.text('View privacy policy'), findsOneWidget);
      expect(scan.requests, 0);
    });

    testWidgets('"Not now" đóng hộp thoại và không xin quyền', (t) async {
      final (scan, _) = await _pump(t);
      await t.tap(find.text('Grant access'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('storage_permission_later')));
      await t.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(scan.requests, 0);
    });

    testWidgets('"Continue" gọi request() một lần', (t) async {
      final (scan, _) = await _pump(t);
      await t.tap(find.text('Grant access'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('storage_permission_continue')));
      await t.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(scan.requests, 1);
    });

    testWidgets('liên kết chính sách mở màn Quyền riêng tư', (t) async {
      await _pump(t);
      await t.tap(find.text('Grant access'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('storage_permission_privacy')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('privacy_body')), findsOneWidget);
    });

    testWidgets('từ chối (không có file) vẫn còn nút Chọn file', (t) async {
      await _pump(t);
      expect(find.byType(PickFileButton), findsOneWidget);
    });
  });

  group('biểu ngữ xin quyền', () {
    testWidgets('hiện khi có file và chưa tắt', (t) async {
      await _pump(t, docs: [_doc]);
      expect(find.byType(PermissionBanner), findsOneWidget);
    });

    testWidgets('bấm × → ẩn và lưu thời điểm tắt', (t) async {
      final (_, prefs) = await _pump(t, docs: [_doc]);
      await t.tap(find.byKey(const ValueKey('permission_banner_dismiss')));
      await t.pumpAndSettle();

      expect(find.byType(PermissionBanner), findsNothing);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(prefs.getInt(SettingsRepository.kStorageBannerDismissedAt), isNotNull);
    });

    testWidgets('đã tắt gần đây (đọc từ prefs) → không hiện', (t) async {
      await _pump(
        t,
        docs: [_doc],
        prefsValues: {
          SettingsRepository.kStorageBannerDismissedAt:
              DateTime.now().millisecondsSinceEpoch,
        },
      );
      expect(find.byType(PermissionBanner), findsNothing);
    });

    testWidgets('tắt đã quá hạn nhắc lại → hiện lại', (t) async {
      await _pump(
        t,
        docs: [_doc],
        prefsValues: {
          SettingsRepository.kStorageBannerDismissedAt: DateTime.now()
              .subtract(storageBannerSnooze + const Duration(days: 1))
              .millisecondsSinceEpoch,
        },
      );
      expect(find.byType(PermissionBanner), findsOneWidget);
    });

    test('isStorageBannerSnoozed', () {
      final now = DateTime(2026, 6, 1);
      expect(isStorageBannerSnoozed(null, now), isFalse);
      expect(isStorageBannerSnoozed(now, now), isTrue);
      expect(
        isStorageBannerSnoozed(now.subtract(storageBannerSnooze), now),
        isFalse,
      );
    });
  });
}
