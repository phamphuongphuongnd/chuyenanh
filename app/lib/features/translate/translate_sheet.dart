import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/cancel_token.dart';
import '../../core/widgets/widgets.dart';
import 'translate_download.dart';
import 'translate_languages.dart';
import 'translate_models_screen.dart';
import 'translate_providers.dart';
import 'translator_engine.dart';

/// Mở bảng dịch trên máy (ML Kit) cho các đoạn văn: chọn ngôn ngữ nguồn/đích, tải gói ngôn ngữ (cần mạng
/// một lần), hiện bản dịch song song đoạn gốc, chép/chia sẻ.
///
/// Điện thoại: bottom sheet toàn chiều cao; máy tính bảng: hộp thoại lớn giữa màn.
/// Cần `ProviderScope` phía trên (app đã có). Đoạn rỗng bị bỏ qua.
Future<void> showTranslateSheet(
  BuildContext context, {
  required List<String> paragraphs,
}) {
  final panel = TranslatePanel(paragraphs: paragraphs);
  if (isTabletLayout(context)) {
    final size = MediaQuery.sizeOf(context);
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 640, height: size.height * 0.85, child: panel),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(heightFactor: 1, child: panel),
  );
}

/// Nội dung bảng dịch (tách riêng để test và để nhúng vào hộp thoại máy tính bảng).
class TranslatePanel extends ConsumerStatefulWidget {
  const TranslatePanel({super.key, required this.paragraphs});

  final List<String> paragraphs;

  @override
  ConsumerState<TranslatePanel> createState() => _TranslatePanelState();
}

class _TranslatePanelState extends ConsumerState<TranslatePanel> {
  late final List<String> _paragraphs = cleanParagraphs(widget.paragraphs);
  late final List<List<String>> _batches = splitIntoBatches(
    _paragraphs,
    kTranslateBatchSize,
  );
  late final String _guessed = guessLanguageCode(sampleForGuess(_paragraphs));

  /// `null` = Tự nhận (dùng [_guessed]).
  String? _source;
  String? _target;

  /// Bản dịch theo chỉ số đoạn; `null` = chưa dịch. [_failed] đánh dấu đoạn lỗi.
  late final List<String?> _results = List<String?>.filled(
    _paragraphs.length,
    null,
  );
  final Set<int> _failed = {};

  /// Số đoạn đã xử lý (từ đầu tài liệu; dịch tuần tự nên luôn là một khúc đầu liền).
  int _done = 0;

  /// Cuối lô đang dịch (để hiện tiến độ x/y).
  int _runningEnd = 0;
  CancelToken? _cancel;

  /// Messenger riêng của bảng (snackbar của Scaffold gốc bị bảng che).
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  bool get _running => _cancel != null;
  String get _effectiveSource => _source ?? _guessed;
  String get _effectiveTarget =>
      _target ??
      defaultTargetCode(
        appCode: Localizations.localeOf(context).languageCode,
        sourceCode: _effectiveSource,
      );
  bool get _sameLanguage => _effectiveSource == _effectiveTarget;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  /// Đổi ngôn ngữ → bỏ kết quả cũ.
  void _reset() {
    _results.fillRange(0, _results.length, null);
    _failed.clear();
    _done = 0;
  }

  void _setLanguages({
    String? source,
    required bool sourceAuto,
    String? target,
  }) {
    if (_running) return;
    setState(() {
      _source = sourceAuto ? null : (source ?? _source);
      // Đích chưa chọn tay thì vẫn tính lại theo nguồn mới (ngôn ngữ app, trùng thì sang en/vi).
      _target = target ?? _target;
      _reset();
    });
  }

  void _swap() {
    if (_running) return;
    final src = _effectiveSource, tgt = _effectiveTarget;
    _setLanguages(source: tgt, sourceAuto: false, target: src);
  }

  Future<void> _pickSource() {
    final l = context.l10n;
    return showChoiceSheet<String?>(
      context,
      title: l.translate_source,
      options: [
        (
          null,
          l.translate_autoDetected(translateLanguageName(context, _guessed)),
          const ValueKey('translate_src_auto'),
        ),
        for (final code in kTranslateLanguageCodes)
          (
            code,
            translateLanguageName(context, code),
            ValueKey('translate_src_$code'),
          ),
      ],
      current: _source,
      onSelect: (code) => _setLanguages(source: code, sourceAuto: code == null),
    );
  }

