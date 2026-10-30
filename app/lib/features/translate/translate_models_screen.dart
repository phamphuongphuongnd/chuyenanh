import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'translate_download.dart';
import 'translate_languages.dart';
import 'translate_providers.dart';

/// Mở màn "Gói dịch đã tải" (đẩy thẳng lên navigator gốc, không cần route riêng).
Future<void> openTranslateModelsScreen(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const TranslateModelsScreen()));

/// Màn quản lý gói dịch: 6 ngôn ngữ, trạng thái đã tải / chưa tải; tải hoặc xoá từng gói.
/// Gói tiếng Anh có sẵn trong ML Kit, không xoá được.
class TranslateModelsScreen extends ConsumerStatefulWidget {
  const TranslateModelsScreen({super.key});

  @override
  ConsumerState<TranslateModelsScreen> createState() =>
      _TranslateModelsScreenState();
}

class _TranslateModelsScreenState extends ConsumerState<TranslateModelsScreen> {
  /// mã → đã tải? (`null` = đang kiểm tra / lỗi).
  Map<String, bool>? _status;
  bool _failed = false;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final engine = ref.read(translatorEngineProvider);
    try {
      final status = <String, bool>{
        for (final code in kTranslateLanguageCodes)
          code: await engine.isModelDownloaded(code),
      };
      if (mounted) {
        setState(() {
          _status = status;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _download(String code) async {
    setState(() => _busy = code);
    await ensureTranslateModels(context, ref.read(translatorEngineProvider), [
      code,
    ]);
    if (!mounted) return;
    setState(() => _busy = null);
    await _load();
  }

  Future<void> _delete(String code) async {
    final l = context.l10n;
    final name = translateLanguageName(context, code);
    final ok = await showConfirmDialog(
      context,
      title: l.translate_deleteModelTitle(name),
      message: l.translate_deleteModelMessage(name, kTranslateModelSizeMb),
      confirmLabel: l.core_delete,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = code);
    try {
      await ref.read(translatorEngineProvider).deleteModel(code);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.translate_modelDeleted)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.core_errorUnknown)));
      }
    }
    if (!mounted) return;
    setState(() => _busy = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: Text(l.translate_models)),
      body: _failed
          ? EmptyState(
              icon: Symbols.error_rounded,
              title: l.translate_checkFailed,
              actionLabel: l.core_retry,
              onAction: () {
                setState(() => _failed = false);
                _load();
              },
            )
          : status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(
                    l.translate_modelsHint(kTranslateModelSizeMb),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: t.textMuted,
                    ),
                  ),
                ),
                CardSection(
                  children: [
                    for (final code in kTranslateLanguageCodes)
                      _ModelTile(
                        key: ValueKey('translate_model_$code'),
                        code: code,
                        downloaded: status[code] ?? false,
                        busy: _busy == code,
                        enabled: _busy == null,
                        onDownload: () => _download(code),
                        onDelete: () => _delete(code),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    super.key,
    required this.code,
    required this.downloaded,
    required this.busy,
    required this.enabled,
    required this.onDownload,
    required this.onDelete,
  });

  final String code;
  final bool downloaded;
  final bool busy;
  final bool enabled;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final builtIn = code == kBuiltInModelCode;
    final subtitle = builtIn
        ? l.translate_modelBuiltIn
        : downloaded
        ? l.translate_modelDownloaded
        : l.translate_modelNotDownloaded;
    final Widget? trailing = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : builtIn
        ? null
        : downloaded
        ? IconButton(
            key: ValueKey('translate_delete_$code'),
            tooltip: l.core_delete,
            icon: Icon(Symbols.delete_rounded, color: t.textMuted),
            onPressed: enabled ? onDelete : null,
          )
        : IconButton(
            key: ValueKey('translate_download_$code'),
            tooltip: l.translate_download,
            icon: Icon(Symbols.download_rounded, color: t.primaryText),
            onPressed: enabled ? onDownload : null,
          );
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: Icon(
        downloaded || builtIn
            ? Symbols.offline_pin_rounded
            : Symbols.cloud_download_rounded,
        color: downloaded || builtIn ? t.primaryText : t.textMuted,
      ),
      title: Text(
        translateLanguageName(context, code),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: t.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: t.textMuted),
      ),
      trailing: trailing,
    );
  }
}
