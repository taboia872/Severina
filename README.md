# Severina

Assistente por voz para crianças (~5 anos), em Flutter.

## Pipeline

```
 microfone (STT local) → API (LLM cloud) → Google TTS (MP3) → speaker
```

- **STT:** `speech_to_text` (Android SpeechRecognizer nativo, local)
- **LLM:** HTTP POST para qualquer endpoint OpenAI-compatible (OpenRouter, OpenAI, custom)
- **TTS:** Google Translate TTS → MP3 → `audioplayers`
- **Settings:** `shared_preferences`

## Estrutura

```
lib/
  main.dart                    # App + router (setup → chat)
  data/app_settings.dart       # Config + presets + persistência
  services/
    stt_service.dart           # Captura de voz (local)
    ai_service.dart            # Chamada LLM (HTTP)
    tts_service.dart            # Google Translate TTS + playback
  screens/
    setup_screen.dart          # Primeira config (API key, preset)
    chat_screen.dart           # Tela principal (voz + face)
    settings_screen.dart       # Editar config
```

## Download

APKs pré-compilados ficam em **[GitHub Releases](https://github.com/taboia872/Severina/releases)**.

1. Abra a página de releases
2. Baixe `severina-vX.Y.Z.apk` da versão desejada
3. Instale no Android (ative "Fontes desconhecidas" se necessário)
4. Assinatura fixa entre builds → atualiza sem desinstalar

## Features

- **Voz:** STT (Android nativo, local) → LLM cloud → Google TTS → playback
- **UI:** corpo do robô + cabeça CustomPainter sobre cenário de fundo
- **3 cenários** trocáveis (yard, toy_room, library)
- **Fullscreen imersivo** (SystemUiMode.immersiveSticky)
- **Transição suave** entre telas (fade + slide, 1s)
- **Multi-provedor LLM:** Gemini (default) e OpenRouter, com múltiplos slots de API Key
- **System prompt:** Severina como babá gentil (sem emojis, sem thinking, respostas curtas)
- **PTT (Press-to-Talk):** botão de microfone 72px com guards de estado

## Build

```bash
flutter pub get
flutter build apk --debug
```

O CI no GitHub Actions builda automaticamente a cada push na `main`.

## Release (manual)

Para gerar um novo release com APK anexado:

```bash
git tag v0.1.0
git push origin v0.1.0
```

O workflow `.github/workflows/release.yml` dispara em push de tag `v*`, builda APK release assinado e cria a release automaticamente no GitHub.
