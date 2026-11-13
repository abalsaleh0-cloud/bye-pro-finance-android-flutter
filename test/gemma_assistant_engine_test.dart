import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingGemmaGenerator implements GemmaTurnGenerator {
  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions,
  ) async {
    throw StateError('model failed');
  }
}

class _FakeGemmaGenerator implements GemmaTurnGenerator {
  _FakeGemmaGenerator(this.output);
  final GemmaModelOutput output;
  List<GemmaFunctionSpec>? receivedFunctions;
  String? receivedInput;

  @override
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions,
  ) async {
    receivedInput = userText;
    receivedFunctions = functions;
    return output;
  }
}

void main() {
  const actions = [
    'save_work_entry',
    'read_work_remaining',
    'read_month_total',
  ];

  group('GemmaAssistantEngine output validation', () {
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

    test('normalizes Arabic-Indic digits in numeric arguments', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.call('save_work_entry', {
          'kind': 'salary',
          'amountMinorUnits': '٢٥٠',
          'year': '٢٠٢٦',
          'month': '١١',
        }),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب ٢٥٠', actions);

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.parameters['amountMinorUnits'], 250);
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 11);
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

    test('returns a short clarification question from the model', () async {
      final generator = _FakeGemmaGenerator(
        const GemmaModelOutput.text('ما الشهر المستحق؟'),
      );
      final result = await GemmaAssistantEngine(generator)
          .interpret('سجل راتب', actions);

      expect(result.kind, AssistantResultKind.clarification);
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

  test('reads work remaining for the selected app month, not the device month', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final work = WorkRepository(database);
    await work.saveEntry(WorkEntry(
      id: 'selected-month-advance',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(400),
      dueMonth: MonthKey(year: 2026, month: 10),
      recordedAt: DateTime.utc(2026, 10, 2),
    ));
    await work.saveEntry(WorkEntry(
      id: 'selected-month-payment',
      kind: WorkEntryKind.salaryPayment,
      amount: Money.fromMinorUnits(200),
      dueMonth: MonthKey(year: 2026, month: 10),
      recordedAt: DateTime.utc(2026, 10, 5),
    ));
    await work.saveEntry(WorkEntry(
      id: 'selected-month-salary',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(1500),
      dueMonth: MonthKey(year: 2026, month: 10),
      recordedAt: DateTime.utc(2026, 10, 1),
    ));
    await work.saveTransfer(WorkHomeTransfer(
      id: 'selected-month-transfer',
      amount: Money.fromMinorUnits(300),
      transferredAt: DateTime.utc(2026, 10, 6),
    ));

    await work.saveEntry(WorkEntry(
      id: 'device-month-advance',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(900),
      dueMonth: MonthKey(year: 2026, month: 11),
      recordedAt: DateTime.utc(2026, 11, 2),
    ));
    await work.saveTransfer(WorkHomeTransfer(
      id: 'device-month-transfer',
      amount: Money.fromMinorUnits(100),
      transferredAt: DateTime.utc(2026, 11, 6),
    ));

    final registry = ActionRegistry(
      work: work,
      home: HomeExpenseRepository(database),
      bills: HomeBillRepository(database),
      debts: DebtRepository(database),
      selectedMonth: MonthKey(year: 2026, month: 10),
    );
    final result = await registry.execute('read_work_remaining', {});

    expect(result.message, 'الباقي في العمل: 300');
  });
}
