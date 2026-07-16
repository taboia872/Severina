import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';

enum BmoState { idle, listening, thinking, speaking }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  BmoState _state = BmoState.idle;
  String _lastHeard = '';
  String _lastResponse = '';
  final List<Map<String, String>> _conversation = [];

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await AppSettings.I.load();
    await SttService.init();
  }

  Future<void> _toggleMic() async {
    if (_state == BmoState.listening) {
      await SttService.stop();
      setState(() => _state = BmoState.idle);
      return;
    }

    if (_state == BmoState.speaking || _state == BmoState.thinking) {
      await TtsService.stop();
    }

    setState(() {
      _state = BmoState.listening;
      _lastHeard = '';
    });

    await SttService.listen(
      onResult: (text, isFinal) {
        if (text.isEmpty) return;
        setState(() => _lastHeard = text);
        if (isFinal && text.trim().isNotEmpty) {
          _processText(text.trim());
        }
      },
    );
  }

  Future<void> _processText(String userText) async {
    setState(() => _state = BmoState.thinking);

    _conversation.add({'role': 'user', 'content': userText});

    // mantém histórico curto (últimas 6 mensagens) + system prompt
    final history = _conversation.length > 6
        ? _conversation.sublist(_conversation.length - 6)
        : List<Map<String, String>>.from(_conversation);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': AppSettings.I.systemPrompt},
      ...history,
    ];

    try {
      final response = await AiService.chat(messages: messages);
      final clean = response.trim();
      _conversation.add({'role': 'assistant', 'content': clean});
      setState(() {
        _lastResponse = clean;
        _state = BmoState.speaking;
      });

      await TtsService.speak(
        clean,
        onStart: () => setState(() => _state = BmoState.speaking),
        onComplete: () => setState(() => _state = BmoState.idle),
      );
    } catch (e) {
      setState(() {
        _lastResponse = 'Deu erro: $e';
        _state = BmoState.idle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- AppBar minimal ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    AppSettings.I.assistantName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: s.primary,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),

            // --- Visual central: rostinho da Severina ---
            Expanded(
              child: Center(
                child: _buildFace(s),
              ),
            ),

            // --- Status text ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusText(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),

            // --- Botão microfone ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == BmoState.listening
                        ? Colors.red[400]
                        : s.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_state == BmoState.listening
                                ? Colors.red[400]!
                                : s.primary)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _state == BmoState.listening ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFace(ColorScheme s) {
    final eyeColor = _state == BmoState.thinking
        ? Colors.amber
        : _state == BmoState.speaking
            ? Colors.green
            : _state == BmoState.listening
                ? Colors.red[300]!
                : s.primary;

    final mouthWidth = _state == BmoState.speaking ? 50.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Olhos
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eye(eyeColor),
            const SizedBox(width: 32),
            _eye(eyeColor),
          ],
        ),
        const SizedBox(height: 20),
        // Boca
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: mouthWidth,
          height: _state == BmoState.speaking ? 12 : 6,
          decoration: BoxDecoration(
            color: eyeColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _eye(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: _state == BmoState.thinking ? 4 : 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _statusText() {
    return switch (_state) {
      BmoState.idle => 'Toca no microfone para falar',
      BmoState.listening => _lastHeard.isEmpty
          ? 'Ouvindo...'
          : '"$_lastHeard"',
      BmoState.thinking => 'Pensando...',
      BmoState.speaking => _lastResponse,
    };
  }
}
