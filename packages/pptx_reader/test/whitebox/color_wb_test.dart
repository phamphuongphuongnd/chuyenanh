// Kiểm thử hộp trắng A19 — lib/src/color.dart (mã bộ C*, xem
// test-output/whitebox/pptx-reader/color/buoc-5-du-lieu-thu.md).
// Hàm thuần, không mock. Expected lấy từ Bước 5 (oracle độc lập theo công thức sRGB/HSL chuẩn,
// giá trị PowerPoint ghi trong comment/README). Nhánh khẳng định qua giá trị phân biệt theo nhánh.
import 'package:pptx_reader/src/color.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;
String hex(int? v) =>
    v == null ? 'null' : v.toRadixString(16).toUpperCase().padLeft(8, '0');

final ctx = ColorContext(
  themeColors: {
    'dk1': 0x111111,
    'lt1': 0xEEEEEE,
    'lt2': 0x222222,
    'accent1': 0x4472C4,
  },
  clrMap: {'bg1': 'dk1'},
  phClr: 0xFF123456,
);
String res(String xml) => hex(ctx.resolve(el(xml)));
String mod(int argb, String children) =>
    hex(ColorContext.applyModifiers(argb, el('<c>$children</c>')));
String hsl(int hueDeg, int? sat, int? lum) => res(
  '<hslClr${' hue="${hueDeg * 60000}"'}'
  '${sat == null ? '' : ' sat="$sat"'}${lum == null ? '' : ' lum="$lum"'}/>',
);

