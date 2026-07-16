import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper para speech_to_text — usa o SpeechRecognizer nativo do Android.
class SttService {
  static final _stt = stt.SpeechToText();
  static bool _available = false;

  static Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (err) {},
      onStatus: (status) {},
    );
    return _available;
  }

  static bool get isAvailable => _available;

  /// Inicia escuta em pt-BR. Chama onResult com cada resultado parcial/final.
  static Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) return;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      localeId: 'pt-BR',
      listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
    );
  }

  static Future<void> stop() async {
    await _stt.stop();
  }
}
