
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

/// TTS via Google Translate TTS.
/// Google corta áudio em ~200 chars — fatiamos por pontuação e reproduzimos em sequência.
class TtsService {
  static final _player = AudioPlayer();

  static bool _stopped = false;

  /// Tokeniza o texto em chunks respeitando pontuação (final de frase).
  static List<String> _chunkText(String text, {int maxLen = 180}) {
    final chunks = <String>[];
    final sentences =
        text.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty);
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if ((buffer.length + sentence.length) > maxLen) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        // sentença sozinha maior que maxLen — corta no espaço mais próximo
        if (sentence.length > maxLen) {
          var s = sentence;
          while (s.length > maxLen) {
            final cut = s.lastIndexOf(' ', maxLen);
            chunks.add(s.substring(0, cut > 0 ? cut : maxLen).trim());
            s = s.substring(cut > 0 ? cut : maxLen);
          }
          if (s.trim().isNotEmpty) buffer.write(s);
        } else {
          buffer.write(sentence);
          buffer.write(' ');
        }
      } else {
        buffer.write(sentence);
        buffer.write(' ');
      }
    }
    if (buffer.toString().trim().isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }
    return chunks;
  }

  /// Reproduz o texto em pt-BR via Google Translate TTS.
  /// Reproduz chunk-by-chunk para contornar o limite de chars do Google.
  static Future<void> speak(String text, {void Function()? onStart, void Function()? onComplete}) async {
    _stopped = false;
    final chunks = _chunkText(text);
    if (chunks.isEmpty) {
      onComplete?.call();
      return;
    }

    onStart?.call();

    for (final chunk in chunks) {
      if (_stopped) break;
      final url = Uri.parse(
        'https://translate.google.com/translate_tts'
        '?ie=UTF-8&tl=pt-BR&client=tw-ob&q=${Uri.encodeComponent(chunk)}',
      );

      // Retry com backoff exponencial para 429/5xx do Google Translate TTS.
      bool ok = false;
      for (var attempt = 0; attempt < 3 && !ok && !_stopped; attempt++) {
        final res = await http.get(url);
        if (res.statusCode == 200) {
          await _player.play(BytesSource(res.bodyBytes));
          await _player.onPlayerComplete.first;
          ok = true;
        } else if (res.statusCode == 429 || res.statusCode >= 500) {
          // Backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          // Erro definitivo (4xx que nao é 429) — nao retenta
          break;
        }
      }
      // Se todos os retries falharam, pula o chunk (fala parcial)
    }

    onComplete?.call();
  }

  static Future<void> stop() async {
    _stopped = true;
    await _player.stop();
  }
}
