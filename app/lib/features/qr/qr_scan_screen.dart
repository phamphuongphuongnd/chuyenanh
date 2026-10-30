import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/link_opener.dart';
import '../../core/widgets/widgets.dart';
import 'barcode_reader.dart';
import 'qr_content.dart';
import 'qr_history.dart';

enum _Phase { idle, scanning, done, error }

/// Quét mã QR / mã vạch từ ảnh chụp hoặc ảnh thư viện (offline, không có camera xem trực tiếp).
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  _Phase _phase = _Phase.idle;
  List<ScannedCode> _codes = const [];
  AppError? _error;

  /// Kết quả đang xem mở từ lịch sử (không hiện dòng "Tìm thấy N mã").
  bool _fromHistory = false;

  Future<void> _scan(QrImageSource source) async {
    final picker = ref.read(qrImagePickerProvider);
    final reader = ref.read(barcodeReaderProvider);
    try {
      final path = await picker.pick(source);
      if (path == null || !mounted) return;
      setState(() => _phase = _Phase.scanning);
      final codes = await reader.read(path);
      if (!mounted) return;
      await ref.read(qrHistoryProvider.notifier).add(codes);
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _fromHistory = false;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppError.from(e);
        _phase = _Phase.error;
      });
    }
  }

  void _showFromHistory(ScannedCode code) => setState(() {
    _codes = [code];
    _fromHistory = true;
    _phase = _Phase.done;
  });

  Future<void> _clearHistory() async {
    final l = context.l10n;
    final ok = await showConfirmDialog(
      context,
      title: l.qr_clearHistory,
      message: l.qr_clearHistoryConfirm,
      confirmLabel: l.core_delete,
    );
    if (ok) await ref.read(qrHistoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final busy = _phase == _Phase.scanning;
    return PopScope(
      // Đang xem kết quả / lỗi: nút quay lại đưa về màn đầu thay vì thoát.
      canPop: _phase == _Phase.idle || busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _phase = _Phase.idle);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(title: Text(l.core_toolQrScan)),
        body: SafeArea(child: _body(context)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _PillButton(
                    filled: true,
                    icon: Symbols.photo_camera_rounded,
                    label: l.qr_takePhoto,
                    onPressed: busy ? null : () => _scan(QrImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    filled: false,
                    icon: Symbols.photo_library_rounded,
                    label: l.qr_pickImage,
                    onPressed: busy
                        ? null
                        : () => _scan(QrImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    switch (_phase) {
      case _Phase.scanning:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l.qr_scanning,
                style: TextStyle(fontSize: 15, color: t.textMuted),
              ),
            ],
          ),
        );
      case _Phase.error:
        return EmptyState(
          icon: Symbols.error_rounded,
          title: appErrorMessage(context, _error ?? const Unknown('')),
        );
      case _Phase.done when _codes.isEmpty:
        return EmptyState(
          icon: Symbols.qr_code_scanner_rounded,
          title: l.qr_noCodeTitle,
          message: l.qr_noCodeMessage,
        );
      case _Phase.done:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (!_fromHistory)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  l.qr_found(_codes.length),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
              ),
            for (final code in _codes) ...[
              QrCodeCard(code: code),
              const SizedBox(height: 14),
            ],
          ],
        );
      case _Phase.idle:
        return _IdleView(
          onOpen: _showFromHistory,
          onClear: _clearHistory,
        );
    }
  }
}

/// Màn đầu: lời giới thiệu + lịch sử gần đây.
class _IdleView extends ConsumerWidget {
  const _IdleView({required this.onOpen, required this.onClear});

