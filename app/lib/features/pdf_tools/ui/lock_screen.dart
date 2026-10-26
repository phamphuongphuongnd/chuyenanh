import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_security.dart';
import '../logic/tool_rules.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Đặt mật khẩu cho PDF (AES-256), lưu thành file mới `<tên>_locked.pdf`.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SinglePdfToolState<LockScreen> {
  final _pwCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _obscure = true;
  PasswordIssue? _issue;

  @override
  String? get initialPath => widget.path;

  @override
  void dispose() {
    _pwCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _lock() async {
    final src = input;
    if (src == null) return;
    final issue = validateNewPassword(_pwCtl.text, _confirmCtl.text);
    setState(() => _issue = issue);
    if (issue != null) return;
    final password = _pwCtl.text;
    final out = await newOutputPath(ref, suffixedName(src.path, 'locked'));
    if (!mounted) return;
    final security = ref.read(pdfSecurityProvider);
    final saved = await runToolJob<String>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) async {
        onProgress(0.05);
        var bytes = await File(src.path).readAsBytes();
        token.throwIfCancelled();
        // File đã có mật khẩu cũ (đã nhập khi mở): gỡ trước rồi đặt mật khẩu mới.
        final oldPassword = src.password;
        if (oldPassword != null) {
          bytes = await security.decrypt(bytes, oldPassword);
          token.throwIfCancelled();
        }
        onProgress(0.4);
        final Uint8List locked = await security.encrypt(bytes, password);
        token.throwIfCancelled();
        onProgress(0.9);
        await writeAtomically(out, locked);
        return out;
      },
    );
    if (saved == null || !mounted) return;
    await finish([saved]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolLock;
    final res = results;
    if (res != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: res, onDone: () => context.pop()),
      );
    }
    final src = input;
    if (src == null) {
      return ToolScaffold(
        title: title,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: pickNew),
      );
    }
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          Text(l.tools_lockHint),
          const SizedBox(height: 12),
          AppTextField(
            controller: _pwCtl,
            obscureText: _obscure,
            hintText: l.core_password,
            suffixIcon: toggle,
            textInputAction: TextInputAction.next,
            errorText: _issue == PasswordIssue.empty ? l.tools_passwordEmpty : null,
            onChanged: (_) {
              if (_issue != null) setState(() => _issue = null);
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _confirmCtl,
            obscureText: _obscure,
            hintText: l.tools_confirmPassword,
            textInputAction: TextInputAction.done,
            errorText: _issue == PasswordIssue.mismatch
                ? l.tools_passwordMismatch
                : null,
            onChanged: (_) {
              if (_issue != null) setState(() => _issue = null);
            },
            onSubmitted: (_) => _lock(),
          ),
          const SizedBox(height: 16),
          NoteBanner(l.tools_lockWarning, icon: Icons.warning_amber_outlined),
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.tools_lockAction,
        icon: Icons.lock_outline,
        onPressed: _lock,
      ),
    );
  }
}
