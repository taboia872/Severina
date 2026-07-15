/**
 * AiService — Integração com APIs OpenAI-compatíveis.
 *
 * Substitui os 4 providers do app web original (Local/OpenRouter/OpenAI-compat/fallback)
 * por um único endpoint OpenAI-compatível que engloba OpenRouter, OpenAI, Groq, etc.
 *
 * Arquitetura:
 * - Endpoint da API (URL)
 * - API Key (Bearer token)
 * - Model name
 * - System prompt (personality)
 * - Conversation history (last N turns)
 */

export type ChatMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export type AiSettings = {
  endpoint: string;
  apiKey: string;
  model: string;
  systemPrompt: string;
  temperature: number;
  maxTokens: number;
  historyTurns: number;
};

/**
 * Envia mensagens para uma API OpenAI-compatível e retorna a resposta.
 */
export async function askAi(
  messages: ChatMessage[],
  settings: AiSettings
): Promise<string> {
  const { endpoint, apiKey, model, temperature, maxTokens } = settings;

  if (!endpoint) throw new Error('Endpoint da API não configurado.');
  if (!model) throw new Error('Modelo não configurado.');

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }

  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model,
      messages,
      max_tokens: maxTokens,
      temperature,
      stream: false,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    throw new Error(errorText || `HTTP ${response.status}`);
  }

  const data = await response.json();

  let content: string =
    data?.choices?.[0]?.message?.content ??
    data?.choices?.[0]?.text ??
    data?.content ??
    data?.response ??
    '';

  if (Array.isArray(content)) {
    content = content
      .map((p: any) => (typeof p === 'string' ? p : p.text || p.content || ''))
      .join(' ');
  }

  if (!content) throw new Error('A IA respondeu em formato ilegível.');

  return String(content).trim();
}

/**
 * Constrói o array de mensagens com system prompt + histórico.
 */
export function buildMessages(
  systemPrompt: string,
  conversation: ChatMessage[],
  historyTurns: number
): ChatMessage[] {
  const system: ChatMessage = {
    role: 'system',
    content: systemPrompt,
  };
  const recent = conversation.slice(-historyTurns);
  return [system, ...recent];
}

/**
 * Resposta de fallback (sem IA) — mantém o mesmo espírito do original.
 */
export function fallbackResponse(text: string, name = 'Severina'): string {
  const lower = String(text || '').toLowerCase();
  if (lower.includes('oi') || lower.includes('olá') || lower.includes('ola'))
    return `Oi! Eu sou a ${name}. Sobre o que vamos conversar?`;
  if (lower.includes('tudo bem'))
    return 'Tudo bem por aqui. E você, está bem?';
  if (lower.includes('piada'))
    return 'Por que o robô foi ao médico? Porque estava com um parafuso solto.';
  if (lower.includes('nome'))
    return `Meu nome é ${name}. Eu vim conversar com você.`;
  return 'Que interessante. Me conta mais um pouquinho.';
}

/**
 * Simplifica mensagens de erro para a interface.
 */
export function simplifyError(raw: string): string {
  const msg = String(raw || 'erro desconhecido');
  if (msg.includes('Failed to fetch') || msg.includes('NetworkError'))
    return 'Não consegui conectar na API. Verifique o endpoint e a chave.';
  if (msg.includes('401') || msg.includes('403'))
    return 'API Key rejeitada. Verifique se está correta.';
  if (msg.includes('404'))
    return 'Modelo não encontrado. Verifique o nome do modelo.';
  return `Falha na IA: ${msg.slice(0, 180)}`;
}
