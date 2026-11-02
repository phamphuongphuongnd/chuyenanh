import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_logic.dart';

/// Lớp mỏng quanh giọng đọc của máy — tách ra để test thay bằng bản giả
/// (override [ttsEngineProvider]). Không dùng mạng.
abstract class TtsEngine {
  /// Đọc xong tự nhiên một lần [speak] (không gọi khi bị [stop]).
  VoidCallback? onComplete;

  /// Engine báo lỗi khi đang đọc.
  ValueChanged<String>? onError;

  /// Vị trí từ đang đọc trong chuỗi vừa [speak] (Android 8+, iOS). Có thể không bao giờ gọi.
  void Function(int start, int end)? onProgress;

  /// Máy có giọng (đã cài) cho [locale] (`vi-VN`)?
  Future<bool> isLanguageAvailable(String locale);

  Future<void> setLanguage(String locale);

  /// Tên (gói) các bộ đọc đã cài trên máy (Android; nơi khác rỗng).
  Future<List<String>> engines();

  /// Bộ đọc đang dùng (mặc định của máy, hoặc bộ đã [useEngine]); `null` nếu không biết.
  Future<String?> currentEngine();

  /// Chuyển bộ đọc cho phiên của app (không đổi mặc định của hệ thống).
  Future<void> useEngine(String engine);

  /// Giọng dùng được cho [locale] (đã lọc, chỉ giọng offline).
  Future<List<TtsVoice>> voicesFor(String locale);

  /// `null` = giọng mặc định của ngôn ngữ.
  Future<void> setVoice(TtsVoice? voice, String locale);

  /// [speed]: 1.0 = bình thường (0.5–2).
  Future<void> setSpeed(double speed);

  /// Bắt đầu đọc [text] (≤ [kTtsMaxChunkLength]); trả về khi đã bắt đầu, không chờ đọc xong.
  Future<void> speak(String text);

  Future<void> stop();

  /// Gỡ callback; engine dùng chung nên không huỷ hẳn.
  void detach() {
    onComplete = null;
    onError = null;
    onProgress = null;
  }
}

/// Cài đặt bằng gói `flutter_tts` (Android TextToSpeech / iOS AVSpeechSynthesizer).
/// Lỗi kênh nền tảng (vd. chạy trong test không có plugin) được nuốt; riêng lỗi [speak] báo qua [onError].
class FlutterTtsEngine extends TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((msg) => onError?.call('$msg'));
    _tts.setProgressHandler(
      (text, start, end, word) => onProgress?.call(start, end),
    );
    _init();
  }

  final FlutterTts _tts;
  String? _current;

  Future<void> _init() async {
    await _guard(() async {
      await _tts.awaitSpeakCompletion(false);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Đọc được cả khi gạt im lặng; hạ tiếng app khác thay vì cắt.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ]);
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setQueueMode(0); // QUEUE_FLUSH: lần đọc mới thay lần cũ.
      }
    });
  }

  static Future<T?> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('TTS: $e');
      return null;
    }
  }

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final r = await _guard(() => _tts.isLanguageAvailable(locale));
    return r == true || r == 1;
  }

  @override
  Future<void> setLanguage(String locale) =>
      _guard(() => _tts.setLanguage(locale));

  @override
  Future<List<String>> engines() async {
    final r = await _guard<dynamic>(() => _tts.getEngines);
    return r is List ? [for (final e in r) '$e'] : const [];
  }

  @override
  Future<String?> currentEngine() async {
    if (_current != null) return _current;
    final r = await _guard<dynamic>(() => _tts.getDefaultEngine);
    return _current = r?.toString();
  }

  @override
  Future<void> useEngine(String engine) async {
    await _guard(() => _tts.setEngine(engine));
    _current = engine;
  }

  @override
  Future<List<TtsVoice>> voicesFor(String locale) async =>
      filterVoices(await _guard<dynamic>(() => _tts.getVoices), locale);

  @override
  Future<void> setVoice(TtsVoice? voice, String locale) => _guard(() async {
    if (voice == null) {
      await _tts.clearVoice();
      await _tts.setLanguage(locale);
    } else {
      await _tts.setVoice(voice.toMap());
    }
  });

  @override
  Future<void> setSpeed(double speed) =>
      _guard(() => _tts.setSpeechRate(ttsEngineRate(speed)));

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      // Không nuốt: báo lên controller để thoát trạng thái đang đọc.
      debugPrint('TTS: $e');
      onError?.call('$e');
    }
  }

  @override
  Future<void> stop() => _guard(() => _tts.stop());
}

/// Engine giọng đọc dùng chung. Test: `ttsEngineProvider.overrideWithValue(FakeTtsEngine())`.
final ttsEngineProvider = Provider<TtsEngine>((ref) => FlutterTtsEngine());
