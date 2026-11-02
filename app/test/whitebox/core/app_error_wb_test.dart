// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/errors/app_error.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/app_error/buoc-5-du-lieu-thu.md
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';

FileSystemException _fse(int? code) => FileSystemException(
  'x',
  'p',
  code == null ? null : OSError('os', code),
);

void main() {
  group('U1 AppError.from', () {
    test('1.1 đã là AppError ⇒ giữ nguyên đối tượng', () {
      const e = WrongPassword();
      expect(AppError.from(e), same(e));
    });

    test('1.2 lỗi không phải FileSystemException ⇒ Unknown giữ cause', () {
      final cause = StateError('boom');
      final r = AppError.from(cause);
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause, same(cause));
    });

    test('1.3 ENOSPC 28 ⇒ NoSpace', () {
      expect(AppError.from(_fse(28)), isA<NoSpace>());
    });

    test('1.4 ERROR_DISK_FULL 112 ⇒ NoSpace', () {
      expect(AppError.from(_fse(112)), isA<NoSpace>());
    });

    test('1.5 EACCES 13 ⇒ PermissionDenied', () {
      expect(AppError.from(_fse(13)), isA<PermissionDenied>());
    });

    test('1.6 EPERM 1 ⇒ PermissionDenied', () {
      expect(AppError.from(_fse(1)), isA<PermissionDenied>());
    });

    test('1.7 ERROR_ACCESS_DENIED 5 ⇒ PermissionDenied', () {
      expect(AppError.from(_fse(5)), isA<PermissionDenied>());
    });

    test('1.8 mã OS khác (2) ⇒ Unknown giữ cause', () {
      final cause = _fse(2);
      final r = AppError.from(cause);
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause, same(cause));
    });

    test('1.9 FileSystemException không có osError ⇒ Unknown', () {
      final cause = _fse(null);
      final r = AppError.from(cause);
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause, same(cause));
    });
  });

  group('U2 appErrorMessage', () {
    late BuildContext ctx;
    late AppLocalizations l;

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      l = AppLocalizations.of(ctx);
    }

    final cases = <(String, AppError, String Function(AppLocalizations))>[
      ('2.1 WrongPassword', const WrongPassword(), (l) => l.core_errorWrongPassword),
      ('2.2 PasswordRequired', const PasswordRequired(), (l) => l.core_errorPasswordRequired),
      ('2.3 CorruptFile', const CorruptFile('x'), (l) => l.core_errorCorruptFile),
      ('2.4 UnsupportedFormat', const UnsupportedFormat('zip'), (l) => l.core_errorUnsupportedFormat),
      ('2.5 NoSpace', const NoSpace(), (l) => l.core_errorNoSpace),
      ('2.6 PermissionDenied', const PermissionDenied(), (l) => l.core_errorPermissionDenied),
      ('2.7 Cancelled', const Cancelled(), (l) => l.core_errorCancelled),
      ('2.8 Unknown', Unknown(StateError('x')), (l) => l.core_errorUnknown),
    ];
    for (final (name, error, key) in cases) {
      testWidgets('$name ⇒ câu thông báo đúng loại, khác mọi loại khác', (
        tester,
      ) async {
        await pump(tester);
        final m = appErrorMessage(ctx, error);
        expect(m, key(l));
        expect(m, isNotEmpty);
        final others = cases
            .where((c) => c.$1 != name)
            .map((c) => c.$3(l))
            .toSet();
        expect(others.contains(m), isFalse, reason: 'mỗi loại lỗi một câu riêng');
      });
    }
  });
}
