import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/app_settings.dart';

class AiService {
  /// Envia a conversa para a API do provedor ativo e retorna a resposta em texto.
  /// Suporta Gemini (formato contents) e OpenRouter/Local (formato OpenAI messages).
  static Future<String> chat({
    required List<Map<String, String>> messages,
  }) async {
    final s = AppSettings.I;

    if (s.provider == AiProvider.gemini) {
      return _chatGemini(messages, s);
    } else {
      return _chatOpenAICompat(messages, s);
    }
  }

  /// Gemini REST API — formato generateContent.
  static Future<String> _chatGemini(
    List<Map<String, String>> messages,
    AppSettings s,
  ) async {
    final systemPrompt = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'])
        .join('\n\n');

    final conversation = messages.where((m) => m['role'] != 'system').toList();

    // Gemini usa "contents" com role "user"/"model" e "parts" com "text"
    final contents = <Map<String, dynamic>>[];
    for (final m in conversation) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [{'text': m['content']}],
      });
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': s.temperature,
        'maxOutputTokens': s.maxTokens,
      },
    };

    if (systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [{'text': systemPrompt}],
      };
    }

    final url =
        '${s.currentProviderConfig.baseUrl}/models/${s.model}:generateContent?key=${s.apiKey}';

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      final snippet = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception('Gemini ${res.statusCode}: $snippet');
    }

    final data = jsonDecode(res.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini: resposta vazia');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List;
    final text = parts.map((p) => p['text'] as String? ?? '').join('').trim();

    return _stripThinkTags(text);
  }

  /// OpenAI-compatible (OpenRouter, Local) — formato chat/completions.
  static Future<String> _chatOpenAICompat(
    List<Map<String, String>> messages,
    AppSettings s,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${s.apiKey}',
    };

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

    final endpoint = s.provider == AiProvider.local
        ? '${s.currentProviderConfig.baseUrl}/chat/completions'
        : '${s.currentProviderConfig.baseUrl}/chat/completions';

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

  /// Remove tags  que alguns modelos (DeepSeek R1, etc) injetam.
  static String _stripThinkTags(String text) {
    var cleaned = text;
    // tags completas: <think>...
    final fullThinkRegex = RegExp(r'', multiLine: true, dotAll: true);
    cleaned = cleaned.replaceAll(fullThinkRegex, '').trim();
    // tag de abertura sem fechamento até o final
    final openThinkRegex = RegExp(r'<think>.*$', multiLine: true, dotAll: true);
    cleaned = cleaned.replaceAll(openThinkRegex, '').trim();
    return cleaned;
  }
}
