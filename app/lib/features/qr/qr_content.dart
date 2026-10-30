import '../../core/utils/url_safety.dart';

/// Loại mã (định dạng ký hiệu) — độc lập với ML Kit để test và lưu lịch sử.
enum CodeFormat {
  qrCode('QR'),
  aztec('Aztec'),
  dataMatrix('Data Matrix'),
  pdf417('PDF417'),
  ean13('EAN-13'),
  ean8('EAN-8'),
  upca('UPC-A'),
  upce('UPC-E'),
  code128('Code 128'),
  code39('Code 39'),
  code93('Code 93'),
  codabar('Codabar'),
  itf('ITF'),
  unknown('?');

  const CodeFormat(this.label);

  /// Tên hiển thị (giống nhau mọi ngôn ngữ).
  final String label;

  /// Mã vạch sản phẩm 1D (nội dung thường là dãy số).
  bool get isProduct =>
      this == ean13 || this == ean8 || this == upca || this == upce;

  /// Đọc lại từ tên đã lưu; tên lạ → [unknown].
  static CodeFormat fromName(String? name) => CodeFormat.values.firstWhere(
    (f) => f.name == name,
    orElse: () => CodeFormat.unknown,
  );
}

/// Kiểu nội dung của mã (để chọn nhãn, icon và nút thao tác).
enum QrContentKind { url, wifi, contact, email, phone, sms, geo, event, product, text }

/// Thông tin mạng Wi‑Fi trong chuỗi `WIFI:S:..;T:..;P:..;H:..;;`.
class WifiInfo {
  const WifiInfo({
    required this.ssid,
    this.password,
    this.security,
    this.hidden = false,
  });

  final String ssid;

  /// `null` hoặc rỗng khi mạng mở.
  final String? password;

  /// WPA / WEP / nopass… (giữ nguyên như trong mã).
  final String? security;
  final bool hidden;
}

/// Một mã đã giải: loại mã + nội dung gốc.
class ScannedCode {
  const ScannedCode({required this.format, required this.raw});

  final CodeFormat format;

  /// Nội dung đầy đủ đúng như trong mã.
  final String raw;

  @override
  bool operator ==(Object other) =>
      other is ScannedCode && other.format == format && other.raw == raw;

  @override
  int get hashCode => Object.hash(format, raw);
}

/// Nội dung đã phân loại.
class QrContent {
  const QrContent({required this.kind, required this.raw, this.wifi});

  final QrContentKind kind;
  final String raw;

  /// Chỉ có khi [kind] là [QrContentKind.wifi].
  final WifiInfo? wifi;
}

final RegExp _emailRe = RegExp(r'^[^\s@:/]+@[^\s@:/]+\.[^\s@:/]+$');
final RegExp _phoneRe = RegExp(r'^\+?[0-9 ()\-]{6,20}$');
final RegExp _digitsRe = RegExp(r'^[0-9]+$');

bool _startsWithIgnoreCase(String s, String prefix) =>
    s.length >= prefix.length &&
    s.substring(0, prefix.length).toUpperCase() == prefix.toUpperCase();

/// Phân loại nội dung mã từ chuỗi gốc. Hàm thuần — có unit test.
///
/// [format] giúp nhận mã vạch sản phẩm (EAN/UPC chỉ có số).
QrContent classifyQrContent(String raw, {CodeFormat format = CodeFormat.qrCode}) {
  final s = raw.trim();
  QrContent of(QrContentKind k) => QrContent(kind: k, raw: raw);

  if (s.isEmpty) return of(QrContentKind.text);
  if (format.isProduct && _digitsRe.hasMatch(s)) {
    return of(QrContentKind.product);
  }
  if (_startsWithIgnoreCase(s, 'WIFI:')) {
    final wifi = parseWifi(s);
    if (wifi != null) {
      return QrContent(kind: QrContentKind.wifi, raw: raw, wifi: wifi);
    }
    return of(QrContentKind.text);
  }
  if (_startsWithIgnoreCase(s, 'http://') ||
      _startsWithIgnoreCase(s, 'https://')) {
    return of(QrContentKind.url);
  }
  if (_startsWithIgnoreCase(s, 'BEGIN:VCARD') ||
      _startsWithIgnoreCase(s, 'MECARD:')) {
    return of(QrContentKind.contact);
  }
  if (_startsWithIgnoreCase(s, 'BEGIN:VEVENT') ||
      _startsWithIgnoreCase(s, 'BEGIN:VCALENDAR')) {
    return of(QrContentKind.event);
  }
  if (_startsWithIgnoreCase(s, 'mailto:') ||
      _startsWithIgnoreCase(s, 'MATMSG:') ||
      _emailRe.hasMatch(s)) {
    return of(QrContentKind.email);
  }
  if (_startsWithIgnoreCase(s, 'tel:')) return of(QrContentKind.phone);
  if (_startsWithIgnoreCase(s, 'SMSTO:') || _startsWithIgnoreCase(s, 'sms:')) {
    return of(QrContentKind.sms);
  }
  if (_startsWithIgnoreCase(s, 'geo:')) return of(QrContentKind.geo);
  if (_phoneRe.hasMatch(s) && s.replaceAll(RegExp(r'\D'), '').length >= 6) {
    return of(QrContentKind.phone);
  }
  return of(QrContentKind.text);
}

