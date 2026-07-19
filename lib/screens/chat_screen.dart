import 'dart:async';
import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../widgets/severina_scene.dart';

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
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await AppSettings.I.load();
    await SttService.init();
    if (mounted) setState(() => _loaded = true);
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
          // Continua 'thinking' ate o audio comecar de fato.
          _state = SeverinaState.thinking;
        });
      }

      await TtsService.speak(
        clean,
        onStart: () async {
          // Atraso de 1s para sincronizar a animacao com o audio real.
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() => _state = SeverinaState.speaking);
        },
        onComplete: () {
          if (mounted) setState(() => _state = SeverinaState.idle);
        },
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

  void _resetSession() {
    TtsService.stop();
    setState(() {
      _conversation.clear();
      _partialText = '';
      _lastHeard = '';
      _lastResponse = '';
      _state = SeverinaState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // === Cenário de fundo cobrindo TODA a tela ===
          Positioned.fill(
            child: _loaded
                ? _buildScene()
                : const Center(child: CircularProgressIndicator()),
          ),

          // === AppBar minimal (vidro, flutuante no topo) ===
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/settings');
                            // Recarrega settings ao voltar (bug do seletor de cenário)
                            if (mounted) {
                              await AppSettings.I.load();
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ),
          ),

          // === Status text (centralizado) ===
          Positioned(
            left: 24,
            right: 24,
            bottom: 120,
            child: Text(
              _statusText(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[800],
                  ),
            ),
          ),

          // === Botão lixeira + Microfone (vidro, flutuante embaixo) ===
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 22),
                          color: Colors.grey[700],
                          tooltip: 'Limpar conversa',
                          onPressed: _state == SeverinaState.idle ? _resetSession : null,
                        ),
                        const Spacer(),
                        Listener(
                          onPointerDown: (_) => _onMicDown(),
                          onPointerUp: (_) => _onMicUp(),
                          onPointerCancel: (_) => _onMicUp(),
                          child: AbsorbPointer(
                            absorbing: _state != SeverinaState.idle && _state != SeverinaState.listening,
                            child: AnimatedOpacity(
                              opacity: _micEnabled ? 1.0 : 0.35,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                width: 72,
                                height: 72,
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
                                            blurRadius: 16,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  _state == SeverinaState.listening
                                      ? Icons.mic
                                      : Icons.mic_none,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
          ),
        ],
      ),
    );
  }


  Widget _buildScene() {
    final faceState = switch (_state) {
      SeverinaState.idle => SeverinaFaceState.idle,
      SeverinaState.listening => SeverinaFaceState.listening,
      SeverinaState.thinking => SeverinaFaceState.thinking,
      SeverinaState.speaking => SeverinaFaceState.speaking,
    };

    return SeverinaScene(state: faceState);
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
