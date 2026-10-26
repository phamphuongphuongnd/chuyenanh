import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/navigation/open_document.dart';
import '../../core/utils/file_paths.dart';
import '../../core/utils/output_directory.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import '../../engines/convert/convert_engine.dart';
import '../../engines/ocr/ocr_engine.dart';
import 'convert_providers.dart';
import 'engine/pdf_convert_engine.dart' show isNoTextError;
import 'text/text_decoder.dart';

/// Sáu kiểu chuyển đổi của feature (mỗi kiểu một route).
enum ConvertMode {
  textToPdf(['txt'], 'pdf'),
  wordToPdf(['docx'], 'pdf'),
  excelToPdf(['xlsx'], 'pdf'),
  pdfToText(['pdf'], 'txt'),
  pdfToWord(['pdf'], 'docx'),
  pdfToExcel(['pdf'], 'xlsx');

  const ConvertMode(this.inputExtensions, this.outputExtension);
  final List<String> inputExtensions;
  final String outputExtension;

  bool get toPdf => outputExtension == 'pdf';
  bool get fromPdf => inputExtensions.single == 'pdf';

  /// PDF → Word/Excel: cảnh báo không giữ bố cục.
  bool get rebuildsLayout => this == pdfToWord || this == pdfToExcel;
}

String _modeTitle(BuildContext context, ConvertMode mode) {
  final l = context.l10n;
  return switch (mode) {
    ConvertMode.textToPdf => l.conv_textToPdf,
    ConvertMode.wordToPdf => l.conv_wordToPdf,
    ConvertMode.excelToPdf => l.conv_excelToPdf,
    ConvertMode.pdfToText => l.conv_pdfToText,
    ConvertMode.pdfToWord => l.conv_pdfToWord,
    ConvertMode.pdfToExcel => l.conv_pdfToExcel,
  };
}

