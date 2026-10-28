import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/app.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dựng app với DB trong bộ nhớ, prefs sạch và 3 stream tài liệu rỗng
/// (stream drift để lại timer sau khi cây widget bị huỷ).
Future<void> pumpApp(WidgetTester tester, {String locale = 'en'}) async {
  SharedPreferences.setMockInitialValues({SettingsRepository.kLocale: locale});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        documentsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
        homeRecentItemsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
        homeFavoriteItemsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
      ],
      child: const PdfOfficeApp(),
    ),
  );
}
