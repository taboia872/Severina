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

## Build

```bash
flutter pub get
flutter build apk --debug
```

O CI no GitHub Actions builda automaticamente a cada push na `main`.
