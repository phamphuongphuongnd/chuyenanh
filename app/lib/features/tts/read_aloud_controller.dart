import 'package:flutter/foundation.dart';

import 'tts_engine.dart';
import 'tts_logic.dart';

/// Trạng thái thanh đọc to.
enum ReadAloudStatus {
  /// Đang hỏi máy có giọng cho ngôn ngữ không.
  checking,

  /// Máy không có giọng cho ngôn ngữ này.
  unavailable,
  idle,
  playing,
  paused,
}

/// Điều khiển đọc lần lượt các đoạn bằng [TtsEngine]: phát / tạm dừng / đoạn trước–sau /
/// dừng, tốc độ, giọng. Đoạn dài được chia nhỏ ([buildTtsQueue]).
class ReadAloudController extends ChangeNotifier {
  ReadAloudController({
    required this.engine,
    required List<String> paragraphs,
    this.onParagraph,
  }) {
    _setQueue(paragraphs);
    engine
      ..onComplete = _handleComplete
      ..onError = _handleError
      ..onProgress = _handleProgress;
  }

  final TtsEngine engine;

  /// Báo đoạn bắt đầu đọc / vừa chuyển tới.
  ValueChanged<int>? onParagraph;

  List<TtsSegment> _queue = const [];
  int _paragraphCount = 0;
  int _seg = 0;

  /// Vị trí (trong phần đang đọc) để đọc tiếp sau khi tạm dừng / đổi tốc độ.
  int _offset = 0;

  /// Phần đang đọc bắt đầu từ ký tự nào của đoạn gốc (để quy đổi `onProgress`).
  int _spokenBase = 0;
  int? _announced;
  bool _disposed = false;

  ReadAloudStatus _status = ReadAloudStatus.checking;
  ReadAloudStatus get status => _status;

  String? _locale;

  /// Locale giọng đọc đang dùng (`vi-VN`).
  String? get locale => _locale;

  double _speed = 1.0;
  double get speed => _speed;

  List<TtsVoice> _voices = const [];
  List<TtsVoice> get voices => _voices;

  TtsVoice? _voice;

  /// `null` = giọng mặc định.
  TtsVoice? get voice => _voice;

  /// Lỗi engine gần nhất (UI hiện thông báo rồi gọi [clearError]).
  String? _error;
  String? get error => _error;
  void clearError() => _error = null;

  int get paragraphCount => _paragraphCount;
  bool get hasContent => _queue.isNotEmpty;

  /// Chỉ số đoạn (gốc) đang ở.
  int get currentParagraph => _queue.isEmpty ? 0 : _queue[_seg].paragraph;

  bool get isPlaying => _status == ReadAloudStatus.playing;
  bool get isReady =>
      _status == ReadAloudStatus.idle ||
      _status == ReadAloudStatus.playing ||
      _status == ReadAloudStatus.paused;

  bool get canPrev => isReady && _firstSegOf(currentParagraph) > 0;
  bool get canNext =>
      isReady && _queue.isNotEmpty && _queue.last.paragraph > currentParagraph;

  void _setQueue(List<String> paragraphs) {
    _queue = buildTtsQueue(paragraphs);
    _paragraphCount = paragraphs.length;
    _seg = 0;
    _offset = 0;
    _announced = null;
  }

  /// Danh sách đoạn đổi → dừng và về đầu.
  Future<void> setParagraphs(List<String> paragraphs) async {
    final wasActive = isPlaying;
    _setQueue(paragraphs);
    if (isReady) _status = ReadAloudStatus.idle;
    _notify();
    if (wasActive) await engine.stop();
  }

  /// Đổi ngôn ngữ: dừng, kiểm tra giọng, nạp danh sách giọng.
  Future<void> setLocale(String locale) async {
    if (_locale == locale) return;
    _locale = locale;
    if (isPlaying) await engine.stop();
    _status = ReadAloudStatus.checking;
    _voices = const [];
    _voice = null;
    _notify();
    await _checkLanguage(locale);
  }

  /// Kiểm tra lại (sau khi người dùng cài giọng).
  Future<void> recheck() async {
    final l = _locale;
    if (l == null) return;
    _status = ReadAloudStatus.checking;
    _notify();
    await _checkLanguage(l);
  }

  Future<void> _checkLanguage(String locale) async {
    final ok = await engine.isLanguageAvailable(locale);
    if (_disposed || _locale != locale) return;
    if (!ok) {
      _status = ReadAloudStatus.unavailable;
      _notify();
      return;
    }
    await engine.setLanguage(locale);
    final voices = await engine.voicesFor(locale);
    await engine.setSpeed(_speed);
    if (_disposed || _locale != locale) return;
    _voices = voices;
    _status = ReadAloudStatus.idle;
    _notify();
  }

