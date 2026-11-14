import 'package:expense_app/features/ai/data/android_assistant_voice_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.byepro.finance/assistant_voice');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = AndroidAssistantVoiceService();

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('returns recognized Arabic text from the Android voice bridge', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognizeArabicSpeech');
      return 'أضف راتب 1500';
    });

    expect(await service.recognizeArabicSpeech(), 'أضف راتب 1500');
  });

  test('reports whether an offline Arabic TTS voice is installed', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hasOfflineArabicTts');
      return true;
    });

    expect(await service.hasOfflineArabicTts(), isTrue);
  });

  test('sends spoken replies only through the native local voice bridge', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    await service.speakArabic('تم حفظ السجل بعد موافقتك');
    await service.stopSpeaking();

    expect(calls.map((call) => call.method), [
      'speakArabic',
      'stopSpeaking',
    ]);
    expect(calls.first.arguments, {'text': 'تم حفظ السجل بعد موافقتك'});
  });

  test('ignores empty spoken replies', () async {
    var callCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      callCount++;
      return true;
    });

    await service.speakArabic('   ');

    expect(callCount, 0);
  });
}
