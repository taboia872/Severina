import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _modelCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  AiProvider _provider = AiProvider.gemini;
  bool _loading = false;
  bool _obscureKey = true;
  bool _detectingModels = false;
  List<MapEntry<String, String>> _models = [];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    await AppSettings.I.load();
    _modelCtrl.text = AppSettings.I.model;
    _provider = AppSettings.I.provider;
    if (mounted) setState(() {});
  }

  void _switchProvider(AiProvider newProvider) {
    setState(() {
      _provider = newProvider;
      final pc = AppSettings.providerConfigFor(newProvider);
      _modelCtrl.text = pc.defaultModel;
      _apiKeyCtrl.clear();
      _models = [];
    });
  }

  Future<void> _detectModels() async {
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_provider == AiProvider.gemini
              ? 'Digite a API Key do Gemini primeiro'
              : 'Digite a API Key do OpenRouter primeiro'),
        ),
      );
      return;
    }

    setState(() => _detectingModels = true);

    List<MapEntry<String, String>> models;
    if (_provider == AiProvider.gemini) {
      models = await AppSettings.fetchGeminiModels(apiKey);
    } else {
      models = await AppSettings.fetchOpenRouterFreeModels(apiKey);
    }

    setState(() => _detectingModels = false);

    if (models.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider == AiProvider.gemini
            ? 'Não encontrei modelos. Verifique a API Key do Google.'
            : 'Não encontrei modelos gratuitos. Verifique a API Key.')),
      );
    } else {
      setState(() => _models = models);
    }
  }

  Future<void> _save() async {
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cadastre uma API Key do ${_provider == AiProvider.gemini ? 'Gemini' : 'OpenRouter'} para continuar.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // Salva a API key como primeiro slot
    final slotId = DateTime.now().millisecondsSinceEpoch.toString();
    final slotLabel = _provider == AiProvider.gemini ? 'Gemini' : 'OpenRouter';
    await AppSettings.saveSlot(slotId, slotLabel, apiKey);

    final s = AppSettings.I;
    s.provider = _provider;
    s.model = _modelCtrl.text.trim();
    s.systemPrompt = AppSettings.defaultSystemPrompt;
    s.apiKey = apiKey;
    s.activeSlotId = slotId;
    await s.save();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = AppSettings.providerConfigFor(_provider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Severina',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assistente por voz',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

              // --- Provedor ---
              Text('Provedor da IA',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Column(
                children: AppSettings.providers.map((pc) {
                  return RadioListTile<AiProvider>(
                    value: pc.provider,
                    groupValue: _provider,
                    title: Text(pc.label),
                    subtitle: Text(pc.hintApiKey, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    onChanged: (v) => _switchProvider(v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // --- API Key ---
              Text('API Key',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'Sua chave de API',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  hintText: pc.hintApiKey,
                ),
              ),
              const SizedBox(height: 28),

              // --- Modelo ---
              Text('Modelo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_models.isNotEmpty)
                DropdownButtonFormField<String>(
                  menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                  isExpanded: true,
                  value: _models.any((m) => m.key == _modelCtrl.text) ? _modelCtrl.text : null,
                  decoration: InputDecoration(
                    labelText: _provider == AiProvider.gemini ? 'Modelo Gemini' : 'Modelo (gratuito)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.memory),
                  ),
                  items: _models.map((m) {
                    return DropdownMenuItem(
                      value: m.key,
                      child: Text(m.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _modelCtrl.text = v);
                  },
                )
              else
                TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nome do modelo',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.memory),
                    hintText: pc.defaultModel,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _detectingModels ? null : _detectModels,
                  icon: _detectingModels
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_detectingModels ? 'Buscando modelos...' : 'Listar modelos disponíveis'),
                ),
              ),
              const SizedBox(height: 40);

              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Salvar e começar', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
