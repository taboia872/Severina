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
  final _endpointCtrl = TextEditingController();
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
    _endpointCtrl.text = AppSettings.I.customBaseUrl;
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
    final pc = AppSettings.providerConfigFor(_provider);
    final apiKey = _apiKeyCtrl.text.trim();

    if (pc.requiresApiKey && apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Digite a API Key do ${pc.label} primeiro'),
        ),
      );
      return;
    }

    if (pc.requiresEndpoint && _endpointCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o endpoint (URL) do seu provedor primeiro.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _detectingModels = true);

    final models = await AppSettings.fetchModelsForProvider(
      _provider,
      apiKey,
      _endpointCtrl.text.trim(),
    );

    setState(() => _detectingModels = false);

    if (models.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não encontrei modelos. Verifique a API Key${pc.requiresEndpoint ? ' e o endpoint' : ''}.')),
      );
    } else {
      setState(() => _models = models);
    }
  }

  Future<void> _save() async {
    final pc = AppSettings.providerConfigFor(_provider);
    final apiKey = _apiKeyCtrl.text.trim();

    if (pc.requiresApiKey && apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cadastre uma API Key do ${pc.label} para continuar.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (pc.requiresEndpoint && _endpointCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o endpoint (URL) do seu provedor.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    String slotId = '';
    if (pc.requiresApiKey && apiKey.isNotEmpty) {
      slotId = DateTime.now().millisecondsSinceEpoch.toString();
      await AppSettings.saveSlot(slotId, pc.label, apiKey);
    }

    final s = AppSettings.I;
    s.provider = _provider;
    s.model = _modelCtrl.text.trim();
    s.systemPrompt = AppSettings.defaultSystemPrompt;
    s.apiKey = apiKey;
    s.activeSlotId = slotId;
    s.customBaseUrl = _endpointCtrl.text.trim();
    await s.save();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
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

              // --- Endpoint (somente Custom) ---
              if (pc.requiresEndpoint) ...[
                Text('Endpoint (URL)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _endpointCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL do provedor (OpenAI-compatible)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://exemplo.com/v1',
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // --- API Key (oculta se não precisa) ---
              if (pc.requiresApiKey) ...[
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
              ],

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
                    hintText: pc.defaultModel.isNotEmpty ? pc.defaultModel : 'ex: model-name',
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
              const SizedBox(height: 12),
              const SizedBox(height: 40),

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
