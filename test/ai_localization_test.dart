import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant media prompts and labels follow the selected locale', () async {
    final arabic = await AppLocalizations.delegate.load(const Locale('ar'));
    final english = await AppLocalizations.delegate.load(const Locale('en'));

    expect(arabic.aiDefaultImagePrompt, contains('الصورة المرفقة'));
    expect(arabic.aiImageAttachmentLabel, 'صورة');
    expect(arabic.aiAudioAttachmentLabel, 'تسجيل صوتي');
    expect(arabic.assistantClarificationFallback, 'يرجى التوضيح.');
    expect(arabic.aiVoiceInput, 'إملاء صوتي بالعربية');
    expect(arabic.aiVoiceOfflineUnavailable, contains('غير متاح'));
    expect(arabic.aiVoiceRepliesOff, 'تشغيل الرد الصوتي');
    expect(arabic.aiArabicTtsUnavailable, contains('صوت عربي محلي'));

    expect(english.aiDefaultImagePrompt, 'Please analyze the attached image.');
    expect(english.aiImageAttachmentLabel, 'Image');
    expect(english.aiAudioAttachmentLabel, 'Audio recording');
    expect(english.assistantClarificationFallback, 'Please clarify.');
    expect(english.aiVoiceInput, 'Dictate in Arabic');
    expect(english.aiVoiceOfflineUnavailable, contains('not available'));
    expect(english.aiVoiceRepliesOff, 'Turn on spoken replies');
    expect(english.aiArabicTtsUnavailable, contains('offline Arabic voice'));
  });
}
