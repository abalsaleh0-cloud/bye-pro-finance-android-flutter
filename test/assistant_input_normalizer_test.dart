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

  group('Explicit calendar date parsing', () {
    test('parses ISO and day-first dates using Arabic digits too', () {
      expect(input.extractDate('2026-11-18'), DateTime(2026, 11, 18));
      expect(input.extractDate('18/11/2026'), DateTime(2026, 11, 18));
      expect(input.extractDate('١٨-١١-٢٠٢٦'), DateTime(2026, 11, 18));
    });

    test('rejects impossible calendar dates instead of normalizing them', () {
      expect(input.extractDate('31/11/2026'), isNull);
      expect(input.extractDate('2026-02-30'), isNull);
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
      expect(input.extractAmount('سجل مبلغ خمس مئة دينار'), 500);
      expect(input.extractAmount('أضف راتب one thousand five hundred'), 1500);
      expect(input.extractAmount('أضف راتب fifteen hundred'), 1500);
    });

    test('parses grouped digits and does not mistake a month for an amount', () {
      expect(input.extractAmount('سجل راتب 1,500 لشهر 2026-11'), 1500);
      expect(input.extractAmount('سجل راتب ١٬٥٠٠ لشهر ١١/٢٠٢٦'), 1500);
      expect(input.extractAmount('سجل راتب لشهر 2026-11'), isNull);
      expect(input.extractAmount('سجل راتب لسنة 2026'), isNull);
      expect(input.extractAmount('سجل راتب تشرين الثاني 2026'), isNull);
      expect(input.extractAmount('سجل راتب 14 تشرين الثاني 2026'), isNull);
      expect(input.extractAmount('سجل راتب November 2026'), isNull);
      expect(input.extractAmount('سجل راتب لسنة 2026'), isNull);
      expect(input.extractAmount('سجل راتب 1.500'), 1500);
      expect(input.extractAmount('سجل راتب 1.50'), isNull);
      expect(input.extractAmount('سجل راتب 1500 لشهر نوفمبر 2026'), 1500);
    });

    test('does not guess an unknown amount phrase', () {
      expect(input.extractAmount('أضف راتب مبلغ كبير'), isNull);
    });
  });

  group('Arabic month formats', () {
    final referenceDate = DateTime(2026, 11, 14);

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
      expect(
        input.extractMonth('راتب 14 تشرين الثاني 2026', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب November 2026', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('راتب لهذا الشهر', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('salary for this month', referenceDate: referenceDate),
        (2026, 11),
      );
      expect(
        input.extractMonth('salary last month', referenceDate: referenceDate),
        (2026, 10),
      );
      expect(
        input.extractMonth('salary next month', referenceDate: referenceDate),
        (2026, 12),
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
