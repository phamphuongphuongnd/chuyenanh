import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translate_languages.dart';

/// Lỗi tải gói dịch (thường do không có mạng).
class TranslateModelDownloadFailed implements Exception {
  const TranslateModelDownloadFailed(this.code, [this.cause]);

  /// Mã ngôn ngữ của gói (vi, en…).
  final String code;
  final Object? cause;

  @override
  String toString() => 'TranslateModelDownloadFailed($code, $cause)';
}

/// Phiên dịch một chiều (nguồn → đích). Dùng xong phải [close] để giải phóng bộ dịch.
abstract class TranslatorSession {
  Future<String> translate(String text);
  Future<void> close();
}

/// Bộ dịch trên máy + quản lý gói ngôn ngữ. Mã ngôn ngữ là mã app (vi, en, zh, ja, ko, id).
/// Test thay bằng bản giả qua `translatorEngineProvider`.
abstract class TranslatorEngine {
  Future<bool> isModelDownloaded(String code);

  /// Tải gói (cần mạng một lần). Lỗi → [TranslateModelDownloadFailed].
  Future<void> downloadModel(String code);

  Future<void> deleteModel(String code);

  /// Mở phiên dịch; gói của cả hai ngôn ngữ phải đã có trên máy.
  TranslatorSession open({required String source, required String target});
}

/// Cài đặt bằng ML Kit (`OnDeviceTranslator`, `OnDeviceTranslatorModelManager`).
class MlKitTranslatorEngine implements TranslatorEngine {
  MlKitTranslatorEngine({OnDeviceTranslatorModelManager? modelManager})
    : _models = modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _models;

  static TranslateLanguage _lang(String code) =>
      translateLanguageFor(code) ??
      (throw ArgumentError.value(code, 'code', 'ngôn ngữ không hỗ trợ'));

  @override
  Future<bool> isModelDownloaded(String code) =>
      _models.isModelDownloaded(_lang(code).bcpCode);

  @override
  Future<void> downloadModel(String code) async {
    final bool ok;
    try {
      // Cho tải cả bằng dữ liệu di động: chỉ cần mạng một lần.
      ok = await _models.downloadModel(
        _lang(code).bcpCode,
        isWifiRequired: false,
      );
    } on PlatformException catch (e) {
      throw TranslateModelDownloadFailed(code, e);
    }
    if (!ok) throw TranslateModelDownloadFailed(code);
  }

  @override
  Future<void> deleteModel(String code) async {
    await _models.deleteModel(_lang(code).bcpCode);
  }

  @override
  TranslatorSession open({required String source, required String target}) =>
      _MlKitSession(
        OnDeviceTranslator(
          sourceLanguage: _lang(source),
          targetLanguage: _lang(target),
        ),
      );
}

class _MlKitSession implements TranslatorSession {
  _MlKitSession(this._translator);

  final OnDeviceTranslator _translator;
  bool _closed = false;

  @override
  Future<String> translate(String text) => _translator.translateText(text);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _translator.close();
  }
}
