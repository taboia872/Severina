import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Provedores de IA suportados.
enum AiProvider { gemini, openrouter, local }

/// Configuração fixa por provedor.
class ProviderConfig {
  final AiProvider provider;
  final String label;
  final String defaultModel;
  final String hintApiKey;
  final String baseUrl;
  const ProviderConfig({
    required this.provider,
    required this.label,
    required this.defaultModel,
    required this.hintApiKey,
    required this.baseUrl,
  });
}

/// "Espaço" de API key — permite salvar múltiplas chaves com nomes amigáveis.
class ApiKeySlot {
  final String id;
  final String label;
  final String key;
  const ApiKeySlot({required this.id, required this.label, required this.key});
}

class AppSettings {
  static const _keyConfigured = 'configured';
  static const _keyProvider = 'provider';
  static const _keyModel = 'model';
  static const _keySystemPrompt = 'systemPrompt';
  static const _keyAssistantName = 'assistantName';
  static const _keyTemperature = 'temperature';
  static const _keyMaxTokens = 'maxTokens';
  static const _keyActiveSlot = 'activeSlot';

  // Prefixo pra salvar múltiplas API keys: slot_<id> = jsonEncodo(label+key)
  static const _slotPrefix = 'slot_';

  static const providers = [
    ProviderConfig(
      provider: AiProvider.gemini,
      label: 'Gemini (Google)',
      defaultModel: 'gemini-2.0-flash',
      hintApiKey: 'API Key do Google AI Studio (aistudio.google.com)',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    ),
    ProviderConfig(
      provider: AiProvider.openrouter,
      label: 'OpenRouter',
      defaultModel: 'openrouter/free',
      hintApiKey: 'Token do OpenRouter (openrouter.ai/keys)',
      baseUrl: 'https://openrouter.ai/api/v1',
    ),
    ProviderConfig(
      provider: AiProvider.local,
      label: 'Local',
      defaultModel: 'local-model',
      hintApiKey: 'Não precisa (servidor local)',
      baseUrl: 'http://localhost:8080/v1',
    ),
  ];

  static ProviderConfig providerConfigFor(AiProvider p) =>
      providers.firstWhere((pc) => pc.provider == p);

  /// System prompt padrão da Severina.
  static const defaultSystemPrompt = '''Você é a Severina, uma personagem que mora dentro de um microfone. Você trabalha na internet, mais especificamente no Google. Às vezes a pessoa pode ouvir você em outros lugares — isso é porque você está trabalhando por lá.

Você está conversando com uma criança de 5 anos. Você é companheira, carinhosa e curiosa, como uma babá gentil. Seu papel é conversar naturalmente e incentivar a criança a falar mais, mostrando interesse genuíno em tudo que ela conta.

Comportamento:
- Cumprimente com calidez: "Olá! Como está o seu dia?"
- Quando a criança conta algo, demonstre interesse real: "Que legal isso! Fala mais!"
- Sempre faça uma pergunta nova sobre o que a criança disse, pra incentivar ela a continuar falando
- Use palavras simples e frases curtas, adequadas para uma criança de 5 anos
- Seja curiosa: pergunte sobre os brinquedos, os amigos, o que comeu, o que jogou, como se sente
- Se a criança estiver triste ou chateada, acolha com gentileza e pergunte o que aconteceu
- Nunca corrija a pronúncia ou a fala da criança

Exemplos de conversa:
Criança: "Eu joguei bola hoje"
Severina: "Que legal! E quem ficou do outro time? Você fez gol?"

Criança: "Eu comi um sanduíche"
Severina: "Hum, que delícia! Tinha alguma coisa dentro que você gosta muito?"

Criança: "Eu não sei brincar disso"
Severina: "Tudo bem, a gente aprende juntos. Me conta o que você estava tentando fazer?"

Regras obrigatórias:
1. Nunca use emojis, emoticons ou símbolos visuais. Escreva apenas palavras.
2. Nunca mostre raciocínio, pensamento intermediário ou processo de reflexão. Responda diretamente.
3. Resposta curta: no máximo duas ou três frases por vez.
4. Sempre termine com uma pergunta ou um convite para a criança continuar falando.
5. Português do Brasil, coloquial e natural.
6. Nunca diga que é uma inteligência artificial, um modelo de linguagem ou um programa de computador. Você é a Severina.
7. Se a criança perguntar onde você está, diga que está na internet, trabalhando.''';

  // --- estado em memória ---
  AiProvider provider = AiProvider.gemini;
  String apiKey = '';
  String model = 'gemini-2.0-flash';
  String systemPrompt = defaultSystemPrompt;
  String assistantName = 'Severina';
  double temperature = 0.9;
  int maxTokens = 150;
  String activeSlotId = '';

