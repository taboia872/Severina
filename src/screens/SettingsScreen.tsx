/**
 * SettingsScreen — Configurar IA, voz e personalidade da Severina.
 *
 * Campos:
 * - Nome do assistente
 * - Personalidade (preset dropdown)
 * - System prompt (editável)
 * - Endpoint da API (OpenAI-compat)
 * - API Key
 * - Modelo
 * - Temperatura / Max tokens / Histórico
 * - Idioma da voz
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  SafeAreaView,
  Picker,
} from 'react-native';
import type { AppSettings } from '../data/appSettings';
import { PERSONALITY_PRESETS } from '../data/appSettings';

type Props = {
  settings: AppSettings;
  onSave: (s: AppSettings) => void;
  onBack: () => void;
};

export function SettingsScreen({ settings, onSave, onBack }: Props) {
  const [draft, setDraft] = useState<AppSettings>({ ...settings });

  const update = <K extends keyof AppSettings>(
    key: K,
    value: AppSettings[K]
  ) => {
    setDraft((prev) => ({ ...prev, [key]: value }));
  };

  const loadPreset = (key: string) => {
    if (key && PERSONALITY_PRESETS[key]) {
      update('systemPrompt', PERSONALITY_PRESETS[key].prompt);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Topbar */}
      <View style={styles.topbar}>
        <TouchableOpacity style={styles.backBtn} onPress={onBack}>
          <Text style={styles.backBtnText}>← Voltar</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Assistente */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>🤖 Assistente</Text>

          <Text style={styles.label}>Nome da personagem</Text>
          <TextInput
            style={styles.input}
            value={draft.assistantName}
            onChangeText={(v) => update('assistantName', v)}
            placeholder="Severina"
          />

          <Text style={styles.label}>Carregar modelo pronto</Text>
          <View style={styles.pickerWrap}>
            <Picker
              selectedValue=""
              onValueChange={loadPreset}
              mode="dropdown"
            >
              <Picker.Item label="Não alterar" value="" />
              {Object.entries(PERSONALITY_PRESETS).map(([key, p]) => (
                <Picker.Item key={key} label={p.label} value={key} />
              ))}
            </Picker>
          </View>

          <Text style={styles.label}>Personalidade / Pré-prompt</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            value={draft.systemPrompt}
            onChangeText={(v) => update('systemPrompt', v)}
            multiline
            numberOfLines={4}
            textAlignVertical="top"
          />
        </View>

        {/* IA */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>🧠 IA</Text>

          <Text style={styles.label}>Endpoint da API (OpenAI-compat)</Text>
          <TextInput
            style={styles.input}
            value={draft.aiEndpoint}
            onChangeText={(v) => update('aiEndpoint', v)}
            placeholder="https://openrouter.ai/api/v1/chat/completions"
            autoCapitalize="none"
            autoCorrect={false}
          />

          <Text style={styles.label}>API Key</Text>
          <TextInput
            style={styles.input}
            value={draft.apiKey}
            onChangeText={(v) => update('apiKey', v)}
            placeholder="sk-..."
            secureTextEntry
            autoCapitalize="none"
            autoCorrect={false}
          />

          <Text style={styles.label}>Modelo</Text>
          <TextInput
            style={styles.input}
            value={draft.aiModel}
            onChangeText={(v) => update('aiModel', v)}
            placeholder="openrouter/free"
            autoCapitalize="none"
            autoCorrect={false}
          />

          <View style={styles.row}>
            <View style={styles.col}>
              <Text style={styles.label}>Criatividade</Text>
              <TextInput
                style={styles.input}
                value={String(draft.temperature)}
                onChangeText={(v) =>
                  update('temperature', Number(v) || 0.8)
                }
                keyboardType="numeric"
              />
            </View>
            <View style={styles.col}>
              <Text style={styles.label}>Tamanho máx.</Text>
              <TextInput
                style={styles.input}
                value={String(draft.maxTokens)}
                onChangeText={(v) =>
                  update('maxTokens', Number(v) || 120)
                }
                keyboardType="numeric"
              />
            </View>
          </View>

          <Text style={styles.label}>Turnos de histórico</Text>
          <TextInput
            style={styles.input}
            value={String(draft.historyTurns)}
            onChangeText={(v) => update('historyTurns', Number(v) || 6)}
            keyboardType="numeric"
          />
        </View>

        {/* Voz */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>🔊 Voz</Text>
          <Text style={styles.label}>Idioma da voz</Text>
          <View style={styles.pickerWrap}>
            <Picker
              selectedValue={draft.voiceLang}
              onValueChange={(v) => update('voiceLang', v)}
              mode="dropdown"
            >
              <Picker.Item label="Português Brasil" value="pt-BR" />
              <Picker.Item label="Português Portugal" value="pt-PT" />
              <Picker.Item label="Inglês EUA" value="en-US" />
              <Picker.Item label="Inglês Reino Unido" value="en-GB" />
              <Picker.Item label="Espanhol" value="es-ES" />
              <Picker.Item label="Francês" value="fr-FR" />
              <Picker.Item label="Alemão" value="de-DE" />
              <Picker.Item label="Italiano" value="it-IT" />
              <Picker.Item label="Japonês" value="ja-JP" />
            </Picker>
          </View>
        </View>

        {/* Save */}
        <TouchableOpacity
          style={styles.btnSave}
          onPress={() => onSave(draft)}
        >
          <Text style={styles.btnSaveText}>Salvar e voltar</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  topbar: { alignItems: 'flex-start', paddingVertical: 10, paddingHorizontal: 12 },
  backBtn: { paddingVertical: 6, paddingHorizontal: 12 },
  backBtnText: { fontSize: 16, color: '#667eea', fontWeight: '600' },
  content: { flex: 1, paddingHorizontal: 16 },
  section: {
    backgroundColor: '#f8f9fb',
    borderRadius: 16,
    padding: 14,
    marginBottom: 12,
  },
  sectionTitle: { fontSize: 16, fontWeight: 'bold', color: '#f5576c', marginBottom: 10 },
  label: { fontSize: 14, fontWeight: '600', color: '#2f2f3a', marginBottom: 4, marginTop: 8 },
  input: {
    borderWidth: 2,
    borderColor: '#ececf3',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 15,
    backgroundColor: '#fff',
  },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  pickerWrap: {
    borderWidth: 2,
    borderColor: '#ececf3',
    borderRadius: 12,
    backgroundColor: '#fff',
    overflow: 'hidden',
  },
  row: { flexDirection: 'row', gap: 10 },
  col: { flex: 1 },
  btnSave: {
    backgroundColor: '#f093fb',
    borderRadius: 27,
    height: 54,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  btnSaveText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
