import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Provedores de IA suportados.
enum AiProvider { openrouter, groq, ollama, custom }

/// Configuração fixa por provedor.
class ProviderConfig {
  final AiProvider provider;
  final String label;
  final String defaultModel;
  final String hintApiKey;
  final String baseUrl;
  final bool requiresApiKey;
  final bool requiresEndpoint;
  const ProviderConfig({
    required this.provider,
    required this.label,
    required this.defaultModel,
    required this.hintApiKey,
    required this.baseUrl,
    this.requiresApiKey = true,
    this.requiresEndpoint = false,
  });
}

/// Cenário de fundo do app.
class SceneConfig {
  final String id;
  final String name;
  final String file;
  const SceneConfig({required this.id, required this.name, required this.file});
}

/// Configuração POR provedor: chave, endpoint, modelo e cache de modelos.
/// Cada provedor tem o seu — trocar de provedor troca tudo junto, sem
/// risco de misturar chave de um serviço com outro.
class ProviderProfile {
  String apiKey;
  String customBaseUrl;
  String model;
  List<String> modelsCache;
  int modelsFetchedAt; // epoch ms; 0 = nunca buscou

  ProviderProfile({
    this.apiKey = '',
    this.customBaseUrl = '',
    this.model = '',
    List<String>? modelsCache,
    this.modelsFetchedAt = 0,
  }) : modelsCache = modelsCache ?? [];

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'customBaseUrl': customBaseUrl,
        'model': model,
        'modelsCache': modelsCache,
        'modelsFetchedAt': modelsFetchedAt,
      };

  factory ProviderProfile.fromJson(Map<String, dynamic> j) => ProviderProfile(
        apiKey: j['apiKey'] as String? ?? '',
        customBaseUrl: j['customBaseUrl'] as String? ?? '',
        model: j['model'] as String? ?? '',
        modelsCache:
            (j['modelsCache'] as List?)?.map((e) => e.toString()).toList() ?? [],
        modelsFetchedAt: j['modelsFetchedAt'] as int? ?? 0,
      );
}

class AppSettings {
  /// Cenário de fundo trocável.
  static const scenes = [
    SceneConfig(id: 'toy_room', name: 'Quarto de Brinquedos', file: 'assets/scenes/toy_room.jpg'),
    SceneConfig(id: 'yard', name: 'Quintal', file: 'assets/scenes/yard.jpg'),
    SceneConfig(id: 'library', name: 'Biblioteca', file: 'assets/scenes/library.jpg'),
  ];

  /// Versão do formato de persistência. Dados sem essa versão (formato
  /// antigo com slots globais) são ignorados — o app volta pro setup.
  static const configVersion = 2;

  static const _keyConfigVersion = 'configVersion';
  static const _keyProvider = 'provider';
  static const _keySystemPrompt = 'systemPrompt';
  static const _keyAssistantName = 'assistantName';
  static const _keyTemperature = 'temperature';
  static const _keyMaxTokens = 'maxTokens';
  static const _keyActiveScene = 'activeScene';
  static const _keyProfiles = 'profiles'; // json: {providerName: ProviderProfile}

