/**
 * Severina — App principal (router de telas)
 *
 * Telas:
 * 1. ChatScreen — conversa por voz (principal)
 * 2. SettingsScreen — configurar IA, voz, personalidade
 *
 * Estado global de settings é carregado do AsyncStorage na inicialização.
 */

import React, { useState, useEffect } from 'react';
import { ChatScreen } from './screens/ChatScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { loadSettings, saveSettings, type AppSettings } from './data/appSettings';

type Screen = 'chat' | 'settings';

export default function App() {
  const [screen, setScreen] = useState<Screen>('chat');
  const [settings, setSettings] = useState<AppSettings | null>(null);

  useEffect(() => {
    loadSettings().then(setSettings);
  }, []);

  if (!settings) return null; // loading

  return (
    <>
      {screen === 'chat' && (
        <ChatScreen
          settings={settings}
          onOpenSettings={() => setScreen('settings')}
        />
      )}
      {screen === 'settings' && (
        <SettingsScreen
          settings={settings}
          onSave={(s) => {
            setSettings(s);
            saveSettings(s);
            setScreen('chat');
          }}
          onBack={() => setScreen('chat')}
        />
      )}
    </>
  );
}