  Future<void> play() async {
    if (!isReady || _queue.isEmpty || isPlaying) return;
    _status = ReadAloudStatus.playing;
    _notify();
    await _speakCurrent();
  }

  /// Tạm dừng; [play] đọc tiếp từ từ đang đọc (nếu engine báo tiến độ) hoặc đầu phần.
  Future<void> pause() async {
    if (!isPlaying) return;
    _status = ReadAloudStatus.paused;
    _notify();
    await engine.stop();
  }

  Future<void> togglePlay() => isPlaying ? pause() : play();

  /// Dừng hẳn; lần phát sau đọc lại từ đầu đoạn hiện tại.
  Future<void> stop() async {
    if (!isReady) return;
    final wasPlaying = isPlaying;
    _seg = _firstSegOf(currentParagraph);
    _offset = 0;
    _announced = null;
    _status = ReadAloudStatus.idle;
    _notify();
    if (wasPlaying) await engine.stop();
  }

  Future<void> next() async {
    if (!canNext) return;
    await _jumpTo(_firstSegOf(currentParagraph + 1, forward: true));
  }

  Future<void> previous() async {
    if (!canPrev) return;
    final prevPara = _queue[_firstSegOf(currentParagraph) - 1].paragraph;
    await _jumpTo(_firstSegOf(prevPara));
  }

  Future<void> setSpeed(double speed) async {
    if (speed == _speed) return;
    _speed = speed;
    _notify();
    await engine.setSpeed(speed);
    await _restartIfPlaying();
  }

  Future<void> setVoice(TtsVoice? voice) async {
    if (voice == _voice) return;
    _voice = voice;
    _notify();
    final l = _locale;
    if (l != null) await engine.setVoice(voice, l);
    await _restartIfPlaying();
  }

  /// Engine chỉ áp tốc độ/giọng cho lần đọc sau → đọc lại từ từ đang đọc.
  Future<void> _restartIfPlaying() async {
    if (!isPlaying) return;
    await engine.stop();
    if (isPlaying) await _speakCurrent();
  }

  Future<void> _jumpTo(int seg) async {
    _seg = seg;
    _offset = 0;
    _announce();
    _notify();
    if (isPlaying) {
      await engine.stop();
      if (isPlaying && _seg == seg) await _speakCurrent();
    } else if (_status == ReadAloudStatus.paused) {
      // Chuyển đoạn khi đang tạm dừng: về trạng thái chờ ở đoạn mới.
      _status = ReadAloudStatus.idle;
      _notify();
    }
  }

  /// Phần đầu tiên (trong hàng đợi) của đoạn đầu tiên có nội dung ≥ / ≤ [paragraph].
  int _firstSegOf(int paragraph, {bool forward = false}) {
    if (forward) {
      final i = _queue.indexWhere((s) => s.paragraph >= paragraph);
      return i < 0 ? _queue.length - 1 : i;
    }
    final i = _queue.indexWhere((s) => s.paragraph == paragraph);
    return i < 0 ? 0 : i;
  }

  void _announce() {
    if (_queue.isEmpty) return;
    final p = currentParagraph;
    if (_announced == p) return;
    _announced = p;
    onParagraph?.call(p);
  }

  Future<void> _speakCurrent() async {
    if (_queue.isEmpty) return;
    _announce();
    final text = _queue[_seg].text;
    if (_offset >= text.length) _offset = 0;
    _spokenBase = _offset;
    await engine.speak(_offset == 0 ? text : text.substring(_offset));
  }

  void _handleProgress(int start, int end) {
    if (!isPlaying || _queue.isEmpty) return;
    final abs = _spokenBase + start;
    if (abs >= 0 && abs < _queue[_seg].text.length) _offset = abs;
  }

  void _handleComplete() {
    if (!isPlaying || _disposed) return;
    _offset = 0;
    if (_seg + 1 >= _queue.length) {
      // Đọc hết: về đầu, chờ.
      _seg = 0;
      _announced = null;
      _status = ReadAloudStatus.idle;
      _notify();
      return;
    }
    _seg++;
    _notify();
    _speakCurrent();
  }

  void _handleError(String message) {
    if (_disposed) return;
    _error = message;
    if (isPlaying) _status = ReadAloudStatus.paused;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (isPlaying || _status == ReadAloudStatus.paused) engine.stop();
    // Engine dùng chung: chỉ gỡ callback nếu vẫn là của controller này.
    if (engine.onComplete == _handleComplete) engine.detach();
    super.dispose();
  }
}
