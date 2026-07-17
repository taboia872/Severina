import 'dart:async';
import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../widgets/severina_face.dart';

enum SeverinaState { idle, listening, thinking, speaking }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  SeverinaState _state = SeverinaState.idle;
  String _lastHeard = '';
  String _lastResponse = '';
  final List<Map<String, String>> _conversation = [];
  String _partialText = '';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await AppSettings.I.load();
    await SttService.init();
  }

  bool get _micEnabled => _state == SeverinaState.idle;

  // === Press-To-Talk ===

  Future<void> _onMicDown() async {
    if (_state != SeverinaState.idle) return;

    setState(() {
      _state = SeverinaState.listening;
      _lastHeard = '';
      _partialText = '';
    });

    await SttService.startListening(
      onResult: (text, isFinal) {
        if (text.isEmpty) return;
        if (mounted) {
          setState(() {
            _partialText = text;
            _lastHeard = text;
          });
        }
      },
    );
  }

  Future<void> _onMicUp() async {
    if (_state != SeverinaState.listening) return;

    await SttService.stopListening();

    // Pequeno delay para garantir que o último callback onResult chegue
    await Future.delayed(const Duration(milliseconds: 300));

    final text = _partialText.trim();

    if (text.isNotEmpty) {
      await _processText(text);
    } else {
      if (mounted) setState(() => _state = SeverinaState.idle);
    }
  }

  Future<void> _processText(String userText) async {
    if (mounted) setState(() => _state = SeverinaState.thinking);

    _conversation.add({'role': 'user', 'content': userText});

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

      if (clean.isEmpty) {
        if (mounted) setState(() => _state = SeverinaState.idle);
        return;
      }

      if (mounted) {
        setState(() {
          _lastResponse = clean;
          _state = SeverinaState.speaking;
        });
      }

      await TtsService.speak(
        clean,
        onStart: () => setState(() => _state = SeverinaState.speaking),
        onComplete: () => setState(() => _state = SeverinaState.idle),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResponse = 'Erro: $e';
          _state = SeverinaState.idle;
        });
      }
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

            // --- Botão microfone (Press-To-Talk) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Listener(
                onPointerDown: (_) => _onMicDown(),
                onPointerUp: (_) => _onMicUp(),
                onPointerCancel: (_) => _onMicUp(),
                child: AbsorbPointer(
                  absorbing: _state != SeverinaState.idle && _state != SeverinaState.listening,
                  child: AnimatedOpacity(
                  opacity: _micEnabled ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _state == SeverinaState.listening
                          ? Colors.red[400]
                          : s.primary,
                      boxShadow: _micEnabled
                          ? [
                              BoxShadow(
                                color: (_state == SeverinaState.listening
                                        ? Colors.red[400]!
                                        : s.primary)
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _state == SeverinaState.listening
                          ? Icons.mic
                          : Icons.mic_none,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
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
    final faceState = switch (_state) {
      SeverinaState.idle => SeverinaFaceState.idle,
      SeverinaState.listening => SeverinaFaceState.listening,
      SeverinaState.thinking => SeverinaFaceState.thinking,
      SeverinaState.speaking => SeverinaFaceState.speaking,
    };

    return SeverinaFace(state: faceState);
  }

  String _statusText() {
    return switch (_state) {
      SeverinaState.idle => 'Segure o botão para falar',
      SeverinaState.listening => _lastHeard.isEmpty
          ? 'Ouvindo...'
          : '"$_lastHeard"',
      SeverinaState.thinking => 'Pensando...',
      SeverinaState.speaking => _lastResponse,
    };
  }
}
