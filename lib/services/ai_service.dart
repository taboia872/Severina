import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/app_settings.dart';

class AiService {
  /// Envia a conversa para a API do provedor ativo e retorna a resposta em texto.
  /// Todos os provedores ativos usam formato OpenAI-compatible (OpenRouter, Groq, Ollama, Custom).
  static Future<String> chat({
    required List<Map<String, String>> messages,
  }) async {
    final s = AppSettings.I;
    final pc = s.currentProviderConfig;

    return _chatOpenAICompat(messages, s, pc);
  }

  /// OpenAI-compatible (OpenRouter, Groq, Ollama, Custom) — formato chat/completions.
  static Future<String> _chatOpenAICompat(
    List<Map<String, String>> messages,
    AppSettings s,
    ProviderConfig pc,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (pc.requiresApiKey && s.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${s.apiKey}';
    }

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

    final endpoint = '${pc.baseUrl}/chat/completions';

    final res = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      final snippet = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception('API ${res.statusCode}: $snippet');
    }

    final data = jsonDecode(res.body);
    final text = data['choices'][0]['message']['content'] as String;

    return _stripThinkTags(text);
  }

    /// Remove tags <think> que alguns modelos (DeepSeek R1, etc) injetam.
  static String _stripThinkTags(String text) {
    var cleaned = text;
    // tags completas: <think>...</think>
    final fullThinkRegex = RegExp(r'<think>.*?</think>', multiLine: true, dotAll: true);
    cleaned = cleaned.replaceAll(fullThinkRegex, '').trim();
    // tag de abertura sem fechamento até o final
    final openThinkRegex = RegExp(r'<think>.*$', multiLine: true, dotAll: true);
    cleaned = cleaned.replaceAll(openThinkRegex, '').trim();
    return cleaned;
  }
}
