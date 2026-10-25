import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';

void main() {
  test('AppError.from giữ nguyên AppError', () {
    const e = WrongPassword();
    expect(AppError.from(e), same(e));
  });

  test('AppError.from đổi lỗi đĩa đầy / thiếu quyền', () {
    expect(
      AppError.from(const FileSystemException('x', 'p', OSError('full', 28))),
      isA<NoSpace>(),
    );
    expect(
      AppError.from(const FileSystemException('x', 'p', OSError('denied', 13))),
      isA<PermissionDenied>(),
    );
  });

  test('lỗi khác → Unknown giữ cause', () {
    final e = AppError.from(StateError('boom'));
    expect(e, isA<Unknown>());
    expect((e as Unknown).cause, isA<StateError>());
  });
}
