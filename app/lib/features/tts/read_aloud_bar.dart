import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import 'read_aloud_controller.dart';
import 'tts_engine.dart';
import 'tts_logic.dart';

/// Thanh đọc to (Phát/Tạm dừng · Đoạn trước/sau · Dừng · Tốc độ · Giọng) cho một danh sách
/// đoạn văn, dùng giọng đọc có sẵn của máy (offline). Cao 64, đặt ở đáy màn
/// (vd. `bottomNavigationBar`) — đã tự chừa vùng an toàn dưới.
///
/// [onParagraph] báo đoạn bắt đầu đọc / vừa chuyển tới để màn chứa cuộn tới.
/// Tự dừng khi bị huỷ, tạm dừng khi có màn khác che lên. Cần `ProviderScope` phía trên;
/// test thay engine bằng `ttsEngineProvider.overrideWithValue(...)`.
class ReadAloudBar extends ConsumerStatefulWidget {
  const ReadAloudBar({
    super.key,
    required this.paragraphs,
    this.languageCode,
    this.onParagraph,
  });

  final List<String> paragraphs;

  /// Mã ngôn ngữ (vi, en, zh, ja, ko, id); null = ngôn ngữ app.
  final String? languageCode;
  final ValueChanged<int>? onParagraph;

  @override
  ConsumerState<ReadAloudBar> createState() => _ReadAloudBarState();
}

class _ReadAloudBarState extends ConsumerState<ReadAloudBar> {
  late final ReadAloudController _c;
  String? _requestedLocale;
  String _languageCode = 'en';

  @override
  void initState() {
    super.initState();
    _c = ReadAloudController(
      engine: ref.read(ttsEngineProvider),
      paragraphs: widget.paragraphs,
      onParagraph: widget.onParagraph,
    )..addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Màn khác (trang mờ đục) đè lên → Overlay tắt TickerMode của màn này → tạm dừng.
    // Bảng chọn / hộp thoại không che kín nên không ảnh hưởng.
    if (!TickerMode.valuesOf(context).enabled && _c.isPlaying) {
      scheduleMicrotask(() {
        if (mounted) _c.pause();
      });
    }
  }

  @override
  void didUpdateWidget(ReadAloudBar old) {
    super.didUpdateWidget(old);
    _c.onParagraph = widget.onParagraph;
    if (!listEquals(old.paragraphs, widget.paragraphs)) {
      _c.setParagraphs(widget.paragraphs);
    }
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final err = _c.error;
    if (err == null || !mounted) return;
    _c.clearError();
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.tts_error)));
  }

  /// `languageCode` → ngôn ngữ trong cài đặt → ngôn ngữ đang hiển thị.
  String _resolveLanguage(BuildContext context) {
    final given = widget.languageCode?.trim();
    if (given != null && given.isNotEmpty) return given;
    Locale? fromSettings;
    try {
      fromSettings = ref.watch(settingsProvider.select((s) => s.locale));
    } catch (_) {
      // Chưa có SharedPreferences (vd. test) → dùng ngôn ngữ đang hiển thị.
    }
    return (fromSettings ?? Localizations.localeOf(context)).languageCode;
  }

  @override
  Widget build(BuildContext context) {
    _languageCode = _resolveLanguage(context);
    final locale = ttsLocaleFor(_languageCode);
    if (locale != _requestedLocale) {
      _requestedLocale = locale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.setLocale(locale);
      });
    }
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) => switch (_c.status) {
                ReadAloudStatus.checking => _buildChecking(context),
                ReadAloudStatus.unavailable => _buildUnavailable(context),
                _ => _buildControls(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecking(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        const SizedBox(width: 8),
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.tts_checking,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: t.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final name = localeNativeNames[_languageCode.toLowerCase()] ??
        _requestedLocale ??
        _languageCode;
    return Row(
      children: [
        const SizedBox(width: 6),
        Icon(Symbols.voice_over_off_rounded, size: 22, color: t.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l.tts_noVoice(name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: t.text, height: 1.3),
          ),
        ),
        TextButton(
          key: const ValueKey('tts_howto'),
          onPressed: _showInstallHelp,
          child: Text(l.tts_howToInstall),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final ready = _c.hasContent;
    final current = ready ? _c.currentParagraph + 1 : 0;
    return Row(
      children: [
        Flexible(
          child: Container(
            key: const ValueKey('tts_progress'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l.tts_progress(current, _c.paragraphCount),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.primaryText,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        _iconButton(
          key: 'tts_prev',
          icon: Symbols.skip_previous_rounded,
          tooltip: l.tts_prev,
          onPressed: _c.canPrev ? _c.previous : null,
        ),
        const SizedBox(width: 2),
        IconButton.filled(
          key: const ValueKey('tts_play'),
          tooltip: _c.isPlaying ? l.tts_pause : l.tts_play,
          onPressed: ready ? _c.togglePlay : null,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            fixedSize: const Size.square(44),
            minimumSize: const Size.square(44),
          ),
          icon: Icon(
            _c.isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
            fill: 1,
            size: 26,
          ),
        ),
        const SizedBox(width: 2),
        _iconButton(
          key: 'tts_next',
          icon: Symbols.skip_next_rounded,
          tooltip: l.tts_next,
          onPressed: _c.canNext ? _c.next : null,
        ),
        _iconButton(
          key: 'tts_stop',
          icon: Symbols.stop_rounded,
          tooltip: l.tts_stop,
          onPressed:
              _c.isPlaying || _c.status == ReadAloudStatus.paused ? _c.stop : null,
        ),
        TextButton(
          key: const ValueKey('tts_speed'),
          onPressed: _showSpeedSheet,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            foregroundColor: t.text,
          ),
          child: Text(
            ttsSpeedLabel(_c.speed),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        if (_c.voices.length > 1)
          _iconButton(
            key: 'tts_voice',
            icon: Symbols.record_voice_over_rounded,
            tooltip: l.tts_voice,
            onPressed: _showVoiceSheet,
          ),
      ],
    );
  }

  Widget _iconButton({
    required String key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 24),
    color: context.tokens.text,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    padding: EdgeInsets.zero,
  );

  void _showSpeedSheet() => showChoiceSheet<double>(
    context,
    title: context.l10n.tts_speed,
    options: [
      for (final s in kTtsSpeeds)
        (s, ttsSpeedLabel(s), ValueKey('tts_speed_$s')),
    ],
    current: _c.speed,
    onSelect: _c.setSpeed,
  );

  void _showVoiceSheet() {
    final l = context.l10n;
    showChoiceSheet<TtsVoice?>(
      context,
      title: l.tts_voice,
      options: [
        (null, l.tts_voiceDefault, const ValueKey('tts_voice_default')),
        for (final (i, v) in _c.voices.indexed)
          (
            v,
            ttsVoiceDisplayName(v) ?? l.tts_voiceN(i + 1),
            ValueKey('tts_voice_$i'),
          ),
      ],
      current: _c.voice,
      onSelect: _c.setVoice,
    );
  }

  void _showInstallHelp() {
    final l = context.l10n;
    final ios = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    showAppSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.tts_installTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Text(
                ios ? l.tts_installIos : l.tts_installAndroid,
                style: TextStyle(fontSize: 14.5, height: 1.5, color: t.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FilledButton(
                key: const ValueKey('tts_recheck'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _c.recheck();
                },
                child: Text(l.tts_recheck),
              ),
            ),
          ],
        );
      },
    );
  }
}
