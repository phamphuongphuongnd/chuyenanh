import 'package:pdf_office/features/tts/tts_engine.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

/// Engine giả: ghi lại lời gọi, [finish] giả lập đọc xong một lần.
class FakeTtsEngine extends TtsEngine {
  FakeTtsEngine({
    this.available = true,
    this.voices = const [],
    this.installedEngines = const [],
    this.engineHasLanguage = const {},
    this.current,
  });

  bool available;

  /// Bộ đọc đã cài; [engineHasLanguage] (tên → có ngôn ngữ) thay [available] khi không rỗng.
  List<String> installedEngines;
  Map<String, bool> engineHasLanguage;
  String? current;
  final engineSwitches = <String>[];
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
    if (engineHasLanguage.isNotEmpty) return engineHasLanguage[current] ?? false;
    return available;
  }

  @override
  Future<List<String>> engines() async => installedEngines;

  @override
  Future<String?> currentEngine() async => current;

  @override
  Future<void> useEngine(String engine) async {
    engineSwitches.add(engine);
    current = engine;
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
