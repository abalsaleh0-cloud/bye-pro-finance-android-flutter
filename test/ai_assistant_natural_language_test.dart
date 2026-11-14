import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = FakeAssistantEngine();
  const actions = [
    'read_work_remaining',
    'read_month_total',
    'read_work_records',
    'read_home_expenses',
    'read_home_bills',
    'read_debts',
    'read_work_transfers',
    'save_work_entry',
    'save_work_home_transfer',
    'save_home_expense',
    'save_home_bill',
    'save_debt',
    'read_dashboard_summary',
    'navigate_to_section',
  ];

  group('Arabic natural-language work commands', () {
    test('understands formal, colloquial and digit variants as the same salary intent', () async {
      final variants = [
        'أضف راتب 1500 هذا الشهر',
        'سجّل معاش ألف وخمسمية هالشهر',
        'ضيف مرتب ١٥٠٠ في الشهر الحالي',
      ];

      for (final phrase in variants) {
        final result = await engine.interpret(phrase, actions);
        expect(result.kind, AssistantResultKind.command, reason: phrase);
        expect(result.command!.name, 'save_work_entry', reason: phrase);
        expect(result.command!.parameters['kind'], 'salary', reason: phrase);
        expect(result.command!.parameters['amountMinorUnits'], 1500, reason: phrase);
        expect(result.command!.parameters['month'], DateTime.now().month, reason: phrase);
      }
    });

    test('understands a received installment as a salary payment, not a new salary', () async {
      final result = await engine.interpret(
        'قبضت دفعة ١٠٠٠ من راتبي هالشهر',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['kind'], 'payment');
      expect(result.command!.parameters['amountMinorUnits'], 1000);
    });

    test('understands common advance wording', () async {
      final result = await engine.interpret(
        'زيد سلفة 500 للشهر الحالي',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.parameters['kind'], 'advance');
      expect(result.command!.parameters['amountMinorUnits'], 500);
    });

    test('asks for a missing amount rather than assuming one', () async {
      final result = await engine.interpret(
        'سجل راتب لهذا الشهر',
        actions,
      );

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('المبلغ'));
    });

    test('uses the previous request when the user answers a clarification', () async {
      final context = 'المستخدم: أضف راتب لشهر 2026-11\n'
          'المساعد: ما المبلغ المطلوب تسجيله؟';
      final result = await engine.interpret(
        'ألف وخمسمئة',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('does not turn a question about receipt into a write command', () async {
      final result = await engine.interpret(
        'هل استلمت راتبي 1500 هذا الشهر؟',
        actions,
      );

      expect(result.kind, AssistantResultKind.notUnderstood);
    });
  });

  group('Home and transfer wording', () {
    test('understands imperative transfer phrases without an extra add verb', () async {
      final result = await engine.interpret('حوّل ٧٥٠ للبيت', actions);

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_home_transfer');
      expect(result.command!.parameters['amountMinorUnits'], 750);
    });

    test('understands home expense and category synonyms', () async {
      final result = await engine.interpret(
        'سجل مصروف البيت 45 على البقالة هذا الشهر',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_expense');
      expect(result.command!.parameters['categoryId'], 'groceries');
      expect(result.command!.parameters['amountMinorUnits'], 45);
    });

    test('understands rent as a rent bill', () async {
      final result = await engine.interpret('أضف إيجار 500 هذا الشهر', actions);

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_bill');
      expect(result.command!.parameters['kind'], 'rent');
      expect(result.command!.parameters['title'], 'الإيجار');
    });

    test('understands named monthly bills', () async {
      final result = await engine.interpret(
        'سجل فاتورة انترنت 90 للشهر الحالي',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_bill');
      expect(result.command!.parameters['title'], 'انترنت');
      expect(result.command!.parameters['kind'], 'monthly');
      expect(result.command!.parameters['amountMinorUnits'], 90);
    });
  });

  group('Reading and navigation phrases', () {
    test('understands Levantine remaining-balance questions', () async {
      for (final phrase in ['قديش ضل بالعمل؟', 'كم الباقي؟', 'شكد باقي؟']) {
        final result = await engine.interpret(phrase, actions);
        expect(result.kind, AssistantResultKind.command, reason: phrase);
        expect(result.command!.name, 'read_work_remaining', reason: phrase);
      }
    });

    test('understands list requests with different verbs', () async {
      final result = await engine.interpret('وريني مصروفات البيت', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_home_expenses');
    });

    test('understands debt read requests', () async {
      final result = await engine.interpret('هات الديون اللي عندي', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_debts');
    });

    test('understands navigation requests with colloquial verbs', () async {
      final result = await engine.interpret('وديني على قسم المنزل', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'navigate_to_section');
      expect(result.command!.parameters['section'], 'home');
    });

    test('keeps the existing month in historical summary requests', () async {
      final result = await engine.interpret(
        'اعطيني ملخص شهر 10/2026',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_dashboard_summary');
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 10);
    });
  });
}
