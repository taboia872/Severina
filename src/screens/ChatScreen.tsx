/**
 * ChatScreen — Tela principal de conversa por voz com Severina.
 *
 *RN 0.79 New Arch | react-native-turbo-stt | react-native-sound | fetch API
 *
 * Fluxo:
 * 1. Botão "Falar com Severina" inicia STT (turbo-stt hook)
 * 2. Texto reconhecido → IA (OpenAI-compat API)
 * 3. Resposta → Google Translate TTS (MP3 stream)
 */

import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  TextInput,
  SafeAreaView,
  PermissionAndroid,
  Platform,
} from 'react-native';
import type { AppSettings } from '../data/appSettings';
import { toAiSettings } from '../data/appSettings';
import {
  askAi,
  buildMessages,
  fallbackResponse,
  simplifyError,
  type ChatMessage,
} from '../services/AiService';
import { useSpeechToText } from 'react-native-turbo-stt';
import {
  speak as ttsSpeak,
  stop as ttsStop,
} from '../services/GoogleTtsService';

type Props = {
  settings: AppSettings;
  onOpenSettings: () => void;
};

type DisplayMessage = {
  id: string;
  text: string;
  sender: 'user' | 'severina' | 'system';
};

type AvatarState = 'idle' | 'listening' | 'thinking' | 'speaking';

