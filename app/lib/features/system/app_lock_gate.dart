import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../data/settings/settings_providers.dart';
import '../settings/app_logo.dart';
import 'app_authenticator.dart';

/// Lớp khoá app (vân tay / khuôn mặt / PIN máy) bọc toàn bộ app trong `MaterialApp.router(builder:)`.
///
/// Khi `AppSettings.appLock` bật: phủ màn khoá lên [child] lúc khởi động và khi app quay lại
/// sau ≥ [gracePeriod] ở nền; tự gọi xác thực một lần mỗi khi màn khoá hiện. Rời app ngắn
/// (chọn file/ảnh, camera, chia sẻ, mở app ngoài) nằm trong thời gian ân hạn nên không khoá;
/// lúc hộp thoại xác thực của hệ thống đang mở thì không tính là rời app.
///
/// Nằm trên Navigator (không có Overlay) nên màn khoá chỉ dùng widget thường, không dùng
/// dialog / tooltip.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  /// Ở nền ít nhất bấy nhiêu thì quay lại phải mở khoá.
  static const gracePeriod = Duration(seconds: 30);

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late bool _locked;

  /// Lúc app xuống nền (hidden/paused); `null` = đang ở trước hoặc không tính.
  DateTime? _backgroundedAt;

  /// Màn khoá vừa hiện, chờ app ở trạng thái resumed để tự hỏi xác thực.
  bool _autoAuthPending = false;
  bool _authenticating = false;

  DateTime _now() => ref.read(appLockClockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).appLock;
    if (_locked) _scheduleAutoAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Màn PIN / sinh trắc của hệ thống (Android mở Activity riêng) không phải rời app.
        if (_backgroundedAt == null &&
            !ref.read(appAuthServiceProvider).isAuthenticating) {
          _backgroundedAt = _now();
        }
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        final enabled = ref.read(settingsProvider).appLock;
        if (enabled &&
            !_locked &&
            since != null &&
            _now().difference(since) >= AppLockGate.gracePeriod) {
          setState(() => _locked = true);
          _scheduleAutoAuth();
        } else if (_locked && _autoAuthPending) {
          _maybeAutoAuth();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleAutoAuth() {
    _autoAuthPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoAuth());
  }

  void _maybeAutoAuth() {
    if (!mounted || !_locked || !_autoAuthPending) return;
    // Hộp thoại hệ thống chỉ hiện được khi app đang ở trước; chưa thì đợi resumed.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _autoAuthPending = false;
    unawaited(_unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    final service = ref.read(appAuthServiceProvider);
    final reason = context.l10n.settings_appLockReasonUnlock;
    setState(() => _authenticating = true);
    final result = await service.authenticate(reason);
    var unlock = result == AppAuthResult.success;
    // Máy đã gỡ hết khoá màn hình thì không còn cách nào xác thực: cho vào, tránh kẹt
    // ngoài app vĩnh viễn. Lỗi khác (máy vẫn có khoá) thì giữ màn khoá.
    if (result == AppAuthResult.unavailable) {
      unlock = !await service.isSupported();
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (unlock) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tắt khoá trong Cài đặt (đã xác thực ở đó) thì bỏ màn khoá nếu đang hiện.
    ref.listen<bool>(settingsProvider.select((s) => s.appLock), (_, enabled) {
      if (!enabled && _locked) {
        setState(() {
          _locked = false;
          _autoAuthPending = false;
        });
      }
    });
    return Stack(
      fit: StackFit.expand,
      children: [
        // Giữ child trong cây để không mất trạng thái; khi khoá thì chặn focus,
        // trình đọc màn hình và hoạt ảnh của nội dung bên dưới.
        ExcludeFocus(
          excluding: _locked,
          child: ExcludeSemantics(
            excluding: _locked,
            child: TickerMode(enabled: !_locked, child: widget.child),
          ),
        ),
        if (_locked)
          _LockScreen(
            key: const ValueKey('app_lock_screen'),
            busy: _authenticating,
            onUnlock: _unlock,
          ),
      ],
    );
  }
}

/// Màn khoá phủ kín: logo, "Phiotron PDF đã khoá", lời nhắc, nút "Mở khoá".
class _LockScreen extends StatelessWidget {
  const _LockScreen({super.key, required this.busy, required this.onUnlock});

  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      // Material đục: che hẳn nội dung và nhận mọi lần chạm thay cho màn bên dưới.
      child: Material(
        color: t.bg,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 88),
                  const SizedBox(height: 26),
                  Text(
                    l.settings_appLockLocked,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.settings_appLockLockedHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: t.textMuted),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('app_lock_unlock'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 50),
                    ),
                    onPressed: busy ? null : onUnlock,
                    icon: const Icon(Symbols.fingerprint_rounded, size: 22),
                    label: Text(l.settings_appLockUnlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
