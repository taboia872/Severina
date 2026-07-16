import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  AiProvider _provider = AiProvider.openaiCompat;
  String _selectedPreset = 'original';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    await AppSettings.I.load();
    _apiKeyCtrl.text = AppSettings.I.apiKey;
    _modelCtrl.text = AppSettings.I.model;
    _provider = AppSettings.I.provider;
    _selectedPreset = AppSettings.I.presetId;
    if (mounted) setState(() {});
  }

  void _switchProvider(AiProvider newProvider) {
    setState(() {
      _provider = newProvider;
      final pc = AppSettings.providerConfigFor(newProvider);
      _modelCtrl.text = pc.defaultModel;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final s = AppSettings.I;
    s.provider = _provider;
    s.apiKey = _apiKeyCtrl.text.trim();
    s.model = _modelCtrl.text.trim();
    final pc = AppSettings.providerConfigFor(_provider);
    s.endpoint = pc.endpoint;
    s.presetId = _selectedPreset;
    s.systemPrompt = AppSettings.presets
        .firstWhere((p) => p.id == _selectedPreset)
        .prompt;
    await s.save();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 28),

              // --- Preset de personalidade ---
              Text('Personalidade',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppSettings.presets.map((p) {
                  final selected = p.id == _selectedPreset;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPreset = p.id),
                    child: Chip(
                      label: Text('${p.emoji} ${p.name}'),
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // --- API Key ---
              Text('Configuração',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  hintText: AppSettings.providerConfigFor(_provider).hintApiKey,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.memory),
                ),
              ),
              const SizedBox(height: 40),

              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
