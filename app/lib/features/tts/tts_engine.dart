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
/// Mọi lỗi kênh nền tảng (vd. chạy trong test không có plugin) đều được nuốt.
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
  Future<void> speak(String text) => _guard(() => _tts.speak(text));

  @override
  Future<void> stop() => _guard(() => _tts.stop());
}

/// Engine giọng đọc dùng chung. Test: `ttsEngineProvider.overrideWithValue(FakeTtsEngine())`.
final ttsEngineProvider = Provider<TtsEngine>((ref) => FlutterTtsEngine());
