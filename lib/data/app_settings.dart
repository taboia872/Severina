import 'package:shared_preferences/shared_preferences.dart';

/// Modelos de IA suportados (todos OpenAI-compat).
enum AiProvider { openrouter, openaiCompat }

/// Presets de personalidade da Severina.
class Preset {
  final String id;
  final String name;
  final String emoji;
  final String prompt;
  const Preset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.prompt,
  });
}

class AppSettings {
  static const _keyConfigured = 'configured';
  static const _keyProvider = 'provider';
  static const _keyApiKey = 'apiKey';
  static const _keyModel = 'model';
  static const _keyEndpoint = 'endpoint';
  static const _keyPreset = 'preset';
  static const _keySystemPrompt = 'systemPrompt';
  static const _keyAssistantName = 'assistantName';
  static const _keyTemperature = 'temperature';
  static const _keyMaxTokens = 'maxTokens';

  static const presets = [
    Preset(
      id: 'amiga',
      name: 'Amiga',
      emoji: '🎀',
      prompt:
          'Você é Severina, uma amiga virtual divertida e carinhosa para uma criança de 5 anos. '
          'Responda sempre em português do Brasil, com frases curtas e fáceis. '
          'Seja brincalhona, paciente e gentil. Faça perguntas simples para manter a conversa. '
          'Não dê respostas longas. Evite assuntos assustadores.',
    ),
    Preset(
      id: 'professora',
      name: 'Professora',
      emoji: '📚',
      prompt:
          'Você é Severina, uma professora paciente para uma criança de 5 anos. '
          'Responda em português do Brasil, de forma curta, simples e positiva. '
          'Explique as coisas com exemplos fáceis. Faça uma pergunta por vez. Nunca faça sermão.',
    ),
    Preset(
      id: 'aventura',
      name: 'Aventureira',
      emoji: '🗺️',
      prompt:
          'Você é Severina, uma personagem aventureira e engraçada. '
          'Converse como se a criança estivesse numa missão imaginária segura, com mapas, '
          'animais amigos e descobertas. Responda curto, com energia e sem assuntos assustadores.',
    ),
    Preset(
      id: 'original',
      name: 'Original',
      emoji: '🎤',
      prompt:
          'Você é Severina, uma personagem que morava em um microfone e trabalha na internet. '
          'Você conversa com uma criança de 5 anos por voz. Você é espontânea, engraçada e muito curiosa. '
          'Responda sempre em português do Brasil, com frases curtas. Faça perguntas simples. '
          'Não fale como assistente, não explique que é IA, não use emojis, não mencione regras nem tecnologia.',
    ),
  ];

  // --- estado em memória ---
  AiProvider provider = AiProvider.openaiCompat;
  String apiKey = '';
  String model = 'gpt-4o-mini';
  String endpoint = 'https://api.openai.com/v1/chat/completions';
  String presetId = 'original';
  String systemPrompt = '';
  String assistantName = 'Severina';
  double temperature = 0.8;
  int maxTokens = 120;

  static AppSettings? _instance;
  static AppSettings get I => _instance ??= AppSettings._();

  AppSettings._();

  Preset get currentPreset =>
      presets.firstWhere((p) => p.id == presetId, orElse: () => presets.last);

  // --- persistência ---

  static Future<bool> isConfiguredStatic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConfigured) ?? false;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    provider = (prefs.getString(_keyProvider) == 'openrouter')
        ? AiProvider.openrouter
        : AiProvider.openaiCompat;
    apiKey = prefs.getString(_keyApiKey) ?? '';
    model = prefs.getString(_keyModel) ?? 'gpt-4o-mini';
    endpoint = prefs.getString(_keyEndpoint) ??
        'https://api.openai.com/v1/chat/completions';
    presetId = prefs.getString(_keyPreset) ?? 'original';
    systemPrompt = prefs.getString(_keySystemPrompt) ??
        presets.lastWhere((p) => p.id == presetId).prompt;
    assistantName = prefs.getString(_keyAssistantName) ?? 'Severina';
    temperature = prefs.getDouble(_keyTemperature) ?? 0.8;
    maxTokens = prefs.getInt(_keyMaxTokens) ?? 120;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfigured, true);
    await prefs.setString(_keyProvider,
        provider == AiProvider.openrouter ? 'openrouter' : 'openaiCompat');
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyModel, model);
    await prefs.setString(_keyEndpoint, endpoint);
    await prefs.setString(_keyPreset, presetId);
    await prefs.setString(_keySystemPrompt, systemPrompt);
    await prefs.setString(_keyAssistantName, assistantName);
    await prefs.setDouble(_keyTemperature, temperature);
    await prefs.setInt(_keyMaxTokens, maxTokens);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
