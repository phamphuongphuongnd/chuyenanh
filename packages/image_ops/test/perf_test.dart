@Tags(['perf'])
library;

import 'dart:typed_data';

import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Rough performance check on a generated 12 MP (4000x3000) photo.
/// Run alone for stable numbers: `dart test -t perf`.
void main() {
  late Uint8List src;

  setUpAll(() {
    src = jpg(photoLike(4000, 3000), quality: 90);
  });

  for (final f in ImageFilter.values) {
    test('12 MP -> maxLongSide 3000, $f', () {
      final sw = Stopwatch()..start();
      final out = applyEdit(src, ImageEdit(filter: f, maxLongSide: 3000));
      sw.stop();
      // ignore: avoid_print
      print('applyEdit 4000x3000 -> 3000x2250 [$f]: ${sw.elapsedMilliseconds} ms'
          ' (${out.length ~/ 1024} KiB)');
      // Generous bound so a loaded CI machine does not flake; target is < 3 s.
      expect(sw.elapsed, lessThan(const Duration(seconds: 8)));
    });
  }

  test('12 MP renderPreview (1024)', () {
    final sw = Stopwatch()..start();
    renderPreview(src, const ImageEdit(filter: ImageFilter.magicColor));
    sw.stop();
    // ignore: avoid_print
    print('renderPreview 4000x3000 -> 1024: ${sw.elapsedMilliseconds} ms');
  });

  test('12 MP detectDocumentCorners', () {
    final sw = Stopwatch()..start();
    detectDocumentCorners(src);
    sw.stop();
    // ignore: avoid_print
    print('detectDocumentCorners 4000x3000: ${sw.elapsedMilliseconds} ms');
  });

  test('12 MP perspectiveWarp', () {
    final sw = Stopwatch()..start();
    perspectiveWarp(src, const [
      NormPoint(0.1, 0.1),
      NormPoint(0.9, 0.12),
      NormPoint(0.88, 0.9),
      NormPoint(0.12, 0.92),
    ]);
    sw.stop();
    // ignore: avoid_print
    print('perspectiveWarp 4000x3000: ${sw.elapsedMilliseconds} ms');
  });
}
