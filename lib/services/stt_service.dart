import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper para speech_to_text — Press-To-Talk.
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

  /// Inicia escuta em pt-BR. Streaming de resultados parciais via onResult.
  static Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) return;

    await _stt.listen(
      onResult: (r) {
        final text = r.recognizedWords;
        onResult(text, r.finalResult);
      },
      localeId: 'pt-BR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// Para a escuta e retorna o último texto reconhecido.
  static Future<void> stopListening() async {
    await _stt.stop();
  }
}
