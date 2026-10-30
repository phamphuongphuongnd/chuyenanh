import 'package:pdf_office/features/tts/tts_engine.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

/// Engine giả: ghi lại lời gọi, [finish] giả lập đọc xong một lần.
class FakeTtsEngine extends TtsEngine {
  FakeTtsEngine({this.available = true, this.voices = const []});

  bool available;
  List<TtsVoice> voices;

  final checked = <String>[];
  final languages = <String>[];
  final spoken = <String>[];
  final voiceSet = <TtsVoice?>[];
  double? speed;
  int stops = 0;

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    checked.add(locale);
    return available;
  }

  @override
  Future<void> setLanguage(String locale) async => languages.add(locale);

  @override
  Future<List<TtsVoice>> voicesFor(String locale) async => voices;

  @override
  Future<void> setVoice(TtsVoice? voice, String locale) async =>
      voiceSet.add(voice);

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  /// Giả lập engine đọc xong câu vừa [speak].
  void finish() => onComplete?.call();
}
