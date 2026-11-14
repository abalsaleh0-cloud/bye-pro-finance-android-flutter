import 'package:expense_app/features/ai/domain/assistant_input_normalizer.dart';
import 'package:expense_app/features/ai/domain/number_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const input = AssistantInputNormalizer();
  const numbers = NumberNormalizer();

  group('Arabic input normalization', () {
    test('normalizes hamza, diacritics, Arabic digits and punctuation', () {
      expect(input.normalize('أُضِفْ راتب ١٥٠٠!'), 'اضف راتب 1500');
      expect(input.normalize('إجماليّ المصروفات؟'), 'اجمالي المصروفات');
    });

    test('matches definite articles and attached Arabic prefixes', () {
      final text = input.normalize('كم قيمة الراتب في البيت؟');
      expect(input.containsAny(text, ['راتب']), isTrue);
      expect(input.containsAny(text, ['البيت']), isTrue);
      expect(input.containsAny(text, ['بيت']), isTrue);
    });
  });

  group('Arabic and colloquial amount formats', () {
    test('parses Eastern Arabic and Persian digits', () {
      expect(numbers.parseInteger('١٥٠٠'), 1500);
      expect(numbers.parseInteger('۱۵۰۰'), 1500);
    });

    test('parses Arabic words and common dialect spellings', () {
      expect(input.extractAmount('أضف راتب ألف وخمسمئة'), 1500);
      expect(input.extractAmount('سجل معاش الف وخمسمية'), 1500);
      expect(input.extractAmount('سجل مرتب ألف وخمسمائة'), 1500);
      expect(input.extractAmount('سجل مبلغ خمسمية دينار'), 500);
      expect(input.extractAmount('سجل مبلغ مائة دينار'), 100);
      expect(input.extractAmount('سجل مبلغ ميتين دينار'), 200);
    });

    test('parses grouped digits and does not mistake a month for an amount', () {
      expect(input.extractAmount('سجل راتب 1,500 لشهر 2026-11'), 1500);
      expect(input.extractAmount('سجل راتب ١٬٥٠٠ لشهر ١١/٢٠٢٦'), 1500);
      expect(input.extractAmount('سجل راتب لشهر 2026-11'), isNull);
    });

    test('does not guess an unknown amount phrase', () {
      expect(input.extractAmount('أضف راتب مبلغ كبير'), isNull);
    });
  });

  group('Arabic month formats', () {
    const referenceDate = DateTime(2026, 11, 14);

    test('parses year-month and month-year number forms', () {
      expect(
        input.extractMonth('راتب لشهر 2026-11', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب لشهر ١١/٢٠٢٦', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب شهر 10 لسنة 2026', referenceDate: referenceDate),
        (2026, 10),
      );
    });

    test('parses Arabic and Levantine month names', () {
      expect(
        input.extractMonth('راتب تشرين الثاني 2026', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب نوفمبر 2026', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب شباط', referenceDate: referenceDate),
        (2026, 2),
      );
      expect(
        input.extractMonth('راتب كانون التاني', referenceDate: referenceDate),
        (2026, 1),
      );
    });

    test('parses current, previous and next month expressions', () {
      expect(
        input.extractMonth('هذا الشهر', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('هالشهر', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('الشهر الماضي', referenceDate: referenceDate),
        (2026, 10),
      );
      expect(
        input.extractMonth('الشهر الجاي', referenceDate: referenceDate),
        (2026, 12),
      );
    });

    test('does not infer a month when no date phrase exists', () {
      expect(input.extractMonth('سجل راتب 1500', referenceDate: referenceDate), isNull);
    });
  });
}
