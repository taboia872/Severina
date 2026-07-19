import 'package:flutter/material.dart';
import '../data/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _model;
  late double _temp;
  late int _maxTokens;
  late AiProvider _provider;

  bool _loadingModels = false;
  List<MapEntry<String, String>> _models = [];
  String? _selectedModel;

  // Slots de API key
  List<ApiKeySlot> _slots = [];
  String _activeSlotId = '';
  String _selectedSceneId = 'toy_room';

  @override
  void initState() {
    super.initState();
    final s = AppSettings.I;
    _model = TextEditingController(text: s.model);
    _temp = s.temperature;
    _maxTokens = s.maxTokens;
    _provider = s.provider;
    _activeSlotId = s.activeSlotId;
    _selectedSceneId = s.activeSceneId;
    _loadSlots();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final slots = await AppSettings.loadSlots();
    if (mounted) setState(() => _slots = slots);
  }

  void _switchProvider(AiProvider newProvider) {
    setState(() {
      _provider = newProvider;
      final pc = AppSettings.providerConfigFor(newProvider);
      _model.text = pc.defaultModel;
      _models = [];
      _selectedModel = null;
    });
  }

  Future<void> _detectModels() async {
    final apiKey = _currentApiKey();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider == AiProvider.gemini
            ? 'Cadastre uma API Key do Gemini primeiro'
            : 'Cadastre uma API Key do OpenRouter primeiro')),
      );
      return;
    }

    setState(() => _loadingModels = true);

    List<MapEntry<String, String>> models;
    if (_provider == AiProvider.gemini) {
      models = await AppSettings.fetchGeminiModels(apiKey);
    } else {
      models = await AppSettings.fetchOpenRouterFreeModels(apiKey);
    }

    setState(() {
      _loadingModels = false;
      _models = models;
      _selectedModel = models.any((m) => m.key == _model.text) ? _model.text : null;
    });

    if (models.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider == AiProvider.gemini
            ? 'Não encontrei modelos. Verifique a API Key do Google.'
            : 'Não encontrei modelos gratuitos. Verifique a API Key.')),
      );
    }
  }

  String _currentApiKey() {
    final slot = _slots.where((s) => s.id == _activeSlotId).firstOrNull;
    return slot?.key ?? AppSettings.I.apiKey;
  }

  void _openSlotManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SlotManagerSheet(
        slots: _slots,
        activeSlotId: _activeSlotId,
        provider: _provider,
        onSaved: () async {
          await _loadSlots();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _save() async {
    final s = AppSettings.I;
    s.provider = _provider;
    s.model = _model.text.trim();
    s.temperature = _temp;
    s.maxTokens = _maxTokens;
    s.activeSlotId = _activeSlotId;
    s.activeSceneId = _selectedSceneId;
    // Atualiza apiKey do slot ativo
    final slot = _slots.where((sl) => sl.id == _activeSlotId).firstOrNull;
    if (slot != null) s.apiKey = slot.key;
    await s.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final showModelDetect = _provider == AiProvider.gemini || _provider == AiProvider.openrouter;
    final showSlotManager = _provider == AiProvider.gemini || _provider == AiProvider.openrouter;

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
                    subtitle: Text(pc.baseUrl, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    onChanged: (v) => _switchProvider(v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // === API KEYS (SLOTS) ===
              if (showSlotManager) ...[
                Row(
                  children: [
                    Text('Chaves de API', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.manage_accounts),
                      tooltip: 'Gerenciar chaves',
                      onPressed: _openSlotManager,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_slots.isEmpty)
                  Text('Nenhuma chave salva. Toque no ícone acima para adicionar.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13))
                else
                  DropdownButtonFormField<String>(

                    menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                    isExpanded: true,                    value: _slots.any((s) => s.id == _activeSlotId) ? _activeSlotId : null,
                    decoration: const InputDecoration(
                      labelText: 'Chave ativa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    items: _slots.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _activeSlotId = v ?? ''),
                  ),
                const SizedBox(height: 24),
              ],

              // === MODELO ===
              if (_models.isNotEmpty)
                DropdownButtonFormField<String>(

                    menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                    isExpanded: true,                  value: _selectedModel,
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
                    if (v != null) setState(() {
                      _selectedModel = v;
                      _model.text = v;
                    });
                  },
                )
              else
                TextField(
                  controller: _model,
                  decoration: InputDecoration(
                    labelText: 'Modelo',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.memory),
                    hintText: _provider == AiProvider.gemini
                        ? 'gemini-2.0-flash'
                        : _provider == AiProvider.openrouter
                            ? 'openrouter/free'
                            : 'openrouter',
                  ),
                ),
              if (showModelDetect) ...[
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
              ],
              const SizedBox(height: 24),

              // === CENARIO ===
              Text('Cenário de fundo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(

                    menuMaxHeight: MediaQuery.of(context).size.height * 0.6,
                    isExpanded: true,                value: _selectedSceneId,
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

// === BOTTOM SHEET: GERENCIAR SLOTS DE API KEY ===

class _SlotManagerSheet extends StatefulWidget {
  final List<ApiKeySlot> slots;
  final String activeSlotId;
  final AiProvider provider;
  final VoidCallback onSaved;

  const _SlotManagerSheet({
    required this.slots,
    required this.activeSlotId,
    required this.provider,
    required this.onSaved,
  });

  @override
  State<_SlotManagerSheet> createState() => _SlotManagerSheetState();
}

class _SlotManagerSheetState extends State<_SlotManagerSheet> {
  late List<ApiKeySlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.slots);
  }

  void _addOrEditSlot({ApiKeySlot? existing}) {
    final nameCtrl = TextEditingController(text: existing?.label ?? '');
    final keyCtrl = TextEditingController(text: existing?.key ?? '');
    final isEdit = existing != null;
    final hint = widget.provider == AiProvider.gemini
        ? 'Ex: Gemini Principal, Gemini Trabalho'
        : 'Ex: OpenRouter Free, OpenRouter Pessoal';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar chave' : 'Nova chave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nome',
                border: const OutlineInputBorder(),
                hintText: hint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final label = nameCtrl.text.trim();
              final key = keyCtrl.text.trim();
              if (label.isEmpty || key.isEmpty) return;
              final id = existing?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString();
              await AppSettings.saveSlot(id, label, key);
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onSaved();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Chaves de API', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhuma chave cadastrada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            ..._slots.map((slot) => Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_key),
                title: Text(slot.label),
                subtitle: Text('${slot.key.substring(0, slot.key.length > 12 ? 12 : slot.key.length)}...',
                    style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _addOrEditSlot(existing: slot),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () async {
                        await AppSettings.deleteSlot(slot.id);
                        setState(() => _slots.removeWhere((s) => s.id == slot.id));
                      },
                    ),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _addOrEditSlot(),
            icon: const Icon(Icons.add),
            label: const Padding(padding: EdgeInsets.all(14), child: Text('Adicionar chave')),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
