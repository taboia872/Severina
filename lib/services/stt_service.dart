import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper para speech_to_text — Press-To-Talk com mute do beep do Android.
class SttService {
  static final _stt = stt.SpeechToText();
  static bool _available = false;

  static const _audioChannel = MethodChannel('severina/audio');

  static Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (err) {},
      onStatus: (status) {},
    );
    return _available;
  }

  static bool get isAvailable => _available;

  /// Inicia escuta em pt-BR. Streaming de resultados parciais via onResult.
  /// No Android, muta o STREAM_SYSTEM antes para silenciar o beep.
  static Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) return;

    // Muta o som do sistema antes de iniciar (silencia o beep do Google STT)
    try {
      await _audioChannel.invokeMethod('muteSystemSound');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {
      // Se o channel não existir (iOS), ignora
    }

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

  /// Para a escuta e desmuta o som do sistema.
  static Future<void> stopListening() async {
    await _stt.stop();

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      await _audioChannel.invokeMethod('unmuteSystemSound');
    } catch (_) {}
  }
}
