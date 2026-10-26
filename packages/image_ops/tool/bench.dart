// Stage-by-stage benchmark on a generated 12 MP photo.
// Run: dart run tool/bench.dart   (JIT)  or
//      dart compile exe tool/bench.dart -o bench.exe && bench.exe   (AOT)
// ignore_for_file: avoid_print, implementation_imports
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:image_ops/src/filters.dart';
import 'package:image_ops/src/raw.dart';

T time<T>(String label, T Function() f) {
  final sw = Stopwatch()..start();
  final r = f();
  print('${label.padRight(40)} ${sw.elapsedMilliseconds} ms');
  return r;
}

Uint8List makePhoto(int w, int h) {
  final rnd = math.Random(1);
  final im = img.Image(width: w, height: h);
  final d = im.toUint8List();
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = rnd.nextInt(24) - 12;
      d[i++] = (x * 255 ~/ w + n).clamp(0, 255);
      d[i++] = (y * 255 ~/ h + n).clamp(0, 255);
      d[i++] = (((x + y) * 128 ~/ (w + h)) + 60 + n).clamp(0, 255);
    }
  }
  return img.encodeJpg(im, quality: 90);
}

void main() {
  final src = makePhoto(4000, 3000);
  print('source JPEG: ${src.length ~/ 1024} KiB');
  for (var round = 0; round < 2; round++) {
    print('--- round ${round + 1}');
    final d = time('decode 4000x3000', () => decodeRaw(src, targetLongSide: 3000));
    final r = time('downscale -> 3000', () => downscaleToLongSide(d.image, 3000));
    time('rotate 1 turn', () => rotateCw(r, 1));
    for (final f in ImageFilter.values) {
      final copy = RawImage(r.width, r.height, r.channels, Uint8List.fromList(r.data));
      time('filter $f', () => applyFilters(copy, ImageEdit(filter: f)));
    }
    time('encode JPEG q90 3000x2250', () => encodeRaw(r, OutputFormat.jpeg, 90));
    for (final f in ImageFilter.values) {
      time('applyEdit total [$f]',
          () => applyEdit(src, ImageEdit(filter: f, maxLongSide: 3000)));
    }
    time('renderPreview 1024', () => renderPreview(src, const ImageEdit()));
    time('detectDocumentCorners', () => detectDocumentCorners(src));
  }
}
