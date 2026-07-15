/**
 * SttService — Re-export do hook useSpeechToText de react-native-turbo-stt
 *
 * react-native-turbo-stt é um TurboModule nativo (New Arch).
 * A API é hook-based: useSpeechToText() → { result, error, isListening, start, stop, destroy }
 *
 * Uso direto no ChatScreen via hook (não dá pra chamar hooks fora de componentes).
 */

export { useSpeechToText } from 'react-native-turbo-stt';
export type SpeechToTextHook = ReturnType<
  typeof import('react-native-turbo-stt').useSpeechToText
>;
