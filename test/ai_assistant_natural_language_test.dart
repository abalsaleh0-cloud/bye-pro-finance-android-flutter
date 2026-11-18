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
    'read_home_categories',
    'save_home_category',
    'delete_home_category',
    'delete_home_bill',
    'delete_home_expense',
    'delete_work_entry',
    'delete_work_home_transfer',
    'delete_debt',
    'record_home_bill_payment',
    'record_debt_payment',
    'read_home_bill_payments',
    'read_debt_payments',
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

    test('understands English numbers and current-month wording', () async {
      final result = await engine.interpret(
        'Add salary one thousand five hundred this month',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['month'], DateTime.now().month);
    });

    test('understands a named month with a year without treating the year as an amount', () async {
      final result = await engine.interpret(
        'سجل معاش ألف وخمسمية تشرين الثاني 2026',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('does not save a question that contains a write verb', () async {
      final result = await engine.interpret(
        'هل أسجل راتب 1500 هذا الشهر؟',
        actions,
      );

      expect(result.kind, AssistantResultKind.notUnderstood);
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

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_work_records');
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
    test('creates and deletes a custom expense category by its live label', () async {
      final added = await engine.interpret(
        'أضف تصنيف لوازم المكتب',
        actions,
      );
      expect(added.kind, AssistantResultKind.command);
      expect(added.command!.name, 'save_home_category');
      expect(added.command!.parameters['name'], 'لوازم المكتب');

      final removed = await engine.interpret(
        'احذف تصنيف لوازم المكتب',
        actions,
        expenseCategories: const {'custom_1': 'لوازم المكتب'},
      );
      expect(removed.kind, AssistantResultKind.command);
      expect(removed.command!.name, 'delete_home_category');
      expect(removed.command!.parameters['name'], 'لوازم المكتب');
    });

    test('renames a custom category while preserving its stable ID', () async {
      final result = await engine.interpret(
        'عدل تصنيف لوازم المكتب إلى تجهيزات مكتبية',
        actions,
        expenseCategories: const {'custom_office': 'لوازم المكتب'},
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_category');
      expect(result.command!.parameters['id'], 'custom_office');
      expect(result.command!.parameters['name'], 'تجهيزات مكتبية');
    });

    test('does not rename a built-in localized category', () async {
      final result = await engine.interpret(
        'عدل تصنيف البقالة إلى الطعام',
        actions,
        expenseCategories: const {'groceries': 'البقالة'},
      );

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('التصنيفات الأساسية'));
    });

    test('accepts a custom category as a clarification answer', () async {
      const context = 'المستخدم: سجل مصروف البيت 45 هذا الشهر\n'
          'المساعد: ما تصنيف المصروف؟ مثل الطعام أو الكهرباء أو المواصلات.';
      final result = await engine.interpret(
        'مستلزمات المكتب',
        actions,
        conversationContext: context,
        expenseCategories: const {'custom_office': 'مستلزمات المكتب'},
      );
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_expense');
      expect(result.command!.parameters['categoryId'], 'custom_office');
      expect(result.command!.parameters['amountMinorUnits'], 45);
    });

    test('records a bill payment against an exact bill title', () async {
      final result = await engine.interpret(
        'دفعت 75 فاتورة الكهرباء اليوم',
        actions,
      );
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'record_home_bill_payment');
      expect(result.command!.parameters['billTitle'], 'الكهرباء');
      expect(result.command!.parameters['amountMinorUnits'], 75);
      expect(result.command!.parameters['date'], isA<String>());
    });

    test('records a debt payment with the named counterparty', () async {
      final result = await engine.interpret(
        'سددت 100 من دين سامر',
        actions,
      );
      expect(
        result.kind,
        AssistantResultKind.command,
        reason: result.message ?? 'The local parser returned no command or clarification message.',
      );
      expect(result.command!.name, 'record_debt_payment');
      expect(result.command!.parameters['counterparty'], 'سامر');
      expect(result.command!.parameters['amountMinorUnits'], 100);
    });

    test('reads all matching section records when asked for all', () async {
      final result = await engine.interpret(
        'اعرض كل مصروفات المنزل',
        actions,
      );
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_home_expenses');
      expect(result.command!.parameters['allRecords'], isTrue);
    });

    test('reads payment history by the actual bill title', () async {
      final result = await engine.interpret(
        'اعرض دفعات فاتورة الكهرباء',
        actions,
      );
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_home_bill_payments');
      expect(result.command!.parameters['billTitle'], 'الكهرباء');
    });

    test('deletes an expense only when category, amount and month identify a target', () async {
      final result = await engine.interpret(
        'احذف مصروف البقالة 50 لشهر 2026-11',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'delete_home_expense');
      expect(result.command!.parameters['categoryId'], 'groceries');
      expect(result.command!.parameters['amountMinorUnits'], 50);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('deletes a work entry using its kind, amount and requested month', () async {
      final result = await engine.interpret(
        'احذف راتب 1500 لشهر 2026-11',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'delete_work_entry');
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('deletes a transfer only when its amount and explicit date are supplied', () async {
      final result = await engine.interpret(
        'احذف تحويل 250 للمنزل بتاريخ 2026-11-15',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'delete_work_home_transfer');
      expect(result.command!.parameters['amountMinorUnits'], 250);
      expect(result.command!.parameters['date'], '2026-11-15');
    });

    test('does not guess the month when deleting an expense by category and amount', () async {
      final result = await engine.interpret(
        'احذف مصروف البقالة 50',
        actions,
      );

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('الشهر أو التاريخ'));
    });

    test('deletes records only when an explicit stable identifier is given', () async {
      final missingId = await engine.interpret(
        'احذف مصروف البقالة',
        actions,
      );
      expect(missingId.kind, AssistantResultKind.clarification);
      expect(missingId.message, contains('معرّفه'));

      final withId = await engine.interpret(
        'احذف مصروف رقم السجل exp_123',
        actions,
      );
      expect(withId.kind, AssistantResultKind.command);
      expect(withId.command!.name, 'delete_home_expense');
      expect(withId.command!.parameters['id'], 'exp_123');
    });

  group('Local clarification continuation and date parsing', () {
    test('continues a debt-payment request when the amount is supplied later', () async {
      const context = 'المستخدم: سددت دفعة من دين سامر\n'
          'المساعد: كم مبلغ الدفعة التي سددتها؟';
      final result = await engine.interpret(
        '100',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'record_debt_payment');
      expect(result.command!.parameters['counterparty'], 'سامر');
      expect(result.command!.parameters['amountMinorUnits'], 100);
    });

    test('continues custom-category creation when its name is supplied later', () async {
      const context = 'المستخدم: أضف تصنيف\n'
          'المساعد: ما اسم التصنيف الجديد؟';
      final result = await engine.interpret(
        'لوازم المكتب',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_category');
      expect(result.command!.parameters['name'], 'لوازم المكتب');
    });

    test('continues a bill-payment request when the amount is supplied later', () async {
      const context = 'المستخدم: دفعت من فاتورة الكهرباء\n'
          'المساعد: كم مبلغ الدفعة؟';
      final result = await engine.interpret(
        '75',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'record_home_bill_payment');
      expect(result.command!.parameters['billTitle'], 'الكهرباء');
      expect(result.command!.parameters['amountMinorUnits'], 75);
    });

    test('continues a work deletion request after the user selects its record kind', () async {
      const context = 'المستخدم: احذف سجل 1500 لشهر 2026-11\n'
          'المساعد: هل تريد حذف راتب أم سلفة أم دفعة؟';
      final result = await engine.interpret(
        'راتب',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'delete_work_entry');
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('continues a transfer deletion request after the user supplies its date', () async {
      const context = 'المستخدم: احذف تحويل 250 للمنزل\n'
          'المساعد: ما تاريخ أو شهر التحويل حتى أحدده بدقة؟';
      final result = await engine.interpret(
        '2026-11-15',
        actions,
        conversationContext: context,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'delete_work_home_transfer');
      expect(result.command!.parameters['amountMinorUnits'], 250);
      expect(result.command!.parameters['date'], '2026-11-15');
    });

    test('continues a custom category rename after the new name is supplied', () async {
      const context = 'المستخدم: عدل تصنيف لوازم المكتب\n'
          'المساعد: ما الاسم الجديد للتصنيف؟';
      final result = await engine.interpret(
        'تجهيزات مكتبية',
        actions,
        conversationContext: context,
        expenseCategories: const {'custom_office': 'لوازم المكتب'},
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_category');
      expect(result.command!.parameters['id'], 'custom_office');
      expect(result.command!.parameters['name'], 'تجهيزات مكتبية');
    });

    test('uses yesterday and preserves the operation note without a model', () async {
      final result = await engine.interpret(
        'سجل مصروف 30 على البقالة أمس ملاحظة مشتريات البيت',
        actions,
      );

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_expense');
      expect(result.command!.parameters['date'],
          DateTime(yesterday.year, yesterday.month, yesterday.day)
              .toIso8601String().split('T').first);
      expect(result.command!.parameters['note'], 'مشتريات البيت');
    });
  });

  group('Local record editing intents', () {
    test('edits a named bill using its exact identifier', () async {
      final result = await engine.interpret(
        'عدل فاتورة الكهرباء رقم الفاتورة bill_1 بمبلغ 175 لشهر 2026-11',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_bill');
      expect(result.command!.parameters['id'], 'bill_1');
      expect(result.command!.parameters['title'], 'الكهرباء');
      expect(result.command!.parameters['amountMinorUnits'], 175);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('edits a debt while preserving the selected creditor/debtor direction', () async {
      final result = await engine.interpret(
        'عدل الدين عند سامر رقم الدين debt_1 بمبلغ 225 دائن لشهر 2026-11',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_debt');
      expect(result.command!.parameters['id'], 'debt_1');
      expect(result.command!.parameters['counterparty'], 'سامر');
      expect(result.command!.parameters['direction'], 'creditor');
      expect(result.command!.parameters['amountMinorUnits'], 225);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('edits a work record using its stable identifier', () async {
      final result = await engine.interpret(
        'عدل راتب رقم السجل work_1 بمبلغ 1750 لشهر 2026-11',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['id'], 'work_1');
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1750);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('edits a household expense by identifier and its selected category', () async {
      final result = await engine.interpret(
        'عدل مصروف البقالة رقم السجل expense_1 بمبلغ 175 بتاريخ 2026-11-18',
        actions,
        expenseCategories: const {'groceries': 'البقالة'},
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_home_expense');
      expect(result.command!.parameters['id'], 'expense_1');
      expect(result.command!.parameters['categoryId'], 'groceries');
      expect(result.command!.parameters['amountMinorUnits'], 175);
      expect(result.command!.parameters['date'], '2026-11-18');
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
    });

    test('edits a work-to-home transfer using its stable identifier', () async {
      final result = await engine.interpret(
        'عدل تحويل للبيت رقم التحويل transfer_1 بمبلغ 225',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_home_transfer');
      expect(result.command!.parameters['id'], 'transfer_1');
      expect(result.command!.parameters['amountMinorUnits'], 225);
      expect(result.command!.parameters['date'], isA<String>());
    });

  });

  });
}
