import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/data/home_expense_category_repository.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingGemmaGenerator implements GemmaTurnGenerator {
  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions, {
    AssistantMedia? media,
  }) async {
    throw StateError('model failed');
  }
}

class _FakeGemmaGenerator implements GemmaTurnGenerator {
  _FakeGemmaGenerator(this.output);
  final GemmaModelOutput output;
  List<GemmaFunctionSpec>? receivedFunctions;
  String? receivedInput;
  AssistantMedia? receivedMedia;

  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions, {
    AssistantMedia? media,
  }) async {
    receivedInput = userText;
    receivedFunctions = functions;
    receivedMedia = media;
    return output;
  }
}

void main() {
  const actions = [
    'save_work_entry',
    'read_work_remaining',
    'read_month_total',
  ];

  group('Gemma action coverage and partial updates', () {
    test('routes a finance request with only its relevant tool schema', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(''),
      );
      final actionNames = ActionRegistry.descriptors
          .map((descriptor) => descriptor.name)
          .toList(growable: false);

      await GemmaAssistantEngine(generator).interpret(
        'اعرض ملخص الشهر',
        actionNames,
      );

      final functions = generator.receivedFunctions!;
      expect(
        functions.map((function) => function.name),
        unorderedEquals(['read_dashboard_summary', 'ask_clarification']),
      );
      final summary = functions.singleWhere(
        (function) => function.name == 'read_dashboard_summary',
      );
      expect(summary.properties.keys, containsAll(['year', 'month']));
      expect(summary.required, isEmpty);
      expect(
        summary.required.every(summary.properties.containsKey),
        isTrue,
      );
    });

    test('falls back to a real salary command when Gemma only claims it saved', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('تمام، أضفت راتب 1500 لشهر أكتوبر.'),
      );
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1);
      final result = await FallbackAssistantEngine(
        primary: GemmaAssistantEngine(generator),
        fallback: const LocalRuleAssistantEngine(),
      ).interpret(
        'أضف راتب 1500 لشهر الماضي ملاحظة راتب شهري',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], previousMonth.year);
      expect(result.command!.parameters['month'], previousMonth.month);
      expect(result.command!.parameters['note'], 'راتب شهري');
      expect(result.usedGemmaFallback, isTrue);
    });

    test('falls back when Gemma asks for a month already specified as last month', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('ask_clarification', {
          'question': 'أي شهر تقصد؟',
        }),
      );
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1);
      final result = await FallbackAssistantEngine(
        primary: GemmaAssistantEngine(generator),
        fallback: const LocalRuleAssistantEngine(),
      ).interpret(
        'أضف راتب 1500 لشهر الماضي',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], previousMonth.year);
      expect(result.command!.parameters['month'], previousMonth.month);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.usedGemmaFallback, isTrue);
    });

    test('does not send any finance tools for ordinary general conversation', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('إليك فقرة قصيرة عن تنظيم الوقت.'),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'اكتب لي فقرة قصيرة عن أهمية تنظيم الوقت، ثم أعطني ثلاثة أمثلة عملية.',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.answer);
      expect(generator.receivedFunctions, isEmpty);
    });

    test('rejects a tool call that was not exposed for this general turn', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_debt', {
          'amountMinorUnits': 500,
          'direction': 'debtor',
          'counterparty': 'سامر',
          'year': 2026,
          'month': 11,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'اكتب فقرة عن تنظيم الوقت',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(generator.receivedFunctions, isEmpty);
      expect(result.kind, AssistantResultKind.notUnderstood);
      expect(result.command, isNull);
    });

    test('routes a personal home-spending question to read-only tools', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(''),
      );
      await GemmaAssistantEngine(generator).interpret(
        'كم صرفت على المنزل؟',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      final names = generator.receivedFunctions!.map((item) => item.name);
      expect(names, contains('read_home_expenses'));
      expect(names, contains('ask_clarification'));
      expect(names, isNot(contains('save_home_expense')));
    });

    test('passes the requested year and month for a new household transfer', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_home_transfer', {
          'amountMinorUnits': 350,
          'year': 2026,
          'month': 10,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'حوّل 350 إلى المنزل في أكتوبر 2026',
        ActionRegistry.descriptors.map((descriptor) => descriptor.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_home_transfer');
      expect(result.command!.parameters, {
        'amountMinorUnits': 350,
        'year': 2026,
        'month': 10,
      });
    });

    test('allows an edit by ID to provide only the changed field', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'id': 'salary-nov',
          'amountMinorUnits': 1800,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'عدّل الراتب المحدد واجعله 1800',
        ActionRegistry.descriptors.map((descriptor) => descriptor.name).toList(),
        conversationContext:
            'المستخدم: عدّل سجل العمل بمعرّف salary-nov\nالمساعد: ما التغيير المطلوب؟',
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters, {
        'id': 'salary-nov',
        'amountMinorUnits': 1800,
      });
      final saveWork = generator.receivedFunctions!
          .singleWhere((function) => function.name == 'save_work_entry');
      expect(saveWork.required, isEmpty);
    });

    test('still asks for missing fields when creating a new record', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'kind': 'salary',
          'amountMinorUnits': 1200,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'أضف راتباً بقيمة 1200',
        ActionRegistry.descriptors.map((descriptor) => descriptor.name).toList(),
      );

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('الشهر'));
    });

    test('resolves payment history by unique bill title or debt party', () async {
      final debtGenerator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('read_debt_payments', {
          'counterparty': 'سامر',
          'direction': 'creditor',
        }),
      );
      final debtResult = await GemmaAssistantEngine(debtGenerator).interpret(
        'اعرض دفعات الدين عند سامر',
        ActionRegistry.descriptors.map((descriptor) => descriptor.name).toList(),
      );
      expect(debtResult.kind, AssistantResultKind.command);
      expect(debtResult.command!.parameters['counterparty'], 'سامر');

      final billGenerator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('read_home_bill_payments', {
          'billTitle': 'Electricity',
        }),
      );
      final billResult = await GemmaAssistantEngine(billGenerator).interpret(
        'اعرض دفعات فاتورة الكهرباء',
        ActionRegistry.descriptors.map((descriptor) => descriptor.name).toList(),
      );
      expect(billResult.kind, AssistantResultKind.command);
      expect(billResult.command!.parameters['billTitle'], 'Electricity');
    });
  });

  group('GemmaAssistantEngine output validation', () {
    test('forwards image and audio bytes to the turn generator', () async {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('ما في الصورة؟'),
      );
      await GemmaAssistantEngine(generator).interpret(
        'صف الصورة',
        actions,
        media: AssistantMedia(imageBytes: imageBytes),
      );

      expect(generator.receivedMedia?.imageBytes, same(imageBytes));
      expect(generator.receivedMedia?.audioBytes, isNull);
    });

    test('forwards audio bytes to the turn generator', () async {
      final audioBytes = Uint8List.fromList([4, 5, 6]);
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('تم استلام التسجيل'),
      );
      await GemmaAssistantEngine(generator).interpret(
        'استمع إلى التسجيل',
        actions,
        media: AssistantMedia(audioBytes: audioBytes),
      );

      expect(generator.receivedMedia?.audioBytes, same(audioBytes));
      expect(generator.receivedMedia?.imageBytes, isNull);
    });

    test('forwards prior dialogue and keeps the current turn explicit', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('ما الشهر المطلوب؟'),
      );
      await GemmaAssistantEngine(generator).interpret(
        'لهذا الشهر',
        actions,
        conversationContext: 'المستخدم: أضف راتب 1500\nالمساعد: أي شهر تقصد؟',
      );

      expect(generator.receivedInput, contains('أضف راتب 1500'));
      expect(generator.receivedInput, contains('أي شهر تقصد؟'));
      expect(generator.receivedInput, endsWith('رسالة المستخدم الحالية:\nلهذا الشهر'));
    });

    test('trims old transcript text while preserving the current user message', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('تابع.'),
      );
      final oldContext = List.filled(200, 'نص قديم لم يعد مهماً').join('؛ ');
      await GemmaAssistantEngine(generator).interpret(
        'تابع',
        const [],
        conversationContext: '$oldContext\nنهاية السياق السابق',
      );

      expect(generator.receivedInput, contains('نهاية السياق السابق'));
      expect(generator.receivedInput, endsWith('رسالة المستخدم الحالية:\nتابع'));
      expect(generator.receivedInput!.length, lessThan(1300));
      expect(generator.receivedFunctions, isEmpty);
    });

    test('returns a natural-language answer for multimodal input', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('تظهر في الصورة فاتورة بقيمة 250 ديناراً.'),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'حلّل الصورة',
        actions,
        media: AssistantMedia(imageBytes: Uint8List.fromList([1, 2, 3])),
      );

      expect(result.kind, AssistantResultKind.answer);
      expect(result.message, 'تظهر في الصورة فاتورة بقيمة 250 ديناراً.');
    });

    test('routes an imperative bill-payment request to the payment tool', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('record_home_bill_payment', {
          'billTitle': 'الكهرباء',
          'amountMinorUnits': 100,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'ادفع فاتورة الكهرباء بقيمة 100',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'record_home_bill_payment');
      final names = generator.receivedFunctions!.map((item) => item.name);
      expect(names, contains('record_home_bill_payment'));
      expect(names, isNot(contains('save_home_bill')));
    });

    test('searches all work months when asked where a salary amount was added', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('read_work_records', {}),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'أين أضفت 1500؟',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
        conversationContext:
            'المستخدم: أضف راتب 1500 لشهر الماضي\nالمساعد: تمت إضافة الراتب.',
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_work_records');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['allRecords'], isTrue);
      expect(
        generator.receivedFunctions!.map((item) => item.name),
        contains('read_work_records'),
      );
    });

    test('removes Gemma-inferred month filters from a historical salary lookup', () async {
      final now = DateTime.now();
      final generator = _FakeGemmaGenerator(
        GemmaModelOutput.call('read_work_records', {
          'year': now.year,
          'month': now.month,
          'amountMinorUnits': 1500,
          'kind': 'salary',
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'أين أضفت 1500؟',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
        conversationContext:
            'المستخدم: أضف راتب 1500 لشهر الماضي\nالمساعد: تمت إضافة الراتب.',
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_work_records');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['allRecords'], isTrue);
      expect(result.command!.parameters.containsKey('year'), isFalse);
      expect(result.command!.parameters.containsKey('month'), isFalse);
    });

    test('local rules resolve a salary lookup from the preceding conversation', () async {
      final result = await const LocalRuleAssistantEngine().interpret(
        'وين أضفت 1500؟',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
        conversationContext:
            'المستخدم: أضف راتب 1500 لشهر الماضي\nالمساعد: تمت إضافة الراتب.',
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_work_records');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['allRecords'], isTrue);
    });

    test('treats a question about paid bills as a read-only history lookup', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('read_home_bill_payments', {
          'billTitle': 'الكهرباء',
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'كم دفعت فاتورة الكهرباء؟',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_home_bill_payments');
      final names = generator.receivedFunctions!.map((item) => item.name);
      expect(names, contains('read_home_bill_payments'));
      expect(names, isNot(contains('record_home_bill_payment')));
    });

    test('exposes required identifiers in payment-history tool schemas', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(''),
      );
      await GemmaAssistantEngine(generator).interpret(
        'اعرض سجل الدفعات',
        const ['read_debt_payments', 'read_home_bill_payments'],
      );

      final functions = generator.receivedFunctions!;
      final debt = functions.singleWhere((item) => item.name == 'read_debt_payments');
      final bill = functions.singleWhere((item) => item.name == 'read_home_bill_payments');
      expect(
        debt.properties.keys,
        containsAll(['debtId', 'id', 'counterparty', 'direction']),
      );
      expect(debt.required, isEmpty);
      expect(
        bill.properties.keys,
        containsAll(['billId', 'id', 'billTitle']),
      );
      expect(bill.required, isEmpty);
    });

    test('keeps Gemma deletion tool schemas aligned with local safe match fields', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(''),
      );
      const names = [
        'delete_work_entry',
        'delete_home_expense',
        'delete_work_home_transfer',
        'delete_home_bill',
        'delete_debt',
        'delete_home_category',
      ];
      await GemmaAssistantEngine(generator).interpret(
        'احذف السجل المحدد',
        names,
      );

      final functions = generator.receivedFunctions!;
      final work = functions.singleWhere((item) => item.name == 'delete_work_entry');
      final expense = functions.singleWhere((item) => item.name == 'delete_home_expense');
      final transfer = functions.singleWhere((item) => item.name == 'delete_work_home_transfer');
      final bill = functions.singleWhere((item) => item.name == 'delete_home_bill');
      final debt = functions.singleWhere((item) => item.name == 'delete_debt');
      final category = functions.singleWhere((item) => item.name == 'delete_home_category');

      expect(work.properties.keys, containsAll(['id', 'kind', 'amountMinorUnits', 'year', 'month', 'date']));
      expect(expense.properties.keys, containsAll(['id', 'categoryId', 'categoryName', 'amountMinorUnits', 'year', 'month', 'date']));
      expect(transfer.properties.keys, containsAll(['id', 'amountMinorUnits', 'year', 'month', 'date']));
      expect(bill.properties.keys, containsAll(['id', 'billId', 'billTitle']));
      expect(debt.properties.keys, containsAll(['id', 'debtId', 'counterparty', 'direction']));
      expect(category.properties.keys, containsAll(['id', 'name']));
    });

    test('exposes dashboard summary and safe navigation tool schemas', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(''),
      );
      await GemmaAssistantEngine(generator).interpret(
        'اعطني ملخصاً وافتح قسم العمل عند الحاجة',
        const ['read_dashboard_summary', 'navigate_to_section'],
      );

      final functions = generator.receivedFunctions!;
      final summary = functions.singleWhere(
        (item) => item.name == 'read_dashboard_summary',
      );
      final navigation = functions.singleWhere(
        (item) => item.name == 'navigate_to_section',
      );
      expect(summary.required, isEmpty);
      expect(summary.properties.keys, containsAll(['year', 'month']));
      expect(navigation.required, ['section']);
      expect(navigation.properties['section']!['enum'], [
        'dashboard',
        'work',
        'home',
        'debts',
        'ai',
        'settings',
      ]);
    });

    test('forwards an explicit month to the dashboard summary action', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('read_dashboard_summary', {
          'year': 2026,
          'month': 10,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'اعطني ملخص شهر 2026-10',
        const ['read_dashboard_summary'],
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_dashboard_summary');
      expect(result.command!.parameters, {'year': 2026, 'month': 10});
    });

    test('converts a valid navigation function call into a read-only command', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('navigate_to_section', {
          'section': 'settings',
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'افتح الإعدادات',
        const ['navigate_to_section'],
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'navigate_to_section');
      expect(result.command!.parameters['section'], 'settings');
    });

    test('does not accept plain text as proof that a work record was deleted', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('تم حذف الراتب بنجاح.'),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'احذف راتب 1500 لشهر 11',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.notUnderstood);
      expect(result.command, isNull);
    });

    test('rejects a fabricated record ID for an edit without an explicit user ID', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'id': 'model-invented-record-id',
          'amountMinorUnits': 1500,
          'kind': 'salary',
          'year': 2026,
          'month': 11,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'عدّل الراتب إلى 1500 لشهر 11',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.notUnderstood);
      expect(result.command, isNull);
    });

    test('converts a valid function call into a command', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'kind': 'salary',
          'amountMinorUnits': 250,
          'year': 2026,
          'month': 11,
        }),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب 250 لشهر 2026-11', actions);

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters['amountMinorUnits'], 250);
      expect(generator.receivedInput, 'سجل راتب 250 لشهر 2026-11');
      expect(generator.receivedFunctions!.map((e) => e.name),
          contains('ask_clarification'));
    });

    test('removes a fabricated ID from a new salary record', () async {
      final now = DateTime.now();
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'id': 'model-invented-record-id',
          'kind': 'advance',
          'amountMinorUnits': 1,
          'year': 2020,
          'month': 1,
          'date': '2020-01-01',
          'note': 'wrong note',
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'أضف راتب 1500 لشهر ${now.month} ملاحظة راتب شهري',
        ActionRegistry.descriptors.map((item) => item.name).toList(),
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_entry');
      expect(result.command!.parameters.containsKey('id'), isFalse);
      expect(result.command!.parameters['kind'], 'salary');
      expect(result.command!.parameters['amountMinorUnits'], 1500);
      expect(result.command!.parameters['year'], now.year);
      expect(result.command!.parameters['month'], now.month);
      expect(result.command!.parameters.containsKey('date'), isFalse);
      expect(result.command!.parameters['note'], 'راتب شهري');
    });

    test('normalizes Arabic-Indic digits while preserving the explicit salary month', () async {
      final now = DateTime.now();
      final generator = _FakeGemmaGenerator(
        GemmaModelOutput.call('save_work_entry', {
          'kind': 'salary',
          'amountMinorUnits': '٢٥٠',
          'year': 2020,
          'month': 1,
        }),
      );
      final result = await GemmaAssistantEngine(generator).interpret(
        'سجل راتب ٢٥٠ لشهر ${now.month}',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.parameters['amountMinorUnits'], 250);
      expect(result.command!.parameters['year'], now.year);
      expect(result.command!.parameters['month'], now.month);
    });

    test('asks for missing required parameters and never guesses', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'kind': 'salary',
          'year': 2026,
          'month': 11,
        }),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('المبلغ'));
    });

    test('rejects malformed JSON returned as plain text', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('{"tool_calls":['),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.notUnderstood);
    });

    test('rejects an unknown function', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('write_directly_to_database', {}),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.notUnderstood);
    });

    test('rejects parallel calls rather than executing more than one', () async {
      final generator = _FakeGemmaGenerator(const GemmaModelOutput.multiple());
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.notUnderstood);
    });

    test('converts model failures to not-understood without a command', () async {
      final result = await GemmaAssistantEngine(_ThrowingGemmaGenerator())
          .interpret('كم الباقي؟', actions);

      expect(result.kind, AssistantResultKind.notUnderstood);
      expect(result.command, isNull);
    });

    test('uses the local parser for a missing salary amount clarification', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('ما الشهر المستحق؟'),
      );
      final result = await FallbackAssistantEngine(
        primary: GemmaAssistantEngine(generator),
        fallback: const LocalRuleAssistantEngine(),
      ).interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.clarification);
      expect(result.message, contains('المبلغ'));
      expect(result.usedGemmaFallback, isTrue);
    });

    test('allows natural general conversation replies containing numbers', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text(
          'إليك 3 خطوات بسيطة لتنظيم محادثاتك: ابدأ بعنوان واضح، '
          'اجمع كل موضوع في محادثة مستقلة، وراجع السجل عند الحاجة.',
        ),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('كيف أنظم محادثاتي؟', actions);

      expect(result.kind, AssistantResultKind.answer);
      expect(result.message, contains('3 خطوات'));
      expect(generator.receivedFunctions, isEmpty);
    });

    test('does not allow a free-form answer to invent personal financial figures', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('رصيدك الحالي 1500 دينار.'),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('كم رصيدي؟', actions);

      expect(result.kind, AssistantResultKind.notUnderstood);
      expect(result.command, isNull);
    });
  });

  test('interpreting a valid write command does not write to the database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final registry = ActionRegistry(
      work: WorkRepository(database),
      home: HomeExpenseRepository(database),
      bills: HomeBillRepository(database),
      debts: DebtRepository(database),
      categories: HomeExpenseCategoryRepository(database),
    );
    final generator = _FakeGemmaGenerator(
      const GemmaModelOutput.call('save_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 250,
        'year': 2026,
        'month': 11,
      }),
    );

    final result = await GemmaAssistantEngine(generator)
        .interpret('سجل راتب 250 لشهر 2026-11', registry.actionNames);

    expect(result.kind, AssistantResultKind.command);
    expect(await database.select(database.workEntries).get(), isEmpty);
    expect(await database.select(database.homeExpenses).get(), isEmpty);
    expect(await database.select(database.debts).get(), isEmpty);
  });

  test('saves and finds a salary record by exact amount across months', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final registry = ActionRegistry(
      work: WorkRepository(database),
      home: HomeExpenseRepository(database),
      bills: HomeBillRepository(database),
      debts: DebtRepository(database),
      categories: HomeExpenseCategoryRepository(database),
    );
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final previousMonthKey = MonthKey(
      year: previousMonth.year,
      month: previousMonth.month,
    );
    final date = DateTime(previousMonth.year, previousMonth.month, 15);

    await registry.execute('save_work_entry', {
      'kind': 'salary',
      'amountMinorUnits': 1500,
      'year': previousMonth.year,
      'month': previousMonth.month,
      'date': date.toIso8601String().split('T').first,
      'note': 'راتب شهري',
    });
    await registry.execute('save_work_entry', {
      'kind': 'salary',
      'amountMinorUnits': 2200,
      'year': now.year,
      'month': now.month,
      'date': DateTime(now.year, now.month, 15).toIso8601String().split('T').first,
    });

    final result = await registry.execute('read_work_records', {
      'amountMinorUnits': 1500,
      'kind': 'salary',
      'allRecords': true,
    });

    expect(result.message, contains('1500'));
    expect(result.message, contains(previousMonthKey.toString()));
    expect(result.message, contains('راتب'));
    expect(result.message, contains('راتب شهري'));
    expect(result.message, isNot(contains('2200')));
  });

  test('reads work remaining for the selected app month, not the device month', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final work = WorkRepository(database);
    final now = DateTime.now();
    final deviceMonth = MonthKey(year: now.year, month: now.month);
    final selectedMonth = MonthKey(
      year: now.month == 1 ? now.year - 1 : now.year,
      month: now.month == 1 ? 12 : now.month - 1,
    );
    final selectedDate = DateTime.utc(selectedMonth.year, selectedMonth.month, 15);
    final deviceDate = DateTime.utc(deviceMonth.year, deviceMonth.month, 15);
    await work.saveEntry(WorkEntry(
      id: 'selected-month-advance',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(400),
      dueMonth: selectedMonth,
      recordedAt: selectedDate,
    ));
    await work.saveEntry(WorkEntry(
      id: 'selected-month-payment',
      kind: WorkEntryKind.salaryPayment,
      amount: Money.fromMinorUnits(200),
      dueMonth: selectedMonth,
      recordedAt: selectedDate,
    ));
    await work.saveEntry(WorkEntry(
      id: 'selected-month-salary',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(1500),
      dueMonth: selectedMonth,
      recordedAt: selectedDate,
    ));
    await work.saveTransfer(WorkHomeTransfer(
      id: 'selected-month-transfer',
      amount: Money.fromMinorUnits(300),
      transferredAt: selectedDate,
    ));

    await work.saveEntry(WorkEntry(
      id: 'device-month-advance',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(900),
      dueMonth: deviceMonth,
      recordedAt: deviceDate,
    ));
    await work.saveTransfer(WorkHomeTransfer(
      id: 'device-month-transfer',
      amount: Money.fromMinorUnits(100),
      transferredAt: deviceDate,
    ));

    final registry = ActionRegistry(
      work: work,
      home: HomeExpenseRepository(database),
      bills: HomeBillRepository(database),
      debts: DebtRepository(database),
      categories: HomeExpenseCategoryRepository(database),
      selectedMonth: selectedMonth,
    );
    final result = await registry.execute('read_work_remaining', {});

    expect(result.message, 'الباقي في العمل: 300');
  });
}