  Future<void> _pickTarget() {
    final l = context.l10n;
    return showChoiceSheet<String>(
      context,
      title: l.translate_target,
      options: [
        for (final code in kTranslateLanguageCodes)
          (
            code,
            translateLanguageName(context, code),
            ValueKey('translate_tgt_$code'),
          ),
      ],
      current: _effectiveTarget,
      onSelect: (code) =>
          _setLanguages(sourceAuto: _source == null, target: code),
    );
  }

  /// Dịch tuần tự từ đoạn [_done] tới hết lô chứa nó (lô [kTranslateBatchSize] đoạn).
  /// Dừng giữa chừng rồi bấm lại thì dịch tiếp phần còn lại của lô. Hết lô mà còn đoạn → hỏi
  /// có dịch tiếp không. Luôn đóng bộ dịch khi xong.
  Future<void> _translate() async {
    if (_running || _sameLanguage || _done >= _paragraphs.length) return;
    final engine = ref.read(translatorEngineProvider);
    final src = _effectiveSource, tgt = _effectiveTarget;
    final ready = await ensureTranslateModels(context, engine, [src, tgt]);
    if (!ready || !mounted || _running) return;

    final start = _done;
    final batchIndex = start ~/ kTranslateBatchSize;
    final end = batchIndex * kTranslateBatchSize + _batches[batchIndex].length;
    final token = CancelToken();
    setState(() {
      _cancel = token;
      _runningEnd = end;
    });

    TranslatorSession? session;
    try {
      session = engine.open(source: src, target: tgt);
      for (var i = start; i < end; i++) {
        if (token.isCancelled) break;
        String? text;
        try {
          text = await session.translate(_paragraphs[i]);
        } catch (_) {
          text = null; // Lỗi một đoạn: đánh dấu, dịch tiếp đoạn sau.
        }
        if (token.isCancelled || !mounted) break;
        setState(() {
          _results[i] = text;
          if (text == null) _failed.add(i);
          _done = i + 1;
        });
      }
    } catch (_) {
      // Không mở được bộ dịch: đánh dấu phần còn lại của lô là lỗi để người dùng thấy.
      if (mounted && !token.isCancelled) {
        setState(() {
          for (var i = _done; i < end; i++) {
            _failed.add(i);
          }
          _done = end;
        });
      }
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
    if (!mounted) return;
    final finished = !token.isCancelled;
    if (identical(_cancel, token)) setState(() => _cancel = null);

    final remaining = _paragraphs.length - _done;
    if (finished && remaining > 0) {
      final l = context.l10n;
      final more = await showConfirmDialog(
        context,
        title: l.translate_moreTitle,
        message: l.translate_moreMessage(_done, remaining),
        confirmLabel: l.translate_continue,
      );
      if (more && mounted) await _translate();
    }
  }

  void _stop() {
    _cancel?.cancel();
    setState(() => _cancel = null);
  }

  String _allTranslations() => [
    for (var i = 0; i < _done; i++)
      if (_results[i] != null) _results[i]!,
  ].join('\n\n');

  Future<void> _copyAll() async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: _allTranslations()));
    if (!mounted) return;
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.translate_copied)));
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _allTranslations(),
          sharePositionOrigin: defaultShareOrigin(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.core_errorUnknown)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Messenger riêng để snackbar hiện trên bảng (không bị bảng che).
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(builder: _buildBody),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(
        children: [
          Expanded(child: SheetTitle(l.translate_title)),
          IconButton(
            key: const ValueKey('translate_models'),
            tooltip: l.translate_models,
            icon: Icon(
              Symbols.download_for_offline_rounded,
              color: t.textMuted,
            ),
            onPressed: () => openTranslateModelsScreen(context),
          ),
          IconButton(
            tooltip: l.core_close,
            icon: Icon(Symbols.close_rounded, color: t.textMuted),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
    if (_paragraphs.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: EmptyState(
              icon: Symbols.translate_rounded,
              title: l.translate_empty,
              message: l.translate_emptyHint,
            ),
          ),
        ],
      );
    }

    final hasResults = _done > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _LanguageButton(
                  key: const ValueKey('translate_source'),
                  label: l.translate_source,
                  value: _source == null
                      ? l.translate_autoDetected(
                          translateLanguageName(context, _guessed),
                        )
                      : translateLanguageName(context, _source!),
                  onTap: _running ? null : _pickSource,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: IconButton.filledTonal(
                  key: const ValueKey('translate_swap'),
                  tooltip: l.translate_swap,
                  icon: const Icon(Symbols.swap_horiz_rounded),
                  onPressed: _running ? null : _swap,
                ),
              ),
              Expanded(
                child: _LanguageButton(
                  key: const ValueKey('translate_target'),
                  label: l.translate_target,
                  value: translateLanguageName(context, _effectiveTarget),
                  onTap: _running ? null : _pickTarget,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Text(
            _sameLanguage
                ? l.translate_sameLanguage
                : l.translate_paragraphCount(_paragraphs.length),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _sameLanguage ? t.primaryText : t.textMuted,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemCount: _paragraphs.length,
            itemBuilder: (context, i) => _ParagraphCard(
              key: ValueKey('translate_item_$i'),
              original: _paragraphs[i],
              translation: _results[i],
              failed: _failed.contains(i),
              pending: _running && i == _done,
            ),
          ),
        ),
        _BottomBar(
          running: _running,
          progressText: l.translate_progress(_done, _runningEnd),
          progress: _runningEnd == 0 ? null : _done / _runningEnd,
          hasResults: hasResults,
          canStart: !_sameLanguage,
          remaining: _paragraphs.length - _done,
          onStart: _translate,
          onStop: _stop,
          onResume: _translate,
          onCopy: _copyAll,
          onShare: _share,
        ),
      ],
    );
  }
}