  final ValueChanged<ScannedCode> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final history = ref.watch(qrHistoryProvider);
    final intro = EmptyState(
      icon: Symbols.qr_code_scanner_rounded,
      title: l.qr_introTitle,
      message: l.qr_introMessage,
    );
    if (history.isEmpty) return intro;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        intro,
        Row(
          children: [
            Expanded(
              child: Text(
                l.qr_history,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Symbols.delete_sweep_rounded, size: 20),
              label: Text(l.qr_clearHistory),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: t.line),
                _HistoryTile(code: history[i], onTap: () => onOpen(history[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.code, required this.onTap});

  final ScannedCode code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = classifyQrContent(code.raw, format: code.format);
    final title = content.wifi?.ssid ?? code.raw.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _KindIcon(kind: content.kind, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${qrKindLabel(context, content.kind)} · ${code.format.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn kiểu nội dung theo ngôn ngữ hiện tại.
String qrKindLabel(BuildContext context, QrContentKind kind) {
  final l = context.l10n;
  return switch (kind) {
    QrContentKind.url => l.qr_kindUrl,
    QrContentKind.wifi => l.qr_kindWifi,
    QrContentKind.contact => l.qr_kindContact,
    QrContentKind.email => l.qr_kindEmail,
    QrContentKind.phone => l.qr_kindPhone,
    QrContentKind.sms => l.qr_kindSms,
    QrContentKind.geo => l.qr_kindGeo,
    QrContentKind.event => l.qr_kindEvent,
    QrContentKind.product => l.qr_kindProduct,
    QrContentKind.text => l.qr_kindText,
  };
}

IconData _kindIcon(QrContentKind kind) => switch (kind) {
  QrContentKind.url => Symbols.link_rounded,
  QrContentKind.wifi => Symbols.wifi_rounded,
  QrContentKind.contact => Symbols.contact_page_rounded,
  QrContentKind.email => Symbols.mail_rounded,
  QrContentKind.phone => Symbols.call_rounded,
  QrContentKind.sms => Symbols.sms_rounded,
  QrContentKind.geo => Symbols.location_on_rounded,
  QrContentKind.event => Symbols.event_rounded,
  QrContentKind.product => Symbols.barcode_rounded,
  QrContentKind.text => Symbols.notes_rounded,
};

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind, this.size = 42});

  final QrContentKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(_kindIcon(kind), size: size * 0.55, color: t.primaryText),
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.l10n.qr_copied)));
}

/// Thẻ một mã: loại mã, kiểu nội dung, nội dung đầy đủ (chọn được chữ), Chép / Chia sẻ / Mở.
class QrCodeCard extends StatelessWidget {
  const QrCodeCard({super.key, required this.code});

  final ScannedCode code;

  Future<void> _open(BuildContext context, Uri uri) async {
    final result = await openLink(linkLauncherOf(context), uri.toString());
    if (result.opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.qr_openFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final content = classifyQrContent(code.raw, format: code.format);
    final openUri = qrOpenUri(content);
    final wifi = content.wifi;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: t.textMuted,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _KindIcon(kind: content.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qrKindLabel(context, content.kind),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code.format.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (wifi != null) ...[
            const SizedBox(height: 14),
            _CopyField(label: l.qr_wifiNetwork, value: wifi.ssid),
            const SizedBox(height: 8),
            if (wifi.password != null)
              _CopyField(label: l.qr_wifiPassword, value: wifi.password!)
            else
              Text(l.qr_wifiNoPassword, style: labelStyle),
            if (wifi.security != null &&
                wifi.security!.toLowerCase() != 'nopass') ...[
              const SizedBox(height: 8),
              Text(
                '${l.qr_wifiSecurity}: ${wifi.security}',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Text(l.qr_content, style: labelStyle),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              code.raw,
              style: TextStyle(fontSize: 14.5, height: 1.45, color: t.text),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (openUri != null)
                FilledButton.icon(
                  onPressed: () => _open(context, openUri),
                  icon: const Icon(Symbols.open_in_new_rounded, size: 20),
                  label: Text(l.core_open),
                ),
              OutlinedButton.icon(
                onPressed: () => _copy(context, code.raw),
                icon: const Icon(Symbols.content_copy_rounded, size: 20),
                label: Text(l.qr_copy),
              ),
              OutlinedButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: code.raw,
                    sharePositionOrigin: defaultShareOrigin(),
                  ),
                ),
                icon: const Icon(Symbols.share_rounded, size: 20),
                label: Text(l.core_share),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một dòng nhãn + giá trị (chọn được chữ) + nút chép riêng (tên mạng, mật khẩu Wi‑Fi).
class _CopyField extends StatelessWidget {
  const _CopyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '${context.l10n.qr_copy} $label',
            onPressed: () => _copy(context, value),
            icon: const Icon(Symbols.content_copy_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Nút viên cao 52 ở thanh dưới: đỏ đặc (chính) hoặc viền (phụ).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.filled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final iconW = Icon(icon, size: 22);
    final button = filled
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 52),
              textStyle: const TextStyle(
                fontFamily: kUiFontFamily,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onPressed,
            icon: iconW,
            label: text,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onPressed,
            icon: iconW,
            label: text,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: filled && onPressed != null ? AppShadows.primary : null,
      ),
      child: SizedBox(height: 52, child: button),
    );
  }
}