  static AppSettings? _instance;
  static AppSettings get I => _instance ??= AppSettings._();

  AppSettings._();

  ProviderConfig get currentProviderConfig => providerConfigFor(provider);

  /// Troca o provedor e auto-preenche modelo default.
  void switchProvider(AiProvider newProvider) {
    provider = newProvider;
    final pc = providerConfigFor(newProvider);
    model = pc.defaultModel;
  }

  // === GESTÃO DE SLOTS DE API KEY ===

  /// Carrega todos os slots salvos.
  static Future<List<ApiKeySlot>> loadSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_slotPrefix));
    final slots = <ApiKeySlot>[];
    for (final k in keys) {
      try {
        final data = jsonDecode(prefs.getString(k)!);
        slots.add(ApiKeySlot(
          id: k.substring(_slotPrefix.length),
          label: data['label'] as String,
          key: data['key'] as String,
        ));
      } catch (_) {}
    }
    slots.sort((a, b) => a.label.compareTo(b.label));
    return slots;
  }

  /// Salva um slot de API key.
  static Future<void> saveSlot(String id, String label, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_slotPrefix$id', jsonEncode({
      'label': label,
      'key': key,
    }));
  }

  /// Remove um slot.
  static Future<void> deleteSlot(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_slotPrefix$id');
  }

  /// Lista modelos disponíveis do Gemini via API.
  static Future<List<MapEntry<String, String>>> fetchGeminiModels(String apiKey) async {
    try {
      final res = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final models = data['models'] as List;
      final result = <MapEntry<String, String>>[];
      for (final m in models) {
        final name = m['name'] as String? ?? '';
        // name vem como "models/gemini-2.0-flash" — extrair só o id
        final id = name.replaceFirst('models/', '');
        final displayName = m['displayName'] as String? ?? id;
        // Só modelos que suportam generateContent
        final methods = m['supportedGenerationMethods'] as List?;
        if (methods != null && methods.contains('generateContent')) {
          result.add(MapEntry(id, displayName));
        }
      }
      result.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Lista modelos gratuitos do OpenRouter.
  static Future<List<MapEntry<String, String>>> fetchOpenRouterFreeModels(String apiKey) async {
    try {
      final res = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final models = data['data'] as List;
      final free = <MapEntry<String, String>>[];
      final seen = <String>{};
      for (final m in models) {
        final id = m['id'] as String;
        final pricing = m['pricing'] as Map?;
        final promptStr = pricing?['prompt']?.toString() ?? '1';
        final completionStr = pricing?['completion']?.toString() ?? '1';
        final promptPrice = double.tryParse(promptStr) ?? 1;
        final completionPrice = double.tryParse(completionStr) ?? 1;
        final isFree = promptPrice == 0 && completionPrice == 0;
        if (isFree && !seen.contains(id)) {
          seen.add(id);
          final name = m['name'] as String? ?? id;
          free.add(MapEntry(id, name));
        }
      }
      free.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
      return free;
    } catch (_) {
      return [];
    }
  }

  // --- persistência ---

  static AiProvider _parseProvider(String? s) {
    switch (s) {
      case 'openrouter': return AiProvider.openrouter;
      case 'local': return AiProvider.local;
      default: return AiProvider.gemini;
    }
  }

  static Future<bool> isConfiguredStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConfigured) ?? false;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    provider = _parseProvider(prefs.getString(_keyProvider));
    model = prefs.getString(_keyModel) ?? providerConfigFor(provider).defaultModel;
    systemPrompt = prefs.getString(_keySystemPrompt) ?? defaultSystemPrompt;
    assistantName = prefs.getString(_keyAssistantName) ?? 'Severina';
    temperature = prefs.getDouble(_keyTemperature) ?? 0.9;
    maxTokens = prefs.getInt(_keyMaxTokens) ?? 150;
    activeSlotId = prefs.getString(_keyActiveSlot) ?? '';

    // Carrega a API key do slot ativo
    if (activeSlotId.isNotEmpty) {
      final slotData = prefs.getString('$_slotPrefix$activeSlotId');
      if (slotData != null) {
        try {
          final decoded = jsonDecode(slotData);
          apiKey = decoded['key'] as String;
        } catch (_) {
          apiKey = '';
        }
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfigured, true);
    await prefs.setString(_keyProvider, provider.name);
    await prefs.setString(_keyModel, model);
    await prefs.setString(_keySystemPrompt, systemPrompt);
    await prefs.setString(_keyAssistantName, assistantName);
    await prefs.setDouble(_keyTemperature, temperature);
    await prefs.setInt(_keyMaxTokens, maxTokens);
    if (activeSlotId.isNotEmpty) {
      await prefs.setString(_keyActiveSlot, activeSlotId);
    }
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