class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key, required this.mode, this.initialPath});

  final ConvertMode mode;
  final String? initialPath;

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  final _text = TextEditingController();
  String? _inputPath;
  String? _resultPath;
  PageSizeOption? _pageSize;
  bool _landscape = false;
  double _fontSize = 12;
  double _margin = 40;
  bool _busy = false;
  OcrScript? _ocrScript;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPath;
    if (initial != null) {
      if (widget.mode == ConvertMode.textToPdf) {
        _loadTxt(initial);
      } else {
        _inputPath = initial;
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadTxt(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _text.text = decodeTextBytes(bytes);
        _inputPath = path;
      });
    } catch (e) {
      _showError(AppError.from(e));
    }
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: widget.mode.inputExtensions,
    );
    final path = file?.path;
    if (path == null || !mounted) return;
    if (widget.mode == ConvertMode.textToPdf) {
      await _loadTxt(path);
    } else {
      setState(() {
        _inputPath = path;
        _resultPath = null;
      });
    }
  }

  void _showError(AppError e) {
    if (!mounted || e is Cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appErrorMessage(context, e))),
    );
  }

  ToPdfOptions get _options => ToPdfOptions(
        pageSize: _pageSize ?? ref.read(settingsProvider).defaultPageSize,
        landscape: _landscape,
        fontSize: _fontSize,
        marginPoints: _margin,
      );

  Future<void> _convert() async {
    final mode = widget.mode;
    final l = context.l10n;
    if (mode == ConvertMode.textToPdf && _text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.conv_emptyText)));
      return;
    }
    if (mode != ConvertMode.textToPdf && _inputPath == null) {
      await _pick();
      if (_inputPath == null) return;
    }
    setState(() {
      _busy = true;
      _resultPath = null;
    });
    if (mode.fromPdf) {
      ref.read(convertOcrScriptProvider.notifier).set(_ocrScript ?? _defaultOcrScript());
    }
    final engine = ref.read(convertEngineProvider);
    try {
      final dir = await ref.read(outputDirectoryProvider.future);
      final base = _inputPath != null
          ? baseNameWithoutExtension(_inputPath!)
          : 'Text';
      final out = await uniqueOutputPath(dir, base, mode.outputExtension);
      String? password;
      String? wrongHint;
      while (true) {
        if (!mounted) return;
        final progress = showProgressDialog(context, title: l.core_processing);
        try {
          final result = await _run(engine, mode, out, password, progress);
          progress.close();
          if (!mounted) return;
          setState(() => _resultPath = result);
          return;
        } on PasswordRequired {
          progress.close();
        } on WrongPassword {
          progress.close();
          wrongHint = l.core_errorWrongPassword;
        }
        if (!mounted) return;
        password = await showPasswordDialog(
          context,
          message: l.core_passwordDialogMessage(p.basename(_inputPath!)),
          errorText: wrongHint,
        );
        if (password == null) return;
      }
    } on AppError catch (e) {
      _handle(e);
    } catch (e) {
      _handle(AppError.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  OcrScript _defaultOcrScript() => ocrScriptForLanguage(
        (ref.read(settingsProvider).locale ?? Localizations.localeOf(context)).languageCode,
      );

  String _scriptName(OcrScript s) {
    final l = context.l10n;
    return switch (s) {
      OcrScript.latin => l.conv_scriptLatin,
      OcrScript.chinese => l.conv_scriptChinese,
      OcrScript.japanese => l.conv_scriptJapanese,
      OcrScript.korean => l.conv_scriptKorean,
    };
  }

  void _handle(AppError e) {
    if (!mounted) return;
    if (isNoTextError(e)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.conv_noTextFound)));
    } else {
      _showError(e);
    }
  }

  Future<String> _run(
    ConvertEngine engine,
    ConvertMode mode,
    String out,
    String? password,
    ProgressDialogController progress,
  ) {
    void onProgress(double v) => progress.update(v);
    final token = progress.cancelToken;
    switch (mode) {
      case ConvertMode.textToPdf:
        return engine.textToPdf(_text.text, out,
            options: _options, onProgress: onProgress, cancelToken: token);
      case ConvertMode.wordToPdf:
        return engine.docxToPdf(_inputPath!, out,
            options: _options, onProgress: onProgress, cancelToken: token);
      case ConvertMode.excelToPdf:
        return engine.xlsxToPdf(_inputPath!, out,
            options: _options, onProgress: onProgress, cancelToken: token);
      case ConvertMode.pdfToText:
        return engine.pdfToText(_inputPath!, out,
            password: password, onProgress: onProgress, cancelToken: token);
      case ConvertMode.pdfToWord:
        return engine.pdfToDocx(_inputPath!, out,
            password: password, onProgress: onProgress, cancelToken: token);
      case ConvertMode.pdfToExcel:
        return engine.pdfToXlsx(_inputPath!, out,
            password: password, onProgress: onProgress, cancelToken: token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = widget.mode;
    final theme = Theme.of(context);
    final pageSize = _pageSize ?? ref.watch(settingsProvider).defaultPageSize;
    return Scaffold(
      appBar: AppBar(title: Text(_modeTitle(context, mode))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode == ConvertMode.textToPdf) ...[
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 14,
              decoration: InputDecoration(
                hintText: l.conv_textHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.description_outlined),
                label: Text(l.conv_loadTxt),
              ),
            ),
          ] else ...[
            Card(
              child: ListTile(
                leading: FileTypeIcon.forPath(_inputPath ?? 'x.${mode.inputExtensions.single}'),
                title: Text(
                  _inputPath == null ? l.conv_chooseFile : l.conv_chosenFile(p.basename(_inputPath!)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.folder_open),
                onTap: _busy ? null : _pick,
              ),
            ),
          ],
          if (mode.rebuildsLayout) ...[
            const SizedBox(height: 12),
            _Notice(text: l.conv_layoutNotice),
          ],
          if (mode.fromPdf) ...[
            const SizedBox(height: 12),
            _Notice(text: l.conv_ocrNotice),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.conv_ocrLanguage)),
                const SizedBox(width: 8),
                DropdownButton<OcrScript>(
                  value: _ocrScript ?? _defaultOcrScript(),
                  isDense: true,
                  items: [
                    for (final s in OcrScript.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(_scriptName(s), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _busy ? null : (s) => setState(() => _ocrScript = s),
                ),
              ],
            ),
          ],
          if (mode.toPdf) ...[
            const SizedBox(height: 16),
            Text(l.conv_options, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.conv_pageSize)),
                SegmentedButton<PageSizeOption>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: PageSizeOption.a4, label: Text('A4')),
                    ButtonSegment(value: PageSizeOption.letter, label: Text('Letter')),
                  ],
                  selected: {pageSize == PageSizeOption.letter ? PageSizeOption.letter : PageSizeOption.a4},
                  onSelectionChanged: (s) => setState(() => _pageSize = s.single),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.conv_orientation)),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(l.conv_portrait)),
                    ButtonSegment(value: true, label: Text(l.conv_landscape)),
                  ],
                  selected: {_landscape},
                  onSelectionChanged: (s) => setState(() => _landscape = s.single),
                ),
              ],
            ),
            if (mode == ConvertMode.textToPdf)
              _SliderRow(
                label: l.conv_fontSize,
                value: _fontSize,
                min: 8,
                max: 24,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            _SliderRow(
              label: l.conv_margin,
              value: _margin,
              min: 0,
              max: 72,
              onChanged: (v) => setState(() => _margin = v),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _convert,
            child: Text(l.conv_convert),
          ),
          if (_resultPath != null) ...[
            const SizedBox(height: 20),
            _ResultCard(path: _resultPath!),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text(value.round().toString(), textAlign: TextAlign.end)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canOpen = routeForDocument(path) != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(l.conv_doneTitle, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.conv_savedAs(path)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (canOpen)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      try {
                        await openDocument(context, path);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(appErrorMessage(context, AppError.from(e)))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.core_open),
                  ),
                OutlinedButton.icon(
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(files: [XFile(path)])),
                  icon: const Icon(Icons.share),
                  label: Text(l.core_share),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
