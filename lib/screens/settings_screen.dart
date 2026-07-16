import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKey;
  late TextEditingController _endpoint;
  late TextEditingController _model;
  late TextEditingController _name;
  late double _temp;
  late int _maxTokens;
  late String _presetId;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.I;
    _apiKey = TextEditingController(text: s.apiKey);
    _endpoint = TextEditingController(text: s.endpoint);
    _model = TextEditingController(text: s.model);
    _name = TextEditingController(text: s.assistantName);
    _temp = s.temperature;
    _maxTokens = s.maxTokens;
    _presetId = s.presetId;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _endpoint.dispose();
    _model.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppSettings.I;
    s.apiKey = _apiKey.text.trim();
    s.endpoint = _endpoint.text.trim();
    s.model = _model.text.trim();
    s.assistantName = _name.text.trim();
    s.temperature = _temp;
    s.maxTokens = _maxTokens;
    s.presetId = _presetId;
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

              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome da assistente',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _apiKey,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _endpoint,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.memory),
                ),
              ),
              const SizedBox(height: 16),

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
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/setup', (_) => false);
                  }
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
