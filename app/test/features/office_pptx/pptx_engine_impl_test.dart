import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/office/pptx_engine.dart' as eng;
import 'package:pdf_office/features/office_pptx/pptx_engine_impl.dart';

const _fixtures = '../packages/pptx_reader/test/fixtures/real';

void main() {
  const engine = PackagePptxEngine();

  test('parseFile deck 16:9 thật → có slide, kích thước đúng tỉ lệ', () async {
    final deck = await engine.parseFile('$_fixtures/deck_16x9.pptx');
    expect(deck.slides, isNotEmpty);
    expect(deck.aspectRatio, closeTo(16 / 9, 0.01));
    final hasText = deck.slides.any(
      (s) => s.shapes.any(
        (sh) => sh is eng.PptxShapeText && sh.paragraphs.isNotEmpty,
      ),
    );
    expect(hasText, isTrue);
  });

  test('parseBytes deck 4:3', () async {
    final bytes = await File('$_fixtures/deck_4x3_theme.pptx').readAsBytes();
    final deck = await engine.parseBytes(bytes);
    expect(deck.aspectRatio, closeTo(4 / 3, 0.01));
  });

  test('deck_extras: có bảng hoặc nhóm / ảnh được ánh xạ', () async {
    final deck = await engine.parseFile('$_fixtures/deck_extras.pptx');
    final all = <eng.PptxShape>[];
    void walk(eng.PptxShape s) {
      all.add(s);
      if (s is eng.PptxGroup) s.children.forEach(walk);
    }

    for (final s in deck.slides) {
      s.shapes.forEach(walk);
    }
    expect(all, isNotEmpty);
  });

  test('bytes rác → CorruptFile', () async {
    await expectLater(
      engine.parseBytes(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<CorruptFile>()),
    );
  });

  test('file không tồn tại → AppError', () async {
    await expectLater(
      engine.parseFile('$_fixtures/khong_co.pptx'),
      throwsA(isA<AppError>()),
    );
  });
}
