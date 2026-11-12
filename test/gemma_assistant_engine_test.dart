import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
