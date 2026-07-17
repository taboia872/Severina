import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/app_settings.dart';

class AiService {
  /// Envia a conversa para uma API OpenAI-compatible e retorna a resposta em texto.
  static Future<String> chat({
    required List<Map<String, String>> messages,
  }) async {
    final s = AppSettings.I;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${s.apiKey}',
    };

    // OpenRouter headers extras (opcional, mas evita 403)
    if (s.provider == AiProvider.openrouter) {
      headers['HTTP-Referer'] = 'https://github.com/taboia872/Severina';
      headers['X-Title'] = 'Severina';
    }

    final body = jsonEncode({
      'model': s.model,
      'messages': messages,
      'temperature': s.temperature,
      'max_tokens': s.maxTokens,
      'stream': false,
    });

    final res = await http.post(
      Uri.parse(s.endpoint),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');
    }

    final data = jsonDecode(res.body);
    return data['choices'][0]['message']['content'] as String;
  }
}
