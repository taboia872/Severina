import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _modelCtrl = TextEditingController();
  AiProvider _provider = AiProvider.gemini;
  bool _loading = false;

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
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final s = AppSettings.I;
    s.provider = _provider;
    s.model = _modelCtrl.text.trim();
    s.systemPrompt = AppSettings.defaultSystemPrompt;
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

              // --- Modelo ---
              Text('Modelo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _modelCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome do modelo',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.memory),
                  hintText: AppSettings.providerConfigFor(_provider).defaultModel,
                ),
              ),
              const SizedBox(height: 16),

              // --- Aviso sobre API Key ---
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cadastre sua API Key em Configurações → Chaves de API',
                            style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