void main() {
  group('C1 colorIn', () {
    test('C1.1 màu đầu tiên trong container', () {
      expect(hex(ctx.colorIn(el('<solidFill><srgbClr val="FF0000"/></solidFill>'))), 'FFFF0000');
    });
    test('C1.2 container null ⇒ null', () => expect(ctx.colorIn(null), isNull));
    test('C1.3 container rỗng ⇒ null', () => expect(ctx.colorIn(el('<solidFill/>')), isNull));
    test('C1.4 bỏ con không phải màu, lấy màu kế tiếp', () {
      expect(hex(ctx.colorIn(el('<solidFill><x/><srgbClr val="00FF00"/></solidFill>'))), 'FF00FF00');
    });
  });

  group('C2 scheme', () {
    test('C2.1 qua clrMap (bg1 -> dk1)', () => expect(hex(ctx.scheme('bg1')), 'FF111111'));
    test('C2.2 phClr ⇒ màu placeholder', () => expect(hex(ctx.scheme('phClr')), 'FF123456'));
    test('C2.3 không có trong clrMap ⇒ ánh xạ mặc định (bg2 -> lt2)', () {
      expect(hex(ctx.scheme('bg2')), 'FF222222');
    });
    test('C2.4 tên theme trực tiếp (accent1)', () => expect(hex(ctx.scheme('accent1')), 'FF4472C4'));
    test('C2.5 tên không có trong theme ⇒ null', () => expect(ctx.scheme('accent9'), isNull));
  });

  group('C3 resolve', () {
    test('C3.1 srgbClr', () => expect(res('<srgbClr val="FF0000"/>'), 'FFFF0000'));
    test('C3.2 schemeClr', () => expect(res('<schemeClr val="accent1"/>'), 'FF4472C4'));
    test('C3.3 schemeClr thiếu val ⇒ null', () => expect(res('<schemeClr/>'), 'null'));
    test('C3.4 sysClr lấy lastClr', () {
      expect(res('<sysClr val="window" lastClr="00FF00"/>'), 'FF00FF00');
    });
    test('C3.5 sysClr window thiếu lastClr ⇒ trắng', () => expect(res('<sysClr val="window"/>'), 'FFFFFFFF'));
    test('C3.6 sysClr khác window thiếu lastClr ⇒ đen', () {
      expect(res('<sysClr val="windowText"/>'), 'FF000000');
    });
    test('C3.7 prstClr', () => expect(res('<prstClr val="red"/>'), 'FFFF0000'));
    test('C3.8 prstClr lạ ⇒ null', () => expect(res('<prstClr val="nope"/>'), 'null'));
    test('C3.9 scrgbClr 100%/0%/100%', () {
      expect(res('<scrgbClr r="100000" g="0" b="100000"/>'), 'FFFF00FF');
    });
    test('C3.10 hslClr 120°/100%/50%', () => expect(hsl(120, 100000, 50000), 'FF00FF00'));
    test('C3.11 hslClr thiếu hue ⇒ 0°', () {
      expect(res('<hslClr sat="100000" lum="50000"/>'), 'FFFF0000');
    });
    test('C3.12 hslClr thiếu sat ⇒ xám', () => expect(hsl(120, null, 50000), 'FF808080'));
    test('C3.13 hslClr thiếu lum ⇒ đen', () => expect(hsl(120, 100000, null), 'FF000000'));
    test('C3.14 thẻ màu lạ ⇒ null', () => expect(res('<fooClr val="FF0000"/>'), 'null'));
    test('C3.15 srgbClr sai hex ⇒ null', () => expect(res('<srgbClr val="ZZ"/>'), 'null'));
  });

  group('C4 ch', () {
    test('C4.1 kênh có giá trị', () {
      expect(res('<scrgbClr r="100000" g="100000" b="0"/>'), 'FFFFFF00');
    });
    test('C4.2 kênh thiếu ⇒ 0', () => expect(res('<scrgbClr r="100000" b="100000"/>'), 'FFFF00FF'));
  });

  group('C5 parseHex', () {
    test('C5.1 6 ký tự hex', () => expect(hex(ColorContext.parseHex('FF8000')), 'FFFF8000'));
    test('C5.2 null ⇒ null', () => expect(ColorContext.parseHex(null), isNull));
    test('C5.3 sai độ dài ⇒ null', () => expect(ColorContext.parseHex('FFF'), isNull));
    test('C5.4 không phải hex ⇒ null', () => expect(ColorContext.parseHex('GGGGGG'), isNull));
  });

  group('C6 applyModifiers', () {
    test('C6.1 alpha 50%', () => expect(mod(0xFF4472C4, '<alpha val="50000"/>'), '804472C4'));
    test('C6.2 không có modifier ⇒ giữ nguyên', () => expect(mod(0xFF4472C4, ''), 'FF4472C4'));
    test('C6.3 modifier thiếu val ⇒ val = 0', () => expect(mod(0xFF4472C4, '<alpha/>'), '004472C4'));
    test('C6.4 alphaMod 50%', () => expect(mod(0x80112233, '<alphaMod val="50000"/>'), '40112233'));
    test('C6.5 alphaOff +25%', () => expect(mod(0x80112233, '<alphaOff val="25000"/>'), 'C0112233'));
    test('C6.6 tint 50% (linear RGB)', () => expect(mod(0xFF4472C4, '<tint val="50000"/>'), 'FFC0C9E4'));
    test('C6.7 shade 50% (linear RGB) = 2F528F', () {
      expect(mod(0xFF4472C4, '<shade val="50000"/>'), 'FF2F528F');
    });
    test('C6.8 inv', () => expect(mod(0xFF4472C4, '<inv/>'), 'FFBB8D3B'));
    test('C6.9 gray', () => expect(mod(0xFF00FF00, '<gray/>'), 'FF969696'));
    test('C6.10 comp', () => expect(mod(0xFF800000, '<comp/>'), 'FF008080'));
    test('C6.11 lumMod 75% = 2F5597 (bảng màu PowerPoint)', () {
      expect(mod(0xFF4472C4, '<lumMod val="75000"/>'), 'FF2F5597');
    });
    test('C6.12 lumOff +20%', () => expect(mod(0xFF808080, '<lumOff val="20000"/>'), 'FFB3B3B3'));
    test('C6.13 satMod 50%', () => expect(mod(0xFF4472C4, '<satMod val="50000"/>'), 'FF647BA4'));
    test('C6.14 satOff +20%', () => expect(mod(0xFF808080, '<satOff val="20000"/>'), 'FF996767'));
    test('C6.15 hueMod 50%', () => expect(mod(0xFF00FF00, '<hueMod val="50000"/>'), 'FFFFFF00'));
    test('C6.16 hueOff 180°', () => expect(mod(0xFFFF0000, '<hueOff val="10800000"/>'), 'FF00FFFF'));
    test('C6.17 hueOff thiếu val ⇒ giữ nguyên', () => expect(mod(0xFFFF0000, '<hueOff/>'), 'FFFF0000'));
    test('C6.18 modifier lạ bị bỏ qua', () => expect(mod(0xFF4472C4, '<gamma/>'), 'FF4472C4'));
    test('C6.x lumMod 40% + lumOff 60% = B4C7E7 (bảng màu PowerPoint, nhiều vòng lặp)', () {
      expect(mod(0xFF4472C4, '<lumMod val="40000"/><lumOff val="60000"/>'), 'FFB4C7E7');
    });
  });

  group('C7 _toLinear (qua shade)', () {
    test('C7.1 kênh > 0.04045 (nhánh mũ)', () {
      expect(mod(0xFF4472C4, '<shade val="15000"/>'), 'FF172C51');
    });
    test('C7.2 kênh <= 0.04045 (nhánh tuyến tính), shade 100% giữ nguyên', () {
      expect(mod(0xFF050505, '<shade val="100000"/>'), 'FF050505');
    });
  });

  group('C8 _toSrgb (qua shade)', () {
    test('C8.1 v > 0.0031308', () => expect(mod(0xFF4472C4, '<shade val="50000"/>'), 'FF2F528F'));
    test('C8.2 v <= 0.0031308 (shade 0 ⇒ đen)', () {
      expect(mod(0xFFFFFFFF, '<shade val="0"/>'), 'FF000000');
    });
  });

  group('C9 _rgbToHsl (qua comp)', () {
    test('C9.1 mx = r, g >= b', () => expect(mod(0xFF800000, '<comp/>'), 'FF008080'));
    test('C9.2 xám (mx = mn)', () => expect(mod(0xFF808080, '<comp/>'), 'FF808080'));
    test('C9.3 l > 0.5', () => expect(mod(0xFFFF8080, '<comp/>'), 'FF80FFFF'));
    test('C9.4 mx = g', () => expect(mod(0xFF008000, '<comp/>'), 'FF800080'));
    test('C9.5 mx = r, g < b', () => expect(mod(0xFF800040, '<comp/>'), 'FF008040'));
    test('C9.6 mx = b', () => expect(mod(0xFF000080, '<comp/>'), 'FF808000'));
  });

  group('C10 _hsl (qua hslClr)', () {
    test('C10.1 s > 0, l < 0.5', () => expect(hsl(0, 100000, 25000), 'FF800000'));
    test('C10.2 s = 0 ⇒ xám', () => expect(hsl(0, 0, 25000), 'FF404040'));
    test('C10.3 l >= 0.5', () => expect(hsl(0, 100000, 75000), 'FFFF8080'));
  });

  group('C11 hue2rgb (qua hslClr)', () {
    test('C11.1 t < 1/6 (30°)', () => expect(hsl(30, 100000, 50000), 'FFFF8000'));
    test('C11.2 t < 0 ⇒ +1 (30°, kênh b)', () => expect(hsl(30, 100000, 50000), 'FFFF8000'));
    test('C11.3 t > 1 ⇒ -1 (270°)', () => expect(hsl(270, 100000, 50000), 'FF7F00FF'));
    test('C11.4 1/6 <= t < 1/2 (0°)', () => expect(hsl(0, 100000, 50000), 'FFFF0000'));
    test('C11.5 1/2 <= t < 2/3 (60°)', () => expect(hsl(60, 100000, 50000), 'FFFFFF00'));
    test('C11.6 t >= 2/3 (120°)', () => expect(hsl(120, 100000, 50000), 'FF00FF00'));
  });
}