/// Nút chọn ngôn ngữ: nhãn nhỏ (Từ / Sang) + tên ngôn ngữ + mũi tên.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.expand_more_rounded, size: 20, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một đoạn: chữ gốc mờ nhỏ ở trên, bản dịch ở dưới.
class _ParagraphCard extends StatelessWidget {
  const _ParagraphCard({
    super.key,
    required this.original,
    required this.translation,
    required this.failed,
    required this.pending,
  });

  final String original;
  final String? translation;
  final bool failed;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              original,
              style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
            ),
            if (translation != null) ...[
              const SizedBox(height: 8),
              Text(
                translation!,
                style: TextStyle(fontSize: 15, height: 1.45, color: t.text),
              ),
            ] else if (failed) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.translate_paragraphFailed,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: t.primaryText,
                ),
              ),
            ] else if (pending) ...[
              const SizedBox(height: 8),
              Text('…', style: TextStyle(fontSize: 15, color: t.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thanh dưới: Dịch / (đang dịch: tiến độ + Dừng) / (xong: Dịch tiếp?, Chép tất cả, Chia sẻ).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.running,
    required this.progressText,
    required this.progress,
    required this.hasResults,
    required this.canStart,
    required this.remaining,
    required this.onStart,
    required this.onStop,
    required this.onResume,
    required this.onCopy,
    required this.onShare,
  });

  final bool running;
  final String progressText;
  final double? progress;
  final bool hasResults;
  final bool canStart;
  final int remaining;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onResume;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    const buttonSize = Size(64, 48);
    final Widget content;
    if (running) {
      content = Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            key: const ValueKey('translate_stop'),
            style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            onPressed: onStop,
            icon: const Icon(Symbols.stop_rounded),
            label: Text(l.translate_stop),
          ),
        ],
      );
    } else if (!hasResults) {
      content = FilledButton.icon(
        key: const ValueKey('translate_start'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: canStart ? onStart : null,
        icon: const Icon(Symbols.translate_rounded),
        label: Text(l.translate_start),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (remaining > 0) ...[
            TextButton.icon(
              key: const ValueKey('translate_continue'),
              onPressed: onResume,
              icon: const Icon(Symbols.translate_rounded),
              label: Text(l.translate_continueButton(remaining)),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('translate_copy_all'),
                  style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                  onPressed: onCopy,
                  icon: const Icon(Symbols.content_copy_rounded),
                  label: Text(
                    l.translate_copyAll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('translate_share'),
                  style: FilledButton.styleFrom(minimumSize: buttonSize),
                  onPressed: onShare,
                  icon: const Icon(Symbols.share_rounded),
                  label: Text(
                    l.core_share,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: content,
        ),
      ),
    );
  }
}
