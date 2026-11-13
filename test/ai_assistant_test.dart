import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_confirmation.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/number_normalizer.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantConfirmation', () {
    const command = AssistantCommand(
      name: 'save_work_entry',
      parameters: {'kind': 'salary', 'amountMinorUnits': 500},
    );

    test('does not execute a write until explicit approval', () async {
      final confirmation = AssistantConfirmation();
      var executions = 0;
      confirmation.request(command);

      expect(confirmation.pending, same(command));
      expect(executions, 0);

      final result = await confirmation.approve((approved) async {
        executions++;
        expect(approved, same(command));
        return const ActionExecution(message: 'saved');
      });

      expect(executions, 1);
      expect(result?.message, 'saved');
      expect(confirmation.hasPending, isFalse);
    });

    test('cancelled write cannot be approved or executed', () async {
      final confirmation = AssistantConfirmation();
      var executions = 0;
      confirmation.request(command);
      confirmation.cancel();

      final result = await confirmation.approve((_) async {
        executions++;
        return const ActionExecution(message: 'saved');
      });

      expect(result, isNull);
      expect(executions, 0);
    });
  });

  group('NumberNormalizer', () {
    const normalizer = NumberNormalizer();
    test('normalizes Arabic-Indic and Persian digits', () {
      expect(normalizer.normalizeDigits('١٢٣٤٥٦٧٨٩٠'), '1234567890');
      expect(normalizer.normalizeDigits('۱۲۳۴۵۶۷۸۹۰'), '1234567890');
    });
    test('parses common Arabic number words', () {
      expect(normalizer.parseInteger('ألف وخمسمئة'), 1500);
      expect(normalizer.parseInteger('خمسمائة'), 500);
      expect(normalizer.parseInteger('ألف'), 1000);
    });
    test('parses numeric values after digit normalization', () {
      expect(normalizer.parseInteger('٢٥٠'), 250);
      expect(normalizer.parseInteger('۲۵۰'), 250);
    });
    test('does not guess unknown number phrases', () {
      expect(normalizer.parseInteger('مبلغ كبير'), isNull);
    });
  });

  group('FakeAssistantEngine', () {
    const engine = FakeAssistantEngine();
    const actions = ['read_work_remaining', 'read_month_total', 'save_work_entry'];
    test('returns a read-only command for remaining balance', () async {
      final result = await engine.interpret('كم الباقي؟', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_work_remaining');
    });
    test('asks for missing amount instead of guessing', () async {
      final result = await engine.interpret('أضف راتب لشهر 2026-11', actions);
      expect(result.kind, AssistantResultKind.clarification);
    });
    test('asks for missing section in monthly query', () async {
      final result = await engine.interpret('مجموع شهر 2026-11', actions);
      expect(result.kind, AssistantResultKind.clarification);
    });
    test('returns not understood for unsupported input', () async {
      final result = await engine.interpret('افعل شيئاً غير معروف', actions);
      expect(result.kind, AssistantResultKind.notUnderstood);
    });
    test('parses amount words and month without model', () async {
      final result = await engine.interpret('راتب ألف وخمسمئة لشهر 2026-11', actions);
      expect(result.command!.parameters['amountMinorUnits'], 1500);
    });
  });

  group('ActionRegistry', () {
    late AppDatabase database;
    late ActionRegistry registry;
    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      registry = ActionRegistry(
        work: WorkRepository(database),
        home: HomeExpenseRepository(database),
        debts: DebtRepository(database),
      );
    });
    tearDown(() => database.close());

    test('validates required fields and types before execution', () async {
      expect(registry.validate('save_work_entry', {'kind':'salary'}), isNotNull);
      expect(registry.validate('save_work_entry', {
        'kind':'salary','amountMinorUnits':'100','year':2026,'month':11,
      }), isNotNull);
      expect(registry.validate('save_work_entry', {
        'kind':'salary','amountMinorUnits':100,'year':2026,'month':11,
      }), isNull);
    });

    test('creates and undoes work entry', () async {
      final result = await registry.execute('save_work_entry', {
        'kind':'salary','amountMinorUnits':1000,'year':2026,'month':11,
      });
      expect(await database.select(database.workEntries).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.workEntries).get(), isEmpty);
    });

    test('deletes and undoes work entry', () async {
      final created = await registry.execute('save_work_entry', {
        'kind':'salary','amountMinorUnits':1000,'year':2026,'month':11,'id':'w1',
      });
      final deleted = await registry.execute('delete_work_entry', {'id':'w1'});
      expect(await database.select(database.workEntries).get(), isEmpty);
      await deleted.undo!();
      expect(await database.select(database.workEntries).get(), hasLength(1));
      await created.undo!();
    });

    test('creates and undoes home expense', () async {
      await registry.execute('save_work_home_transfer', {'amountMinorUnits':500});
      final result = await registry.execute('save_home_expense', {
        'amountMinorUnits':250,'categoryId':'food','date':'2026-11-12',
        'year':2026,'month':11,
      });
      expect(await database.select(database.homeExpenses).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.homeExpenses).get(), isEmpty);
    });

    test('deletes and undoes home expense', () async {
      await registry.execute('save_work_home_transfer', {'amountMinorUnits':500});
      await registry.execute('save_home_expense', {
        'amountMinorUnits':250,'categoryId':'food','date':'2026-11-12',
        'year':2026,'month':11,'id':'h1',
      });
      final result = await registry.execute('delete_home_expense', {'id':'h1'});
      await result.undo!();
      expect(await database.select(database.homeExpenses).get(), hasLength(1));
    });

    test('creates and undoes work-to-home transfer', () async {
      final result = await registry.execute('save_work_home_transfer', {'amountMinorUnits':500});
      expect(await database.select(database.workHomeTransfers).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.workHomeTransfers).get(), isEmpty);
    });

    test('deletes and undoes transfer', () async {
      await registry.execute('save_work_home_transfer', {'amountMinorUnits':500,'id':'t1'});
      final result = await registry.execute('delete_work_home_transfer', {'id':'t1'});
      await result.undo!();
      expect(await database.select(database.workHomeTransfers).get(), hasLength(1));
    });

    test('creates and undoes debt', () async {
      final result = await registry.execute('save_debt', {
        'amountMinorUnits':700,'direction':'debtor','counterparty':'Ali',
        'year':2026,'month':11,
      });
      expect(await database.select(database.debts).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.debts).get(), isEmpty);
    });

    test('cannot delete debt with payment history through assistant action', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits':700,'direction':'debtor','counterparty':'Ali',
        'year':2026,'month':11,'id':'d1',
      });
      await registry.execute('record_debt_payment', {'debtId':'d1','amountMinorUnits':200});
      await expectLater(
        registry.execute('delete_debt', {'id':'d1'}),
        throwsStateError,
      );
      expect(await database.select(database.debts).get(), hasLength(1));
      expect(await database.select(database.debtPayments).get(), hasLength(1));
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 500);
    });

    test('records and undoes a debt payment atomically', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits':700,'direction':'debtor','counterparty':'Ali',
        'year':2026,'month':11,'id':'d2',
      });
      final result = await registry.execute('record_debt_payment', {'debtId':'d2','amountMinorUnits':200});
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 500);
      await result.undo!();
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 700);
      expect(await database.select(database.debtPayments).get(), isEmpty);
    });

    test('read-only actions do not expose undo and run without approval metadata', () async {
      final descriptor = registry.descriptor('read_work_remaining')!;
      expect(descriptor.readOnly, isTrue);
      final result = await registry.execute('read_work_remaining', {});
      expect(result.undo, isNull);
    });

    test('monthly read requires an explicit section and month', () async {
      expect(registry.validate('read_month_total', {'year':2026,'month':11}), isNotNull);
      final result = await registry.execute('read_month_total', {
        'section':'work','year':2026,'month':11,
      });
      expect(result.undo, isNull);
    });
  });
}
