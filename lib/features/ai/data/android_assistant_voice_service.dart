import 'package:flutter/services.dart';

/// Thin Flutter bridge to Android's on-device Arabic speech APIs.
///
/// This channel deliberately exposes no online recognition fallback.
class AndroidAssistantVoiceService {
  const AndroidAssistantVoiceService();

  static const MethodChannel _channel = MethodChannel(
    'com.byepro.finance/assistant_voice',
  );

  Future<String> recognizeArabicSpeech() async {
    final transcript = await _channel.invokeMethod<String>(
      'recognizeArabicSpeech',
    );
    return transcript?.trim() ?? '';
  }

  Future<bool> hasOfflineArabicTts() async {
    return await _channel.invokeMethod<bool>('hasOfflineArabicTts') ?? false;
  }

  Future<void> speakArabic(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await _channel.invokeMethod<bool>(
      'speakArabic',
      <String, Object>{'text': value},
    );
  }

  Future<void> stopSpeaking() async {
    await _channel.invokeMethod<void>('stopSpeaking');
  }
}
