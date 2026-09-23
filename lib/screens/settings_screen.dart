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
  late TextEditingController _endpoint;
  late double _temp;
  late int _maxTokens;
  late AiProvider _provider;
  late String _selectedSceneId;
  bool _obscureKey = true;

  bool _loadingModels = false;
  List<MapEntry<String, String>> _models = [];

  @override
  void initState() {
    super.initState();
    final s = AppSettings.I;
    _provider = s.provider;
    _temp = s.temperature;
    _maxTokens = s.maxTokens;
    _selectedSceneId = s.activeSceneId;
    _apiKey = TextEditingController();
    _model = TextEditingController();
    _endpoint = TextEditingController();
    _loadProfileIntoFields();
  }

  /// Preenche os campos com o perfil salvo do provedor selecionado.
  void _loadProfileIntoFields() {
    final prof = AppSettings.I.profileFor(_provider);
    _apiKey.text = prof.apiKey;
    _endpoint.text = prof.customBaseUrl;
    _model.text =
        prof.model.isNotEmpty ? prof.model : AppSettings.providerConfigFor(_provider).defaultModel;
    _models = [];
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  void _switchProvider(AiProvider newProvider) {
    setState(() {
      _provider = newProvider;
      _loadProfileIntoFields();
    });
  }

  Future<void> _detectModels() async {
    final pc = AppSettings.providerConfigFor(_provider);
    final apiKey = _apiKey.text.trim();

    if (pc.requiresApiKey && apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Digite a API Key do ${pc.label} primeiro')),
      );
      return;
    }

    if (pc.requiresEndpoint && _endpoint.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o endpoint (URL) do provedor primeiro')),
      );
      return;
    }

    setState(() => _loadingModels = true);

    final models = await AppSettings.I.fetchModelsForProvider(
      _provider,
      apiKeyOverride: apiKey,
      endpointOverride: _endpoint.text,
    );

    setState(() => _loadingModels = false);

    if (models.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_provider == AiProvider.openrouter
              ? 'Não encontrei modelos gratuitos. Verifique a API Key.'
              : pc.requiresEndpoint
                  ? 'Não encontrei modelos. Verifique a API Key e o endpoint.'
                  : 'Não encontrei modelos. Verifique a API Key do ${pc.label}.'),
        ),
      );
    } else {
      setState(() => _models = models);
    }
  }

  Future<void> _save() async {
    final s = AppSettings.I;
    final prof = s.profileFor(_provider);
    prof.apiKey = _apiKey.text.trim();
    prof.customBaseUrl = _endpoint.text.trim();
    prof.model = _model.text.trim();
    s.provider = _provider;
    s.temperature = _temp;
    s.maxTokens = _maxTokens;
    s.activeSceneId = _selectedSceneId;
    await s.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pc = AppSettings.providerConfigFor(_provider);

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
              Column(
                children: AppSettings.providers.map((pc) {
                  return RadioListTile<AiProvider>(
                    value: pc.provider,
                    groupValue: _provider,
                    title: Text(pc.label),
                    subtitle: Text(
                      pc.requiresEndpoint ? 'URL própria (OpenAI-compatible)' : pc.baseUrl,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onChanged: (v) => _switchProvider(v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // === ENDPOINT (somente Custom) ===
              if (pc.requiresEndpoint) ...[
                Text('Endpoint (URL)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _endpoint,
                  decoration: const InputDecoration(
                    labelText: 'URL do provedor (OpenAI-compatible)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://exemplo.com/v1',
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // === API KEY (campo direto, sempre do provedor selecionado) ===
              if (pc.requiresApiKey) ...[
                Text('API Key do ${pc.label}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    hintText: pc.hintApiKey,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // === MODELO ===
              Text('Modelo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_models.isNotEmpty)
                DropdownButtonFormField<String>(
                  menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                  isExpanded: true,
                  value: _models.any((m) => m.key == _model.text) ? _model.text : null,
                  decoration: InputDecoration(
                    labelText: 'Modelo ${pc.label}',
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
                    if (v != null) setState(() => _model.text = v);
                  },
                )
              else
                TextField(
                  controller: _model,
                  decoration: InputDecoration(
                    labelText: 'Modelo',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.memory),
                    hintText: pc.defaultModel.isNotEmpty ? pc.defaultModel : 'ex: model-name',
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingModels ? null : _detectModels,
                  icon: _loadingModels
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_loadingModels ? 'Buscando modelos...' : 'Listar modelos disponíveis'),
                ),
              ),
              const SizedBox(height: 24),

              // === CENARIO ===
              Text('Cenário de fundo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                isExpanded: true,
                value: _selectedSceneId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
                items: AppSettings.scenes.map((sc) {
                  return DropdownMenuItem(
                    value: sc.id,
                    child: Text(sc.name),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSceneId = v);
                },
              ),
              const SizedBox(height: 24),

              // === TEMPERATURA ===
              Text('Temperatura: ${_temp.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Slider(value: _temp, min: 0.0, max: 2.0, divisions: 20,
                onChanged: (v) => setState(() => _temp = v)),
              const SizedBox(height: 8),

              // === MAX TOKENS ===
              Text('Tokens máximos: $_maxTokens',
                  style: Theme.of(context).textTheme.bodyMedium),
              Slider(value: _maxTokens.toDouble(), min: 30, max: 300, divisions: 27,
                onChanged: (v) => setState(() => _maxTokens = v.round())),
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
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Apagar tudo?'),
                      content: const Text(
                        'Isso vai apagar todas as configurações, chaves de API e conversas. '
                        'O app volta para a tela inicial. Tem certeza?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Apagar tudo'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await AppSettings.I.reset();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/setup', (_) => false);
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
