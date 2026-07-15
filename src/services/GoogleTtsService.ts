/**
 * GoogleTtsService — Voz do Google Tradutor em React Native
 *
 * Endpoint: translate.google.com/translate_tts
 * Retorna MP3 direto. Tocado via react-native-sound.
 *
 * O texto é fatiado em chunks de no máx 180 chars (limite do endpoint)
 * e tocados sequencialmente.
 */

import Sound from 'react-native-sound';

// Modo que permite tocar áudio mesmo em silencioso
Sound.setCategory('Playback', true);

let currentSound: Sound | null = null;
let isSpeaking = false;
let speakQueue: string[] = [];
let onDoneCallback: (() => void) | null = null;

/**
 * Fatia texto em chunks de no máx maxLen chars,
 * quebrando em pontuação natural (., !, ?) quando possível.
 */
function splitForTTS(text: string, maxLen = 180): string[] {
  const clean = String(text || '').replace(/\s+/g, ' ').trim();
  if (!clean) return [];

  const parts = clean.match(/[^.!?]+[.!?]+|[^.!?]+$/g) || [clean];
  const chunks: string[] = [];
  let current = '';

  for (const part of parts) {
    const next = `${current} ${part}`.trim();
    if (next.length <= maxLen) {
      current = next;
    } else {
      if (current) chunks.push(current);
      // Se o pedaço sozinho excede o limite, corta no meio
      current = part.trim().slice(0, maxLen);
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

/**
 * Constrói a URL do Google Translate TTS.
 */
function buildTtsUrl(text: string, lang: string): string {
  const encoded = encodeURIComponent(text);
  const tl = encodeURIComponent(lang);
  return `https://translate.google.com/translate_tts?ie=UTF-8&tl=${tl}&client=tw-ob&q=${encoded}`;
}

/**
 * Toca um único chunk de áudio via react-native-sound.
 * Baixa da URL e toca — Sound carrega via streaming nativo.
 */
function playChunk(url: string): Promise<void> {
  return new Promise((resolve, reject) => {
    currentSound = new Sound(url, '', (error) => {
      if (error) {
        console.warn('[GoogleTts] Erro ao carregar:', error);
        reject(error);
        return;
      }
      currentSound?.play((success) => {
        if (currentSound) {
          currentSound.release();
          currentSound = null;
        }
        if (success) {
          resolve();
        } else {
          reject(new Error('Playback failed'));
        }
      });
    });
  });
}

/**
 * Fala um texto completo usando Google Translate TTS.
 * Fatiar → enfileirar chunks → tocar sequencialmente.
 */
export async function speak(text: string, lang = 'pt-BR'): Promise<void> {
  // Se já está falando, para tudo e recomeça
  stop();

  const chunks = splitForTTS(text, 180);
  if (!chunks.length) return;

  isSpeaking = true;
  speakQueue = [...chunks];

  for (const chunk of speakQueue) {
    if (!isSpeaking) break; // foi cancelado
    try {
      const url = buildTtsUrl(chunk, lang);
      await playChunk(url);
    } catch (error) {
      console.warn('[GoogleTts] Falha em chunk:', error);
      // Continua para o próximo chunk mesmo se um falhar
    }
  }

  finishSpeaking();
}

/**
 * Para toda reprodução imediatamente.
 */
export function stop(): void {
  isSpeaking = false;
  speakQueue = [];

  if (currentSound) {
    currentSound.stop();
    currentSound.release();
    currentSound = null;
  }

  if (onDoneCallback) {
    onDoneCallback();
    onDoneCallback = null;
  }
}

/**
 * Retorna se está falando agora.
 */
export function isCurrentlySpeaking(): boolean {
  return isSpeaking;
}

/**
 * Registra callback para quando terminar de falar.
 */
export function onDone(cb: () => void): void {
  onDoneCallback = cb;
}

/**
 * Callback interno de finalização.
 */
function finishSpeaking(): void {
  isSpeaking = false;
  speakQueue = [];
  currentSound = null;
  if (onDoneCallback) {
    onDoneCallback();
    onDoneCallback = null;
  }
}