export function ChatScreen({ settings, onOpenSettings }: Props) {
  const [messages, setMessages] = useState<DisplayMessage[]>([]);
  const [isBusy, setIsBusy] = useState(false);
  const [avatarState, setAvatarState] = useState<AvatarState>('idle');
  const [statusText, setStatusText] = useState('Pronta para conversar.');
  const [textInput, setTextInput] = useState('');

  const conversationRef = useRef<ChatMessage[]>([]);
  const scrollViewRef = useRef<ScrollView>(null);
  const msgCounter = useRef(0);
  const processedRef = useRef(false);

  // Hook do TurboModule STT
  const { result, error: sttError, isListening, start, stop, destroy } =
    useSpeechToText();

  useEffect(() => {
    const name = settings.assistantName || 'Severina';
    setMessages([
      {
        id: 'opening',
        text: `Oi! Eu sou a ${name}. Aperte o botão e fale comigo.`,
        sender: 'severina',
      },
    ]);
    return () => {
      ttsStop();
      destroy();
    };
  }, []);

  // Watch STT results
  useEffect(() => {
    if (result?.text && result.isFinal && !processedRef.current) {
      processedRef.current = true;
      const transcript = result.text.trim();
      if (transcript) {
        addMessage(transcript, 'user');
        processMessage(transcript);
      }
      setAvatarState('idle');
    }
  }, [result]);

  // Watch STT errors
  useEffect(() => {
    if (sttError) {
      setAvatarState('idle');
      setStatusText(sttError.message || 'Erro no microfone.');
    }
  }, [sttError]);

  const addMessage = (text: string, sender: DisplayMessage['sender']) => {
    const msg: DisplayMessage = {
      id: `msg_${msgCounter.current++}`,
      text,
      sender,
    };
    setMessages((prev) => [...prev, msg]);
  };

  const requestMicPermission = async (): Promise<boolean> => {
    if (Platform.OS !== 'android') return true;
    const granted = await PermissionAndroid.request(
      PermissionAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Permissão de Microfone',
        message: 'A Severina precisa do microfone para te ouvir.',
        buttonPositive: 'Permitir',
        buttonNegative: 'Não',
      }
    );
    return granted === PermissionAndroid.RESULTS.GRANTED;
  };

  const handleRecord = async () => {
    // Se ocupado (falando), para tudo
    if (avatarState === 'speaking') {
      ttsStop();
      setAvatarState('idle');
      setStatusText('Pronta para conversar.');
      return;
    }

    // Se ouvindo, para
    if (isListening) {
      stop();
      setAvatarState('idle');
      setStatusText('Pronta para conversar.');
      return;
    }

    // Iniciar
    ttsStop();
    const hasPermission = await requestMicPermission();
    if (!hasPermission) {
      setStatusText('Permissão de microfone negada.');
      return;
    }

    processedRef.current = false;
    setAvatarState('listening');
    setStatusText('Estou ouvindo. Pode falar.');
    start('pt-BR');
  };

  const processMessage = async (text: string) => {
    const name = settings.assistantName || 'Severina';
    setIsBusy(true);
    setAvatarState('thinking');
    setStatusText(`${name} está pensando...`);

    conversationRef.current.push({ role: 'user', content: text });

    let answer = '';
    try {
      const aiSettings = toAiSettings(settings);
      const msgs = buildMessages(
        aiSettings.systemPrompt,
        conversationRef.current,
        aiSettings.historyTurns
      );
      answer = await askAi(msgs, aiSettings);
    } catch (error) {
      const detail = simplifyError(String((error as Error)?.message || error));
      setStatusText(detail);
      addMessage(detail, 'system');
      conversationRef.current.pop();
      setIsBusy(false);
      setAvatarState('idle');
      return;
    }

    conversationRef.current.push({ role: 'assistant', content: answer });
    addMessage(answer, 'severina');
    setStatusText(`${name} está falando...`);
    setAvatarState('speaking');

    // Falar via Google Translate TTS
    await ttsSpeak(answer, settings.voiceLang || 'pt-BR');

    setIsBusy(false);
    setAvatarState('idle');
    setStatusText('Pronta para conversar.');
  };

  const handleSendText = () => {
    const text = textInput.trim();
    if (!text || avatarState === 'thinking' || avatarState === 'speaking') return;
    setTextInput('');
    addMessage(text, 'user');
    processMessage(text);
  };

  const handleClearChat = () => {
    ttsStop();
    const name = settings.assistantName || 'Severina';
    conversationRef.current = [];
    setMessages([
      {
        id: 'cleared',
        text: `Oi! Eu sou a ${name}. Aperte o botão e fale comigo.`,
        sender: 'severina',
      },
    ]);
    setStatusText('Conversa limpa.');
    setAvatarState('idle');
  };

  const avatarEmoji: Record<AvatarState, string> = {
    idle: '🎙️',
    listening: '👂',
    thinking: '💭',
    speaking: '🗣️',
  };

  const recordLabel = isListening
    ? 'Parar'
    : avatarState === 'speaking'
    ? 'Parar'
    : `Falar com ${settings.assistantName || 'Severina'}`;

  return (
    <SafeAreaView style={styles.container}>
      {/* Topbar */}
      <View style={styles.topbar}>
        <TouchableOpacity style={styles.iconBtn} onPress={onOpenSettings}>
          <Text style={styles.iconBtnText}>⚙️</Text>
        </TouchableOpacity>
      </View>

      {/* Hero */}
      <View style={styles.hero}>
        <View
          style={[
            styles.avatar,
            avatarState !== 'idle' && styles.avatarActive,
          ]}
        >
          <Text style={styles.avatarText}>{avatarEmoji[avatarState]}</Text>
        </View>
        <Text style={styles.title}>
          {settings.assistantName || 'Severina'}
        </Text>
        <Text style={styles.subtitle}>
          Aperte o botão e converse comigo.
        </Text>
      </View>

      {/* Chat Area */}
      <ScrollView
        ref={scrollViewRef}
        style={styles.chatArea}
        contentContainerStyle={styles.chatContent}
        onContentSizeChange={() =>
          scrollViewRef.current?.scrollToEnd({ animated: true })
        }
      >
        {messages.map((msg) => (
          <View
            key={msg.id}
            style={[
              styles.message,
              msg.sender === 'user' && styles.messageUser,
              msg.sender === 'severina' && styles.messageSeverina,
              msg.sender === 'system' && styles.messageSystem,
            ]}
          >
            <Text style={styles.messageLabel}>
              {msg.sender === 'user'
                ? 'Você'
                : msg.sender === 'system'
                ? 'Sistema'
                : settings.assistantName || 'Severina'}
            </Text>
            <Text style={styles.messageText}>{msg.text}</Text>
          </View>
        ))}
      </ScrollView>

      {/* Bottom controls */}
      <View style={styles.bottom}>
        <View style={styles.controls}>
          <TouchableOpacity
            style={[styles.btnRecord, isListening && styles.btnRecording]}
            onPress={handleRecord}
          >
            <Text style={styles.btnRecordText}>
              {isListening ? '⏹️' : '🎙️'} {recordLabel}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnSmall} onPress={handleClearChat}>
            <Text style={styles.btnSmallText}>🗑️</Text>
          </TouchableOpacity>
        </View>

        {/* Text input */}
        <View style={styles.textInputArea}>
          <TextInput
            style={styles.textInput}
            placeholder="Ou digite aqui..."
            value={textInput}
            onChangeText={setTextInput}
            onSubmitEditing={handleSendText}
            editable={
              avatarState !== 'thinking' && avatarState !== 'speaking'
            }
          />
          <TouchableOpacity
            style={styles.btnSend}
            onPress={handleSendText}
            disabled={
              avatarState === 'thinking' || avatarState === 'speaking'
            }
          >
            <Text style={styles.btnSendText}>➤</Text>
          </TouchableOpacity>
        </View>

        <Text
          style={[
            styles.status,
            (avatarState === 'listening' || avatarState === 'speaking') &&
              styles.statusActive,
          ]}
        >
          {statusText}
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  topbar: { alignItems: 'center', paddingVertical: 10, paddingHorizontal: 60 },
  iconBtn: {
    position: 'absolute',
    right: 12,
    top: 8,
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#f0f0f7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconBtnText: { fontSize: 20 },
  hero: { alignItems: 'center', paddingVertical: 8 },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#f093fb',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  avatarActive: { backgroundColor: '#f5576c' },
  avatarText: { fontSize: 48 },
  title: { fontSize: 28, fontWeight: 'bold', color: '#2f2f3a' },
  subtitle: { fontSize: 15, color: '#6c6c7a', marginTop: 4 },
  chatArea: {
    flex: 1,
    marginHorizontal: 12,
    marginVertical: 8,
    backgroundColor: '#f8f9fb',
    borderRadius: 20,
    padding: 14,
  },
  chatContent: { flexGrow: 1 },
  message: { maxWidth: '88%', padding: 11, borderRadius: 18, marginBottom: 12 },
  messageUser: { alignSelf: 'flex-end', backgroundColor: '#667eea' },
  messageSeverina: { alignSelf: 'flex-start', backgroundColor: '#f093fb' },
  messageSystem: { alignSelf: 'center', backgroundColor: '#ececf4' },
  messageLabel: {
    fontSize: 12,
    fontWeight: 'bold',
    color: 'rgba(255,255,255,0.85)',
    marginBottom: 3,
  },
  messageText: { fontSize: 15, color: '#fff', lineHeight: 20 },
  bottom: { padding: 12 },
  controls: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  btnRecord: {
    flex: 1,
    height: 54,
    borderRadius: 27,
    backgroundColor: '#f093fb',
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnRecording: { backgroundColor: '#c62828' },
  btnRecordText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  btnSmall: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#f0f0f7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnSmallText: { fontSize: 18 },
  textInputArea: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 8,
  },
  textInput: {
    flex: 1,
    height: 44,
    borderRadius: 22,
    borderWidth: 2,
    borderColor: '#ececf3',
    paddingHorizontal: 16,
    fontSize: 15,
  },
  btnSend: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#f093fb',
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnSendText: { color: '#fff', fontSize: 18 },
  status: { textAlign: 'center', fontSize: 14, color: '#6c6c7a', marginTop: 6 },
  statusActive: { color: '#f5576c', fontWeight: '600' },
});
