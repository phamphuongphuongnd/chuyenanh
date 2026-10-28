import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_security.dart';
import '../logic/tool_rules.dart';
import 'pdf_pick_screen.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Gỡ mật khẩu PDF (cần mật khẩu đúng), lưu thành file mới `<tên>_unlocked.pdf`.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String? _path;
  int? _size;
  bool? _locked;
  bool _checking = false;
  bool _obscure = true;
  String? _error;
  List<String>? _results;
  final _pwCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final path = widget.path;
      if (path != null) {
        await _check(path);
      } else {
        await _pick();
      }
    });
  }

  @override
  void dispose() {
    _pwCtl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await ref.read(inAppPdfPickerProvider)(
      context,
      PdfPickMode.lockedOnly,
    );
    if (!mounted || path == null) return;
    await _check(path);
  }

  Future<void> _check(String path) async {
    setState(() => _checking = true);
    try {
      final bytes = await File(path).readAsBytes();
      final locked = await ref.read(pdfSecurityProvider).isEncrypted(bytes);
      if (!mounted) return;
      setState(() {
        _path = path;
        _size = bytes.length;
        _locked = locked;
        _error = null;
        _pwCtl.clear();
      });
    } catch (e) {
      if (mounted) showToolError(context, e is AppError ? e : CorruptFile('$e'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _unlock() async {
    final path = _path;
    if (path == null) return;
    final password = _pwCtl.text;
    if (password.isEmpty) {
      setState(() => _error = context.l10n.tools_passwordEmpty);
      return;
    }
    final out = await newOutputPath(ref, suffixedName(path, 'unlocked'));
    if (!mounted) return;
    final security = ref.read(pdfSecurityProvider);
    final wrongText = context.l10n.core_errorWrongPassword;
    var wrongPassword = false;
    final saved = await runToolJob<String?>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) async {
        onProgress(0.1);
        final bytes = await File(path).readAsBytes();
        token.throwIfCancelled();
        final Uint8List plain;
        try {
          plain = await security.decrypt(bytes, password);
        } on WrongPassword {
          wrongPassword = true;
          return null;
        }
        token.throwIfCancelled();
        onProgress(0.8);
        await writeAtomically(out, plain);
        return out;
      },
    );
    if (!mounted) return;
    if (saved == null) {
      // Sai mật khẩu: hiện ngay dưới ô nhập thay vì chỉ SnackBar.
      if (wrongPassword) setState(() => _error = wrongText);
      return;
    }
    await registerOutputs(ref, [saved]);
    if (mounted) setState(() => _results = [saved]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolUnlock;
    final results = _results;
    if (results != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: results, onDone: () => context.pop()),
      );
    }
    final path = _path;
    if (path == null) {
      return ToolScaffold(
        title: title,
        body: _checking
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: _pick),
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final card = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: FileTypeIcon.forPath(path, locked: _locked ?? false),
        title: Text(p.basename(path), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: _size == null ? null : Text(formatFileSize(_size!, locale)),
        trailing: TextButton(onPressed: _pick, child: Text(l.tools_changeFile)),
      ),
    );
    if (_locked == false) {
      return ToolScaffold(
        title: title,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            card,
            const SizedBox(height: 16),
            NoteBanner(l.tools_unlockNotLocked),
          ],
        ),
      );
    }
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card,
          const SizedBox(height: 16),
          Text(l.tools_unlockHint),
          const SizedBox(height: 12),
          AppTextField(
            controller: _pwCtl,
            obscureText: _obscure,
            hintText: l.core_password,
            errorText: _error,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _unlock(),
          ),
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.tools_unlockAction,
        icon: Icons.lock_open_outlined,
        onPressed: _unlock,
      ),
    );
  }
}
