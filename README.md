# Severina

Assistente por voz para crianças (~5 anos), em Flutter.

## Pipeline

```
 microfone (STT local) → API (LLM cloud) → Google TTS (MP3) → speaker
```

- **STT:** `speech_to_text` (Android SpeechRecognizer nativo, local) — auto-para após 8s de silêncio
- **LLM:** HTTP POST para múltiplos provedores (ver aba Provedores abaixo)
- **TTS:** Google Translate TTS → MP3 → `audioplayers` (retry com backoff exponencial)
- **Settings:** `shared_preferences`

## Estrutura

```
lib/
  main.dart                    # App + router (setup → chat)
  data/app_settings.dart       # Config + presets + persistência + slots de API key
  services/
    stt_service.dart           # Captura de voz (local, timeout 8s)
    ai_service.dart            # Chamada LLM (HTTP, Gemini/OpenAI-compat)
    tts_service.dart           # Google Translate TTS + playback (retry 3x)
  screens/
    setup_screen.dart          # Primeira config (API key, provedor, modelo)
    chat_screen.dart           # Tela principal (voz + face)
    settings_screen.dart       # Editar config, chaves, cenários
```

## Download

APKs pré-compilados ficam em **[GitHub Releases](https://github.com/taboia872/Severina/releases)**.

1. Abra a página de releases
2. Baixe `severina-vX.Y.Z.apk` da versão desejada
3. Instale no Android (ative "Fontes desconhecidas" se necessário)
4. Assinatura fixa entre builds → atualiza sem desinstalar

## Features

- **Voz:** STT (Android nativo, local) → LLM cloud → Google TTS → playback
- **STT com timeout:** auto-para após 8s de silêncio (não trava ouvindo indefinidamente)
- **UI:** corpo do robô + cabeça CustomPainter sobre cenário de fundo
- **3 cenários** trocáveis (yard, toy_room, library)
- **Fullscreen imersivo** (SystemUiMode.manual, overlays: [])
- **Transição suave** entre telas (fade + slide, 1s)
- **Multi-provedor LLM:** Gemini, OpenRouter, Groq, AIHorde e Personalizado (endpoint custom)
- **Slots de API Key:** múltiplas chaves com nomes amigáveis, troca rápida
- **Detecção de modelos:** lista modelos disponíveis para **todos** os provedores (botão "Listar modelos disponíveis")
- **Endpoint customizado:** provedor Personalizado com URL OpenAI-compatible + API key
- **System prompt:** Severina como babá gentil (sem emojis, sem thinking, respostas curtas)
- **PTT (Press-to-Talk):** botão de microfone 72px com guards de estado + feedback tátil (HapticFeedback)
- **Erros amigáveis:** SnackBar com mensagens em PT-BR (sem internet, API key inválida, modelo não encontrado, rate limit)
- **Confirmação ao resetar:** AlertDialog antes de apagar tudo (preserva chaves de API)
- **Retry no TTS:** 3 tentativas com backoff exponencial (1s/2s/4s) para 429/5xx do Google
- **Gemini API key via header** (`x-goog-api-key`) em vez de query string

### Provedores suportados

| Provedor | API | API Key | Busca de modelos |
|---|---|---|---|
| **Gemini** (Google) | REST `generateContent` | Sim (`x-goog-api-key`) | Sim (modelos Gemini) |
| **OpenRouter** | OpenAI-compatible | Sim (`Bearer`) | Sim (modelos gratuitos) |
| **Groq** | OpenAI-compatible | Sim (`Bearer`) | Sim (via `/models`) |
| **AIHorde** | OpenAI-compatible | Sim (`Bearer`) | Sim (via `/models`) |
| **Personalizado** | OpenAI-compatible | Sim ou não | Sim (via `/models` no endpoint informado) |

## Build

```bash
flutter pub get
flutter build apk --debug
```

O CI no GitHub Actions builda automaticamente a cada push na `main`.

### Keystore (CI)

O keystore de assinatura **não está no repositório** — é injetado via GitHub Secrets:
- `SEVERINA_KEYSTORE_BASE64` — keystore em base64
- `KEY_ALIAS` — alias da chave
- `KEY_PASSWORD` — senha da chave
- `STORE_PASSWORD` — senha do keystore

O workflow decodifica o keystore de Secret antes do build e as senhas são lidas de env vars.

## Release (manual)

Para gerar um novo release com APK anexado:

```bash
git tag v0.2.0
git push origin v0.2.0
```

O workflow `.github/workflows/release.yml` dispara em push de tag `v*`, builda APK release assinado e cria a release automaticamente no GitHub.
