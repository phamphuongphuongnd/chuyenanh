/// Quyết định URL nào được phép mở bằng ứng dụng ngoài (hàm thuần).
const Set<String> kOpenableSchemes = {'http', 'https', 'mailto', 'tel'};

/// Trả về [Uri] nếu [raw] là liên kết an toàn để mở (http/https/mailto/tel),
/// ngược lại `null` (file:, javascript:, content:, intent:, thiếu scheme, rỗng…).
Uri? safeLinkUri(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  // Chặn ký tự điều khiển / khoảng trắng bên trong (tránh lách scheme).
  if (RegExp(r'[\x00-\x20\x7f]').hasMatch(s)) return null;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (!kOpenableSchemes.contains(scheme)) return null;
  if ((scheme == 'http' || scheme == 'https') && uri.host.isEmpty) return null;
  if ((scheme == 'mailto' || scheme == 'tel') && uri.path.isEmpty) return null;
  return uri;
}

bool isSafeLink(String? raw) => safeLinkUri(raw) != null;
