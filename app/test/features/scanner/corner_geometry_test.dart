import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/scanner/manual/corner_geometry.dart';

ops.NormPoint pt(double x, double y) => ops.NormPoint(x, y);

void main() {
  test('defaultCorners là hình chữ nhật hợp lệ theo thứ tự TL,TR,BR,BL', () {
    final c = defaultCorners();
    expect(c[0], pt(0.1, 0.1));
    expect(c[2], pt(0.9, 0.9));
    expect(isValidQuad(c), isTrue);
    expect(quadArea(c), closeTo(0.64, 1e-9));
  });

  test('clampPoint giữ trong 0..1', () {
    expect(clampPoint(pt(-0.2, 1.4)), pt(0, 1));
    expect(clampPoint(pt(0.3, 0.4)), pt(0.3, 0.4));
  });

  test('nearestCornerIndex chọn góc gần nhất trong bán kính', () {
    final c = defaultCorners();
    expect(nearestCornerIndex(c, pt(0.12, 0.08)), 0);
    expect(nearestCornerIndex(c, pt(0.88, 0.93)), 2);
    expect(nearestCornerIndex(c, pt(0.5, 0.5)), isNull);
  });

  test('isValidQuad từ chối tứ giác lõm, tự cắt, quá nhỏ, sai số điểm', () {
    // lõm: góc dưới-phải kéo vào trong
    expect(
      isValidQuad([pt(.1, .1), pt(.9, .1), pt(.3, .3), pt(.1, .9)]),
      isFalse,
    );
    // tự cắt (bướm)
    expect(
      isValidQuad([pt(.1, .1), pt(.9, .9), pt(.9, .1), pt(.1, .9)]),
      isFalse,
    );
    // quá nhỏ
    expect(
      isValidQuad([pt(.4, .4), pt(.45, .4), pt(.45, .45), pt(.4, .45)]),
      isFalse,
    );
    expect(isValidQuad([pt(.1, .1), pt(.9, .1), pt(.9, .9)]), isFalse);
  });

  test('isValidQuad chấp nhận hình thang nghiêng', () {
    expect(
      isValidQuad([pt(.2, .1), pt(.8, .15), pt(.9, .9), pt(.1, .85)]),
      isTrue,
    );
  });
}
