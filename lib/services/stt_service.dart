import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper para speech_to_text — usa o SpeechRecognizer nativo do Android.
class SttService {
  static final _stt = stt.SpeechToText();
  static bool _available = false;
  static bool _listening = false;

  static Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (err) => _listening = false,
      onStatus: (status) {
        // 'notListening' significa que parou sem finalizar
        if (status == 'notListening' && _listening) {
          _listening = false;
        }
      },
    );
    return _available;
  }

  static bool get isAvailable => _available;
  static bool get isListening => _listening;

  /// Inicia escuta em pt-BR. Chama onResult com cada resultado parcial/final.
  /// Chama onTimeout se parar sem produzir texto final.
  static Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onTimeout,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_available) return;
    _listening = true;

    await _stt.listen(
      onResult: (r) {
        final text = r.recognizedWords;
        if (text.isNotEmpty) {
          onResult(text, r.finalResult);
        }
        if (r.finalResult) {
          _listening = false;
        }
      },
      localeId: 'pt-BR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        autoStop: true,
      ),
    );

    // Timeout: se ainda listening após N segundos sem finalResult, para
    if (onTimeout != null) {
      Future.delayed(timeout, () {
        if (_listening) {
          stop();
          _listening = false;
          onTimeout();
        }
      });
    }
  }

  static Future<void> stop() async {
    _listening = false;
    await _stt.stop();
  }
}