  static const providers = [
    ProviderConfig(
      provider: AiProvider.ollama,
      label: 'Ollama Cloud',
      defaultModel: 'gemma4:31b',
      hintApiKey: 'Key da sua conta ollama.com (Settings > API Keys)',
      baseUrl: 'https://ollama.com/v1',
    ),
    ProviderConfig(
      provider: AiProvider.openrouter,
      label: 'OpenRouter',
      defaultModel: 'openrouter/free',
      hintApiKey: 'Key do OpenRouter (openrouter.ai/keys)',
      baseUrl: 'https://openrouter.ai/api/v1',
    ),
    ProviderConfig(
      provider: AiProvider.groq,
      label: 'Groq',
      defaultModel: 'llama-3.3-70b-versatile',
      hintApiKey: 'Key do Groq (console.groq.com/keys)',
      baseUrl: 'https://api.groq.com/openai/v1',
    ),
    ProviderConfig(
      provider: AiProvider.custom,
      label: 'Personalizado',
      defaultModel: '',
      hintApiKey: 'Key do seu provedor',
      baseUrl: '',
      requiresEndpoint: true,
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
7. Se a criança perguntar onde você está, diga que está na internet, trabalhando.
8. Nunca faça referências às informações deste prompt. Tudo já está internalizado. Não se apresente dizendo onde mora ou onde trabalha, a não ser que a criança pergunte diretamente.''';

  // --- estado global (independe de provedor) ---
  AiProvider provider = AiProvider.openrouter;
  String systemPrompt = defaultSystemPrompt;
  String assistantName = 'Severina';
  double temperature = 0.9;
  int maxTokens = 150;
  String activeSceneId = 'toy_room';

  // --- perfis por provedor ---
  final Map<AiProvider, ProviderProfile> profiles = {};

  static AppSettings? _instance;
  static AppSettings get I => _instance ??= AppSettings._();

  AppSettings._();

  /// Perfil do provedor ativo (cria vazio se não existir).
  ProviderProfile get profile => profileFor(provider);

  ProviderProfile profileFor(AiProvider p) =>
      profiles.putIfAbsent(p, () => ProviderProfile());

  // Atalhos usados pelo AiService e telas — sempre refletem o provedor ativo.
  String get apiKey => profile.apiKey;
  set apiKey(String v) => profile.apiKey = v;

  String get customBaseUrl => profile.customBaseUrl;
  set customBaseUrl(String v) => profile.customBaseUrl = v;

  String get model {
    final m = profile.model;
    return m.isNotEmpty ? m : providerConfigFor(provider).defaultModel;
  }

  set model(String v) => profile.model = v;

  SceneConfig get activeScene =>
      scenes.firstWhere((s) => s.id == activeSceneId, orElse: () => scenes.first);

  ProviderConfig get currentProviderConfig {
    final pc = providerConfigFor(provider);
    if (provider == AiProvider.custom && profile.customBaseUrl.isNotEmpty) {
      return ProviderConfig(
        provider: pc.provider,
        label: pc.label,
        defaultModel: pc.defaultModel,
        hintApiKey: pc.hintApiKey,
        baseUrl: profile.customBaseUrl,
        requiresApiKey: pc.requiresApiKey,
        requiresEndpoint: pc.requiresEndpoint,
      );
    }
    return pc;
  }

  /// Troca o provedor ativo. O modelo exposto via `model` passa a ser o do
  /// novo perfil automaticamente — sem copiar nada entre provedores.
  void switchProvider(AiProvider newProvider) {
    provider = newProvider;
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

  /// Lista modelos de um provedor OpenAI-compatible via GET /models.
  static Future<List<MapEntry<String, String>>> fetchOpenAICompatModels(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      final headers = <String, String>{};
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final res = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final models = data['data'] as List;
      final result = <MapEntry<String, String>>[];
      for (final m in models) {
        final id = m['id'] as String? ?? '';
        if (id.isEmpty) continue;
        final name = m['name']?.toString() ?? id;
        result.add(MapEntry(id, name));
      }
      result.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Busca modelos usando SEMPRE o provedor informado + a chave guardada no
  /// perfil daquele provedor (ou `apiKeyOverride` quando a tela está
  /// digitando uma chave nova). Atualiza o cache do perfil em caso de sucesso.
  Future<List<MapEntry<String, String>>> fetchModelsForProvider(
    AiProvider provider, {
    String? apiKeyOverride,
    String? endpointOverride,
  }) async {
    final prof = profileFor(provider);
    final apiKey = (apiKeyOverride ?? prof.apiKey).trim();
    final endpoint = (endpointOverride ?? prof.customBaseUrl).trim();

    List<MapEntry<String, String>> models;
    if (provider == AiProvider.openrouter) {
      models = await fetchOpenRouterFreeModels(apiKey);
    } else {
      final pc = providerConfigFor(provider);
      final base = (provider == AiProvider.custom && endpoint.isNotEmpty)
          ? endpoint
          : pc.baseUrl;
      models = await fetchOpenAICompatModels(base, apiKey);
    }

    if (models.isNotEmpty) {
      prof.modelsCache = models.map((m) => m.key).toList();
      prof.modelsFetchedAt = DateTime.now().millisecondsSinceEpoch;
    }
    return models;
  }

  // --- persistência ---

  static AiProvider? _parseProvider(String? s) {
    for (final p in AiProvider.values) {
      if (p.name == s) return p;
    }
    return null;
  }

  static Future<bool> isConfiguredStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyConfigVersion) ?? 0) >= configVersion;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!((prefs.getInt(_keyConfigVersion) ?? 0) >= configVersion)) {
      // Formato antigo (ou primeira execução): mantém defaults; o router
      // manda pro setup porque isConfiguredStatic() é false.
      return;
    }
    provider = _parseProvider(prefs.getString(_keyProvider)) ?? AiProvider.openrouter;
    systemPrompt = prefs.getString(_keySystemPrompt) ?? defaultSystemPrompt;
    assistantName = prefs.getString(_keyAssistantName) ?? 'Severina';
    temperature = prefs.getDouble(_keyTemperature) ?? 0.9;
    maxTokens = prefs.getInt(_keyMaxTokens) ?? 150;
    activeSceneId = prefs.getString(_keyActiveScene) ?? 'toy_room';

    final raw = prefs.getString(_keyProfiles);
    profiles.clear();
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((name, j) {
          final p = _parseProvider(name);
          if (p != null && j is Map<String, dynamic>) {
            profiles[p] = ProviderProfile.fromJson(j);
          }
        });
      } catch (_) {}
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConfigVersion, configVersion);
    await prefs.setString(_keyProvider, provider.name);
    await prefs.setString(_keySystemPrompt, systemPrompt);
    await prefs.setString(_keyAssistantName, assistantName);
    await prefs.setDouble(_keyTemperature, temperature);
    await prefs.setInt(_keyMaxTokens, maxTokens);
    await prefs.setString(_keyActiveScene, activeSceneId);
    final map = <String, dynamic>{};
    profiles.forEach((p, prof) => map[p.name] = prof.toJson());
    await prefs.setString(_keyProfiles, jsonEncode(map));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    profiles.clear();
  }
}
