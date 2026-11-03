import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Hộp chữ trên ảnh, toạ độ theo đơn vị nội dung [widthUnits] × [heightUnits] của ảnh
/// (vd. pt của trang), gốc trên-trái; hàm xoá tự quy ra pixel.
class PixelBox {
  const PixelBox(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Kết quả xoá chữ: ảnh JPEG mới + màu chữ (0xRRGGBB) đo được cho từng hộp (cùng thứ tự đầu vào).
class ErasedImage {
  const ErasedImage(this.bytes, this.textColors, this.imageWidth, this.imageHeight);

  final Uint8List bytes;
  final List<int> textColors;
  final int imageWidth;
  final int imageHeight;
}

/// Xoá chữ khỏi ảnh [jpeg] (nội dung [widthUnits] × [heightUnits]): mỗi hộp trong [boxes] được tô bằng màu nền lấy mẫu (trung vị từng
/// kênh) trên vành 2 px quanh hộp. Màu chữ ước lượng từ các điểm ảnh trong hộp khác nền nhiều
/// nhất (không rõ → đen). Nền phức tạp (ảnh, gradient) có thể để lại vệt.
///
/// Thuần, đồng bộ; chạy được trong `Isolate.run`. Ảnh không giải mã được → trả null.
ErasedImage? eraseTextFromJpeg(
  Uint8List jpeg,
  List<PixelBox> boxes, {
  required double widthUnits,
  required double heightUnits,
  int quality = 85,
}) {
  img.Image? image;
  try {
    image = img.decodeJpg(jpeg);
  } catch (_) {
    return null; // không phải JPEG hợp lệ
  }
  if (image == null || !(widthUnits > 0 && heightUnits > 0)) return null;
  final w = image.width;
  final h = image.height;
  final sx = w / widthUnits;
  final sy = h / heightUnits;

  // Mọi mẫu lấy từ ảnh gốc (trước khi tô) để hộp kề nhau không lấy màu của hộp đã xoá.
  final rects = <List<int>>[];
  final bgs = <List<int>>[];
  final colors = <int>[];
  for (final b in boxes) {
    const padX = 2;
    final padY = math.max(2, (b.height * sy * 0.1).round());
    final x0 = ((b.left * sx).floor() - padX).clamp(0, w);
    final y0 = ((b.top * sy).floor() - padY).clamp(0, h);
    final x1 = ((b.left + b.width) * sx).ceil() + padX;
    final y1 = ((b.top + b.height) * sy).ceil() + padY;
    final cx1 = x1.clamp(0, w);
    final cy1 = y1.clamp(0, h);
    rects.add([x0, y0, cx1, cy1]);
    if (cx1 <= x0 || cy1 <= y0) {
      bgs.add(const [255, 255, 255]);
      colors.add(0);
      continue;
    }
    final bg = _ringMedian(image, x0, y0, cx1, cy1);
    bgs.add(bg);
    colors.add(_textColor(image, x0, y0, cx1, cy1, bg));
  }
  for (var i = 0; i < rects.length; i++) {
    final r = rects[i];
    if (r[2] <= r[0] || r[3] <= r[1]) continue;
    final c = bgs[i];
    img.fillRect(
      image,
      x1: r[0],
      y1: r[1],
      x2: r[2] - 1,
      y2: r[3] - 1,
      color: img.ColorRgb8(c[0], c[1], c[2]),
    );
  }
  return ErasedImage(
    Uint8List.fromList(img.encodeJpg(image, quality: quality)),
    colors,
    w,
    h,
  );
}

/// Trung vị từng kênh của vành 2 px ngay ngoài (x0,y0)-(x1,y1) (cắt theo biên ảnh).
List<int> _ringMedian(img.Image im, int x0, int y0, int x1, int y1) {
  final rs = <int>[], gs = <int>[], bs = <int>[];
  void add(int x, int y) {
    if (x < 0 || y < 0 || x >= im.width || y >= im.height) return;
    final p = im.getPixel(x, y);
    rs.add(p.r.toInt());
    gs.add(p.g.toInt());
    bs.add(p.b.toInt());
  }

  for (var d = 1; d <= 2; d++) {
    for (var x = x0 - d; x <= x1 + d - 1; x++) {
      add(x, y0 - d);
      add(x, y1 + d - 1);
    }
    for (var y = y0; y < y1; y++) {
      add(x0 - d, y);
      add(x1 + d - 1, y);
    }
  }
  if (rs.isEmpty) {
    // Hộp phủ kín ảnh: lấy mẫu ngay các góc trong hộp.
    add(x0.clamp(0, im.width - 1), y0.clamp(0, im.height - 1));
  }
  if (rs.isEmpty) return const [255, 255, 255];
  return [_median(rs), _median(gs), _median(bs)];
}

int _median(List<int> v) {
  v.sort();
  return v[v.length ~/ 2];
}

/// Màu chữ: trung bình các điểm trong hộp cách nền > 60% khoảng cách lớn nhất; chênh lệch
/// quá nhỏ (không có chữ rõ) → đen.
int _textColor(img.Image im, int x0, int y0, int x1, int y1, List<int> bg) {
  var maxD = 0;
  int dist(img.Pixel p) =>
      (p.r.toInt() - bg[0]).abs() +
      (p.g.toInt() - bg[1]).abs() +
      (p.b.toInt() - bg[2]).abs();
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      maxD = math.max(maxD, dist(im.getPixel(x, y)));
    }
  }
  if (maxD < 90) return 0;
  final cut = maxD * 0.6;
  var n = 0, r = 0, g = 0, b = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final p = im.getPixel(x, y);
      if (dist(p) >= cut) {
        n++;
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
      }
    }
  }
  if (n == 0) return 0;
  return ((r ~/ n) << 16) | ((g ~/ n) << 8) | (b ~/ n);
}
