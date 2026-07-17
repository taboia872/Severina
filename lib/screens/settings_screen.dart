import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKey;
  late TextEditingController _model;
  late TextEditingController _name;
  late double _temp;
  late int _maxTokens;
  late String _presetId;
  late AiProvider _provider;

  bool _loadingModels = false;
  List<MapEntry<String, String>> _freeModels = [];
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.I;
    _apiKey = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    _name = TextEditingController(text: s.assistantName);
    _temp = s.temperature;
    _maxTokens = s.maxTokens;
    _presetId = s.presetId;
    _provider = s.provider;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _name.dispose();
    super.dispose();
  }

  void _switchProvider(AiProvider newProvider) {
    setState(() {
      _provider = newProvider;
      final pc = AppSettings.providerConfigFor(newProvider);
      _model.text = pc.defaultModel;
      _freeModels = [];
      _selectedModel = null;
    });
  }

  Future<void> _detectModels() async {
    if (_provider != AiProvider.openrouter) return;
    if (_apiKey.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite a API Key do OpenRouter primeiro')),
      );
      return;
    }

    setState(() => _loadingModels = true);

    final models = await AppSettings.fetchOpenRouterFreeModels(_apiKey.text.trim());

    setState(() {
      _loadingModels = false;
      _freeModels = models;
      _selectedModel = models.any((m) => m.key == _model.text) ? _model.text : null;
    });

    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não encontrei modelos gratuitos. Verifique a API Key.')),
        );
      }
    }
  }

  Future<void> _save() async {
    final s = AppSettings.I;
    s.provider = _provider;
    s.apiKey = _apiKey.text.trim();
    s.model = _model.text.trim();
    s.assistantName = _name.text.trim();
    s.temperature = _temp;
    s.maxTokens = _maxTokens;
    s.presetId = _presetId;
    // endpoint é automático baseado no provider
    final pc = AppSettings.providerConfigFor(_provider);
    s.endpoint = pc.endpoint;
    s.systemPrompt =
        AppSettings.presets.firstWhere((p) => p.id == _presetId).prompt;
    await s.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // === PROVEDOR ===
              Text('Provedor da IA', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<AiProvider>(
                segments: AppSettings.providers.map((pc) {
                  return ButtonSegment(
                    value: pc.provider,
                    label: Text(pc.label),
                  );
                }).toList(),
                selected: {_provider},
                onSelectionChanged: (set) => _switchProvider(set.first),
              ),
              const SizedBox(height: 24),

              // === PERSONALIDADE ===
              Text('Personalidade', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppSettings.presets.map((p) {
                  final sel = p.id == _presetId;
                  return ChoiceChip(
                    label: Text('${p.emoji} ${p.name}'),
                    selected: sel,
                    onSelected: (_) => setState(() => _presetId = p.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // === API KEY ===
              TextField(
                controller: _apiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  hintText: AppSettings.providerConfigFor(_provider).hintApiKey,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // === MODELO ===
              if (_provider == AiProvider.openrouter && _freeModels.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'Modelo (gratuito)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.memory),
                  ),
                  items: _freeModels.map((m) {
                    return DropdownMenuItem(
                      value: m.key,
                      child: Text(m.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() {
                      _selectedModel = v;
                      _model.text = v;
                    });
                  },
                )
              else
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.memory),
                  ),
                ),
              if (_provider == AiProvider.openrouter) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingModels ? null : _detectModels,
                    icon: _loadingModels
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loadingModels
                        ? 'Buscando modelos...'
                        : 'Detectar modelos gratuitos'),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // === NOME ===
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome da assistente',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // === TEMPERATURA ===
              Text('Temperatura: ${_temp.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Slider(
                value: _temp,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                onChanged: (v) => setState(() => _temp = v),
              ),
              const SizedBox(height: 8),

              // === MAX TOKENS ===
              Text('Tokens máximos: $_maxTokens',
                  style: Theme.of(context).textTheme.bodyMedium),
              Slider(
                value: _maxTokens.toDouble(),
                min: 30,
                max: 300,
                divisions: 27,
                onChanged: (v) => setState(() => _maxTokens = v.round()),
              ),
              const SizedBox(height: 24),

              // === SAVE ===
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Salvar', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await AppSettings.I.reset();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/setup', (_) => false);
                },
                child: const Text('Apagar tudo e reconfigurar',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
