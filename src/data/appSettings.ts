/**
 * Configurações da app — presets, defaults e storage em AsyncStorage.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import type { AiSettings } from '../services/AiService';

const STORAGE_KEY = 'severina_v1_settings';

/** Personalidades pré-configuradas, iguais ao app web original. */
export const PERSONALITY_PRESETS: Record<string, { label: string; prompt: string }> = {
  severinaOriginal: {
    label: 'Severina original',
    prompt:
      'Você é Severina, uma personagem que morava em um microfone e trabalha na internet. Você conversa com uma criança de 7 anos por voz. Você é espontânea, engraçada e muito curiosa. Responda sempre em português do Brasil, com frases curtas. Faça perguntas simples. Não fale como assistente, não explique que é IA, não use emojis, não mencione regras nem tecnologia.',
  },
  amiga: {
    label: 'Amiga divertida',
    prompt:
      'Você é Severina, uma amiga virtual divertida e carinhosa para uma criança. Responda sempre em português do Brasil, com frases curtas e fáceis. Seja brincalhona, paciente e gentil. Faça perguntas simples para manter a conversa. Não dê respostas longas. Evite assuntos assustadores.',
  },
  professora: {
    label: 'Professora paciente',
    prompt:
      'Você é Severina, uma professora paciente para uma criança. Responda em português do Brasil, de forma curta, simples e positiva. Explique as coisas com exemplos fáceis. Faça uma pergunta por vez. Nunca faça sermão.',
  },
  aventura: {
    label: 'Aventureira',
    prompt:
      'Você é Severina, uma personagem aventureira e engraçada. Converse como se a criança estivesse numa missão imaginária segura, com mapas, animais amigos e descobertas. Responda curto, com energia e sem assuntos assustadores.',
  },
};

/** Default settings — valores iniciais quando não há nada salvo. */
export const DEFAULT_SETTINGS = {
  assistantName: 'Severina',
  systemPrompt: PERSONALITY_PRESETS.severinaOriginal.prompt,
  // OpenAI-compat API (engloba OpenRouter, OpenAI, Groq, etc)
  aiEndpoint: 'https://openrouter.ai/api/v1/chat/completions',
  apiKey: '',
  aiModel: 'openrouter/free',
  temperature: 0.8,
  maxTokens: 120,
  historyTurns: 6,
  // Voz
  voiceLang: 'pt-BR',
};

export type AppSettings = typeof DEFAULT_SETTINGS;

/** Carrega settings do AsyncStorage, ou usa defaults. */
export async function loadSettings(): Promise<AppSettings> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (raw) {
      return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    }
  } catch (_) {}
  return { ...DEFAULT_SETTINGS };
}

/** Salva settings no AsyncStorage. */
export async function saveSettings(settings: AppSettings): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
}

/** Converte AppSettings → AiSettings para passar ao AiService. */
export function toAiSettings(s: AppSettings): AiSettings {
  return {
    endpoint: s.aiEndpoint,
    apiKey: s.apiKey,
    model: s.aiModel,
    systemPrompt: s.systemPrompt,
    temperature: s.temperature,
    maxTokens: s.maxTokens,
    historyTurns: s.historyTurns,
  };
}