/// Tách chuỗi Wi‑Fi theo chuẩn ZXing: `WIFI:T:WPA;S:ten;P:matkhau;H:false;;`.
/// Thứ tự trường tuỳ ý; `\;`, `\,`, `\:`, `\\`, `\"` là ký tự thoát.
/// Trả `null` khi không có tên mạng.
WifiInfo? parseWifi(String raw) {
  final s = raw.trim();
  if (!_startsWithIgnoreCase(s, 'WIFI:')) return null;
  final body = s.substring(5);
  final fields = <String, String>{};
  final buf = StringBuffer();
  var escaped = false;
  void flush() {
    final part = buf.toString();
    buf.clear();
    final colon = _unescapedColon(part);
    if (colon <= 0) return;
    final key = part.substring(0, colon).toUpperCase();
    final value = _unescape(part.substring(colon + 1));
    fields.putIfAbsent(key, () => value);
  }

  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (escaped) {
      buf
        ..write(r'\')
        ..write(c);
      escaped = false;
    } else if (c == r'\') {
      escaped = true;
    } else if (c == ';') {
      flush();
    } else {
      buf.write(c);
    }
  }
  flush();

  final ssid = _stripQuotes(fields['S'] ?? '');
  if (ssid.isEmpty) return null;
  final password = fields['P'];
  return WifiInfo(
    ssid: ssid,
    password: password == null || password.isEmpty
        ? null
        : _stripQuotes(password),
    security: (fields['T'] ?? '').isEmpty ? null : fields['T'],
    hidden: (fields['H'] ?? '').toLowerCase() == 'true',
  );
}

/// Vị trí dấu `:` đầu tiên không bị thoát (giá trị còn giữ `\x`).
int _unescapedColon(String s) {
  for (var i = 0; i < s.length; i++) {
    if (s[i] == r'\') {
      i++;
      continue;
    }
    if (s[i] == ':') return i;
  }
  return -1;
}

String _unescape(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (s[i] == r'\' && i + 1 < s.length) {
      out.write(s[i + 1]);
      i++;
    } else {
      out.write(s[i]);
    }
  }
  return out.toString();
}

/// Tên/mật khẩu dạng `"abc"` → `abc` (một số máy phát thêm ngoặc kép).
String _stripQuotes(String s) =>
    s.length >= 2 && s.startsWith('"') && s.endsWith('"')
    ? s.substring(1, s.length - 1)
    : s;

/// Liên kết được phép mở cho nội dung này, hoặc `null` (ẩn nút **Mở**).
/// Chỉ http/https/mailto/tel, và luôn qua [safeLinkUri]. Hàm thuần — có unit test.
Uri? qrOpenUri(QrContent content) {
  final s = content.raw.trim();
  switch (content.kind) {
    case QrContentKind.url:
    case QrContentKind.phone when _startsWithIgnoreCase(s, 'tel:'):
      return safeLinkUri(s);
    case QrContentKind.email:
      if (_startsWithIgnoreCase(s, 'mailto:')) return safeLinkUri(s);
      if (_emailRe.hasMatch(s)) return safeLinkUri('mailto:$s');
      return null;
    default:
      return null;
  }
}
