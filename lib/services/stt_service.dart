import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper para speech_to_text — Press-To-Talk.
class SttService {
  static final _stt = stt.SpeechToText();
  static bool _available = false;

  static Future<bool> init() async {
    try {
      // Timeout 5s — em alguns Android (Samsung One UI) o initialize()
      // pode nunca completar se o Google STT nao estiver disponivel.
      _available = await _stt.initialize(
        onError: (err) {},
        onStatus: (status) {},
      ).timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      _available = false;
    }
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

  /// Para a escuta.
  static Future<void> stopListening() async {
    await _stt.stop();
  }
}
