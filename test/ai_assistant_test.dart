import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_confirmation.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/number_normalizer.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/data/home_expense_category_repository.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
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

  group('LocalRuleAssistantEngine', () {
    const engine = LocalRuleAssistantEngine();
    const actions = [
      'read_work_remaining',
      'read_month_total',
      'save_work_entry',
      'save_work_home_transfer',
      'save_home_expense',
      'read_dashboard_summary',
      'navigate_to_section',
    ];
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
    test('routes transfer to home before generic home expense matching', () async {
      final result = await engine.interpret('حوّل 750 إلى المنزل', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'save_work_home_transfer');
      expect(result.command!.parameters['amountMinorUnits'], 750);
    });
    test('does not route transfer when transfer action is unavailable', () async {
      final result = await engine.interpret(
        'حوّل 750 إلى المنزل',
        ['read_work_remaining'],
      );
      expect(result.kind, AssistantResultKind.notUnderstood);
    });
    test('does not pretend to process media without Gemma', () async {
      final result = await engine.interpret(
        'حلل الصورة',
        actions,
        media: AssistantMedia(imageBytes: Uint8List.fromList([1, 2, 3])),
      );
      expect(result.kind, AssistantResultKind.notUnderstood);
    });
    test('reads a dashboard summary on a financial overview request', () async {
      final result = await engine.interpret('اعطني ملخص وضعي المالي', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_dashboard_summary');
    });

    test('uses a specifically requested month for dashboard summary', () async {
      final result = await engine.interpret(
        'اعطني ملخص شهر 2026-10',
        actions,
      );

      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'read_dashboard_summary');
      expect(result.command!.parameters['year'], 2026);
      expect(result.command!.parameters['month'], 10);
    });

    test('navigates to a requested app section', () async {
      final result = await engine.interpret('افتح قسم الديون', actions);
      expect(result.kind, AssistantResultKind.command);
      expect(result.command!.name, 'navigate_to_section');
      expect(result.command!.parameters['section'], 'debts');
    });

    test('does not navigate when the navigation action is unavailable', () async {
      final result = await engine.interpret(
        'افتح قسم الديون',
        ['read_work_remaining'],
      );
      expect(result.kind, AssistantResultKind.notUnderstood);
    });

    test('returns not understood for unsupported input', () async {
      final result = await engine.interpret('افعل شيئاً غير معروف', actions);
      expect(result.kind, AssistantResultKind.notUnderstood);
    });
    test('parses amount words and month without model', () async {
      final result = await engine.interpret('سجل راتب ألف وخمسمئة لشهر 2026-11', actions);
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
        bills: HomeBillRepository(database),
        debts: DebtRepository(database),
        categories: HomeExpenseCategoryRepository(database),
      );
    });
    tearDown(() => database.close());

    Future<void> seedWorkCash() async {
      final now = DateTime.now();
      await WorkRepository(database).saveEntry(WorkEntry(
        id: 'seed-cash', kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: now.year, month: now.month), recordedAt: now,
      ));
    }

    Future<void> seedWorkCashForMonth(
      int year,
      int month,
      int amount, {
      required String id,
    }) async {
      await WorkRepository(database).saveEntry(WorkEntry(
        id: id,
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(amount),
        dueMonth: MonthKey(year: year, month: month),
        recordedAt: DateTime(year, month, 1),
      ));
    }

    test('reads work records only from the selected month', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'selected-month-record',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 10),
      ));
      await work.saveEntry(WorkEntry(
        id: 'other-month-record',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(900),
        dueMonth: MonthKey(year: 2026, month: 10),
        recordedAt: DateTime(2026, 10, 10),
      ));
      final selectedRegistry = ActionRegistry(
        work: work,
        home: HomeExpenseRepository(database),
        bills: HomeBillRepository(database),
        debts: DebtRepository(database),
        categories: HomeExpenseCategoryRepository(database),
        selectedMonth: MonthKey(year: 2026, month: 11),
      );

      final result = await selectedRegistry.execute('read_work_records', {});

      expect(result.message, contains('selected-month-record'));
      expect(result.message, isNot(contains('other-month-record')));
    });

    test('validates required fields and types before execution', () async {
      expect(registry.validate('save_work_entry', {'kind':'salary'}), isNotNull);
      expect(registry.validate('save_work_entry', {
        'kind':'salary','amountMinorUnits':'100','year':2026,'month':11,
      }), isNotNull);
      expect(registry.validate('save_work_entry', {
        'kind':'salary','amountMinorUnits':100,'year':2026,'month':11,
      }), isNull);
    });

    test('normalizes the assistant payment alias to a salary payment record', () async {
      final now = DateTime.now();
      await registry.execute('save_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 1500,
        'year': now.year,
        'month': now.month,
      });

      final result = await registry.execute('save_work_entry', {
        'kind': 'payment',
        'amountMinorUnits': 1000,
        'year': now.year,
        'month': now.month,
      });

      final saved = await WorkRepository(database).watchEntries().first;
      final payment = saved.singleWhere(
        (entry) => entry.kind == WorkEntryKind.salaryPayment,
      );
      expect(payment.amount.minorUnits, 1000);
      expect(result.message, 'تم حفظ سجل العمل');

      final summary = await registry.execute('read_dashboard_summary', {});
      expect(
        summary.dashboardSummary!.overview.salary.minorUnits,
        1500,
      );
      expect(
        summary.dashboardSummary!.overview.payments.minorUnits,
        1000,
      );
      expect(
        summary.dashboardSummary!.overview.currentSalaryOutstandingMinorUnits,
        500,
      );
    });

    test('maps salary edits that overdraw work transfers to a localized assistant error', () async {
      await seedWorkCashForMonth(2026, 11, 500, id: 'salary-cash');
      await WorkRepository(database).saveTransfer(WorkHomeTransfer(
        id: 'salary-cash-transfer',
        amount: Money.fromMinorUnits(400),
        transferredAt: DateTime(2026, 11, 5),
      ));

      await expectLater(
        registry.execute('save_work_entry', {
          'id': 'salary-cash',
          'kind': 'salaryPayment',
          'amountMinorUnits': 300,
          'year': 2026,
          'month': 11,
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'work_balance_insufficient',
        )),
      );
    });

    test('maps insufficient household balance when adding an expense', () async {
      await seedWorkCashForMonth(2026, 11, 100, id: 'expense-cash');
      await WorkRepository(database).saveTransfer(WorkHomeTransfer(
        id: 'expense-transfer',
        amount: Money.fromMinorUnits(100),
        transferredAt: DateTime(2026, 11, 5),
      ));

      await expectLater(
        registry.execute('save_home_expense', {
          'amountMinorUnits': 200,
          'categoryId': 'groceries',
          'date': '2026-11-06',
          'year': 2026,
          'month': 11,
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'home_balance_insufficient',
        )),
      );
    });

    test('creates a transfer in the requested month when no exact day is given', () async {
      await seedWorkCashForMonth(2026, 10, 500, id: 'month-only-transfer-cash');

      final execution = await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 150,
        'year': 2026,
        'month': 10,
      });

      final transfer = (await WorkRepository(database).watchTransfers().first)
          .single;
      expect(transfer.amount.minorUnits, 150);
      expect(transfer.transferredAt.year, 2026);
      expect(transfer.transferredAt.month, 10);
      await execution.undo!();
      expect(await WorkRepository(database).watchTransfers().first, isEmpty);
    });

    test('maps transfers larger than received work cash to an assistant error', () async {
      await seedWorkCashForMonth(2026, 11, 500, id: 'transfer-limit-cash');

      await expectLater(
        registry.execute('save_work_home_transfer', {
          'amountMinorUnits': 600,
          'date': '2026-11-05',
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'work_balance_insufficient',
        )),
      );
    });

    test('maps a bill edit that exceeds the available home balance', () async {
      await seedWorkCashForMonth(2026, 11, 500, id: 'bill-limit-cash');
      await WorkRepository(database).saveTransfer(WorkHomeTransfer(
        id: 'bill-limit-transfer',
        amount: Money.fromMinorUnits(500),
        transferredAt: DateTime(2026, 11, 1),
      ));
      await registry.execute('save_home_bill', {
        'title': 'Internet',
        'kind': 'monthly',
        'amountMinorUnits': 100,
        'year': 2026,
        'month': 11,
      });
      final billId = (await HomeBillRepository(database).getBills()).single.id;

      await expectLater(
        registry.execute('save_home_bill', {
          'id': billId,
          'amountMinorUnits': 600,
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'bill_commitment_not_available',
        )),
      );
    });

    test('maps a moved transfer that leaves old-month home obligations uncovered', () async {
      await seedWorkCashForMonth(2026, 11, 500, id: 'nov-obligation-cash');
      await seedWorkCashForMonth(2026, 12, 500, id: 'dec-obligation-cash');
      await WorkRepository(database).saveTransfer(WorkHomeTransfer(
        id: 'obligation-transfer',
        amount: Money.fromMinorUnits(300),
        transferredAt: DateTime(2026, 11, 1),
      ));
      await registry.execute('save_home_expense', {
        'amountMinorUnits': 200,
        'categoryId': 'groceries',
        'date': '2026-11-10',
        'year': 2026,
        'month': 11,
      });

      await expectLater(
        registry.execute('save_work_home_transfer', {
          'id': 'obligation-transfer',
          'amountMinorUnits': 300,
          'date': '2026-12-01',
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'home_commitment_not_covered',
        )),
      );
    });

    test('creates and undoes work entry', () async {
      final result = await registry.execute('save_work_entry', {
        'kind':'salary','amountMinorUnits':1000,'year':2026,'month':11,
      });
      expect(await database.select(database.workEntries).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.workEntries).get(), isEmpty);
    });
    test('prepares and applies a partial work edit without changing its date or type', () async {
      final work = WorkRepository(database);
      final originalDate = DateTime(2026, 11, 8);
      await work.saveEntry(WorkEntry(
        id: 'partial-work',
        kind: WorkEntryKind.advance,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: originalDate,
        note: 'ملاحظة أصلية',
      ));

      final prepared = await registry.prepareUpdateParameters(
        'save_work_entry',
        const {'id': 'partial-work', 'amountMinorUnits': 800},
      );
      expect(prepared['kind'], 'advance');
      expect(prepared['year'], 2026);
      expect(prepared['month'], 11);
      expect(prepared['date'], '2026-11-08');
      expect(prepared['note'], 'ملاحظة أصلية');
      expect(registry.validate('save_work_entry', prepared), isNull);

      await registry.execute('save_work_entry', prepared);
      final updated = (await work.watchEntries().first).single;
      expect(updated.amount.minorUnits, 800);
      expect(updated.kind, WorkEntryKind.advance);
      expect(updated.recordedAt, originalDate);
      expect(updated.note, 'ملاحظة أصلية');
    });
    test('synchronizes the due month when an edited work record receives a new date', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'date-change-work',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 8),
      ));

      final prepared = await registry.prepareUpdateParameters(
        'save_work_entry',
        const {'id': 'date-change-work', 'date': '2026-12-08'},
      );
      expect(prepared['year'], 2026);
      expect(prepared['month'], 12);
      expect(prepared['amountMinorUnits'], 500);
      expect(registry.validate('save_work_entry', prepared), isNull);

      await registry.execute('save_work_entry', prepared);
      final updated = (await work.watchEntries().first).single;
      expect(updated.dueMonth, MonthKey(year: 2026, month: 12));
      expect(updated.recordedAt, DateTime(2026, 12, 8));
    });

    test('keeps the original transfer date when a partial edit omits a new date', () async {
      final work = WorkRepository(database);
      await seedWorkCashForMonth(2026, 11, 1000, id: 'partial-transfer-cash');
      final originalDate = DateTime(2026, 11, 12);
      await work.saveTransfer(WorkHomeTransfer(
        id: 'partial-transfer',
        amount: Money.fromMinorUnits(600),
        transferredAt: originalDate,
        note: 'التحويل الأصلي',
      ));

      final prepared = await registry.prepareUpdateParameters(
        'save_work_home_transfer',
        const {'id': 'partial-transfer', 'amountMinorUnits': 850},
      );
      expect(prepared['date'], '2026-11-12');
      expect(prepared['note'], 'التحويل الأصلي');

      await registry.execute('save_work_home_transfer', prepared);
      final updated = (await work.watchTransfers().first).single;
      expect(updated.amount.minorUnits, 850);
      expect(updated.transferredAt, originalDate);
      expect(updated.note, 'التحويل الأصلي');
    });
    test('moves a transfer to a requested month while preserving its calendar day', () async {
      final work = WorkRepository(database);
      await seedWorkCashForMonth(2026, 11, 600, id: 'nov-transfer-cash');
      await seedWorkCashForMonth(2026, 12, 700, id: 'dec-transfer-cash');
      await work.saveTransfer(WorkHomeTransfer(
        id: 'month-transfer',
        amount: Money.fromMinorUnits(600),
        transferredAt: DateTime(2026, 11, 12),
      ));

      final prepared = await registry.prepareUpdateParameters(
        'save_work_home_transfer',
        const {
          'id': 'month-transfer',
          'amountMinorUnits': 700,
          'year': 2026,
          'month': 12,
        },
      );
      expect(prepared['date'], '2026-12-12');
      expect(registry.validate('save_work_home_transfer', prepared), isNull);

      await registry.execute('save_work_home_transfer', prepared);
      final updated = (await work.watchTransfers().first).single;
      expect(updated.transferredAt, DateTime(2026, 12, 12));
    });

    test('moves an edited expense month without changing its original day where possible', () async {
      final work = WorkRepository(database);
      final home = HomeExpenseRepository(database);
      await seedWorkCashForMonth(2026, 10, 50, id: 'oct-expense-cash');
      await seedWorkCashForMonth(2026, 11, 100, id: 'nov-expense-cash');
      await work.saveTransfer(WorkHomeTransfer(
        id: 'oct-expense-transfer',
        amount: Money.fromMinorUnits(50),
        transferredAt: DateTime(2026, 10, 1),
      ));
      await work.saveTransfer(WorkHomeTransfer(
        id: 'nov-expense-transfer',
        amount: Money.fromMinorUnits(100),
        transferredAt: DateTime(2026, 11, 1),
      ));
      await home.save(HomeExpense(
        id: 'partial-expense',
        amount: Money.fromMinorUnits(50),
        categoryId: 'groceries',
        expenseDate: DateTime(2026, 10, 31),
        dueMonth: MonthKey(year: 2026, month: 10),
        note: 'ملاحظة المصروف',
      ));

      final prepared = await registry.prepareUpdateParameters(
        'save_home_expense',
        const {
          'id': 'partial-expense',
          'amountMinorUnits': 75,
          'year': 2026,
          'month': 11,
        },
      );
      expect(prepared['categoryId'], 'groceries');
      expect(prepared['categoryName'], isNotEmpty);
      expect(prepared['date'], '2026-11-30');
      expect(prepared['note'], 'ملاحظة المصروف');
      expect(registry.validate('save_home_expense', prepared), isNull);
    });

    test('deletes and undoes work entry', () async {
      final created = await registry.execute('save_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 1000,
        'year': 2026,
        'month': 11,
      });
      final saved = (await WorkRepository(database).watchEntries().first).single;
      final deleted = await registry.execute('delete_work_entry', {
        'id': saved.id,
      });
      expect(await database.select(database.workEntries).get(), isEmpty);
      await deleted.undo!();
      expect(await database.select(database.workEntries).get(), hasLength(1));
      await created.undo!();
    });

    test('creates and undoes home expense', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {'amountMinorUnits':500, 'date': DateTime.now().toIso8601String()});
      final now = DateTime.now();
      final result = await registry.execute('save_home_expense', {
        'amountMinorUnits':250,'categoryId':'groceries','date':now.toIso8601String(),
        'year':now.year,'month':now.month,
      });
      expect(await database.select(database.homeExpenses).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.homeExpenses).get(), isEmpty);
    });

    test('deletes and undoes home expense', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {'amountMinorUnits':500, 'date': DateTime.now().toIso8601String()});
      final now = DateTime.now();
      await registry.execute('save_home_expense', {
        'amountMinorUnits': 250,
        'categoryId': 'groceries',
        'date': now.toIso8601String(),
        'year': now.year,
        'month': now.month,
      });
      final saved = (await HomeExpenseRepository(database).watchAll().first).single;
      final result = await registry.execute('delete_home_expense', {
        'id': saved.id,
      });
      await result.undo!();
      expect(await database.select(database.homeExpenses).get(), hasLength(1));
    });

    test('creates and undoes work-to-home transfer', () async {
      await seedWorkCash();
      final result = await registry.execute('save_work_home_transfer', {'amountMinorUnits':500, 'date': DateTime.now().toIso8601String()});
      expect(await database.select(database.workHomeTransfers).get(), hasLength(1));
      await result.undo!();
      expect(await database.select(database.workHomeTransfers).get(), isEmpty);
    });

    test('deletes and undoes transfer', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 500,
        'date': DateTime.now().toIso8601String(),
      });
      final saved = (await WorkRepository(database).watchTransfers().first).single;
      final result = await registry.execute('delete_work_home_transfer', {
        'id': saved.id,
      });
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
    test('partial debt edit retains its direction, party, date, and payment history', () async {
      final date = DateTime(2026, 11, 4);
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'creditor',
        'counterparty': 'Samer',
        'year': 2026,
        'month': 11,
        'date': '2026-11-04',
        'note': 'original debt note',
      });
      final partialDebtId = (await DebtRepository(database).watchAll().first).single.id;
      await registry.execute('record_debt_payment', {
        'debtId': partialDebtId,
        'amountMinorUnits': 150,
      });

      final prepared = await registry.prepareUpdateParameters(
        'save_debt',
        {'id': partialDebtId, 'amountMinorUnits': 900},
      );
      expect(prepared['direction'], 'creditor');
      expect(prepared['counterparty'], 'Samer');
      expect(prepared['year'], 2026);
      expect(prepared['month'], 11);
      expect(prepared['date'], '2026-11-04');
      expect(prepared['note'], 'original debt note');
      expect(registry.validate('save_debt', prepared), isNull);

      await registry.execute('save_debt', prepared);
      final debt = (await DebtRepository(database).watchAll().first).single;
      expect(debt.originalAmount.minorUnits, 900);
      expect(debt.outstandingAmount.minorUnits, 750);
      expect(debt.direction.name, 'creditor');
      expect(debt.counterparty, 'Samer');
      expect(debt.createdAt, date);
      expect((await DebtRepository(database).watchPayments(debt.id).first), hasLength(1));
    });

    test('editing debt recalculates outstanding balance after recorded payments', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'debtor',
        'counterparty': 'Ali',
        'year': 2026,
        'month': 11,
      });
      final editedDebtId = (await DebtRepository(database).watchAll().first).single.id;

      await registry.execute('save_debt', {
        'amountMinorUnits': 900,
        'id': editedDebtId,
      });
      var debt = (await database.select(database.debts).get()).single;
      expect(debt.originalAmountMinorUnits, 900);
      expect(debt.outstandingAmountMinorUnits, 900);

      await WorkRepository(database).saveTransfer(
        WorkHomeTransfer(
          id: 'debt-payment-test-funding-0',
          amount: Money.fromMinorUnits(5000),
          transferredAt: DateTime(2026, 11, 1),
        ),
      );
      await registry.execute('record_debt_payment', {
        'debtId': editedDebtId,
        'amountMinorUnits': 200,
      });
      await registry.execute('save_debt', {
        'amountMinorUnits': 1000,
        'id': editedDebtId,
      });
      debt = (await database.select(database.debts).get()).single;
      expect(debt.originalAmountMinorUnits, 1000);
      expect(debt.outstandingAmountMinorUnits, 800);

      await expectLater(
        registry.execute('save_debt', {
          'amountMinorUnits': 100,
          'direction': 'debtor',
          'counterparty': 'Ali',
          'year': 2026,
          'month': 11,
          'id': editedDebtId,
        }),
        throwsA(isA<AssistantActionException>().having(
          (error) => error.code,
          'code',
          'debt_amount_below_paid',
        )),
      );
    });

    test('cannot delete debt with payment history through assistant action', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'debtor',
        'counterparty': 'Ali',
        'year': 2026,
        'month': 11,
      });
      final protectedDebtId = (await DebtRepository(database).watchAll().first).single.id;
      await WorkRepository(database).saveTransfer(
        WorkHomeTransfer(
          id: 'debt-payment-test-funding-1',
          amount: Money.fromMinorUnits(5000),
          transferredAt: DateTime(2026, 11, 1),
        ),
      );
      await registry.execute('record_debt_payment', {
        'debtId': protectedDebtId,
        'amountMinorUnits': 200,
      });
      await expectLater(
        registry.execute('delete_debt', {'id': protectedDebtId}),
        throwsA(
          isA<AssistantActionException>().having(
            (error) => error.code,
            'code',
            'debt_has_payments',
          ),
        ),
      );
      expect(await database.select(database.debts).get(), hasLength(1));
      expect(await database.select(database.debtPayments).get(), hasLength(1));
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 500);
    });

    test('deletes and restores a debt when no payment history exists', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'debtor',
        'counterparty': 'Ali',
        'year': 2026,
        'month': 11,
      });

      final debtWithoutPaymentsId = (await DebtRepository(database).watchAll().first).single.id;
      final deletion = await registry.execute('delete_debt', {
        'id': debtWithoutPaymentsId,
      });
      expect(await database.select(database.debts).get(), isEmpty);

      await deletion.undo!();
      final restored = await database.select(database.debts).get();
      expect(restored, hasLength(1));
      expect(restored.single.id, debtWithoutPaymentsId);
      expect(restored.single.outstandingAmountMinorUnits, 700);
    });

    test('records and undoes a debt payment atomically', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'debtor',
        'counterparty': 'Ali',
        'year': 2026,
        'month': 11,
      });
      final paymentDebtId = (await DebtRepository(database).watchAll().first).single.id;
      await WorkRepository(database).saveTransfer(
        WorkHomeTransfer(
          id: 'debt-payment-test-funding-2',
          amount: Money.fromMinorUnits(5000),
          transferredAt: DateTime(2026, 11, 1),
        ),
      );
      final result = await registry.execute('record_debt_payment', {
        'debtId': paymentDebtId,
        'amountMinorUnits': 200,
      });
      final homeOutflows = await database.select(database.homeExpenses).get();
      expect(homeOutflows, hasLength(1));
      expect(homeOutflows.single.categoryId, 'debt_repayment');
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 500);
      await result.undo!();
      expect((await database.select(database.debts).get()).single.outstandingAmountMinorUnits, 700);
      expect(await database.select(database.debtPayments).get(), isEmpty);
      expect(await database.select(database.homeExpenses).get(), isEmpty);
    });

    test('assistant can create, list, and record a household bill payment', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 500, 'date': DateTime.now().toIso8601String(),
      });
      await registry.execute('save_home_bill', {
        'title': 'Internet',
        'kind': 'monthly',
        'amountMinorUnits': 400,
        'year': DateTime.now().year,
        'month': DateTime.now().month,
      });
      final internetBillId = (await HomeBillRepository(database).getBills()).single.id;

      final bills = await registry.execute('read_home_bills', {});
      expect(bills.message, contains('Internet'));
      expect(bills.message, contains('400'));

      final payment = await registry.execute('record_home_bill_payment', {
        'billId': internetBillId,
        'amountMinorUnits': 100,
      });
      expect(payment.undo, isNotNull);
      expect((await HomeBillRepository(database).getBills()).single.remainingMinorUnits, 300);
      await payment.undo!();
      expect((await HomeBillRepository(database).getBills()).single.remainingMinorUnits, 400);
      expect(await HomeBillRepository(database).paymentsFor(internetBillId), isEmpty);
    });

    test('bill edit preview retains payment history and accurate remaining amount', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 500,
        'date': DateTime.now().toIso8601String(),
      });
      final now = DateTime.now();
      await registry.execute('save_home_bill', {
        'title': 'Electricity',
        'kind': 'monthly',
        'amountMinorUnits': 400,
        'year': now.year,
        'month': now.month,
        'date': DateTime(now.year, now.month, 5).toIso8601String(),
        'note': 'monthly power bill',
      });
      final billEditPreviewId = (await HomeBillRepository(database).getBills()).single.id;
      await registry.execute('record_home_bill_payment', {
        'billId': billEditPreviewId,
        'amountMinorUnits': 100,
        'date': DateTime.now().toIso8601String(),
      });

      final prepared = await registry.prepareUpdateParameters(
        'save_home_bill',
        {'id': billEditPreviewId, 'amountMinorUnits': 500},
      );
      expect(prepared['title'], 'Electricity');
      expect(prepared['kind'], 'monthly');
      expect(prepared['paidMinorUnits'], 100);
      expect(prepared['remainingMinorUnits'], 300);
      expect(prepared['note'], 'monthly power bill');
      expect(registry.validate('save_home_bill', prepared), isNull);

      await registry.execute('save_home_bill', prepared);
      final bill = (await HomeBillRepository(database).getBills()).single;
      expect(bill.title, 'Electricity');
      expect(bill.paidMinorUnits, 100);
      expect(bill.remainingMinorUnits, 400);
    });
    test('creates, lists and removes a custom category safely', () async {
      final create = await registry.execute('save_home_category', {
        'name': 'Office supplies',
      });
      final categories = await registry.execute('read_home_categories', {});
      expect(categories.message, contains('Office supplies'));
      final saved = (await HomeExpenseCategoryRepository(database).getAll())
          .singleWhere((item) => item.name == 'Office supplies');
      final deleted = await registry.execute('delete_home_category', {
        'name': 'Office supplies',
      });
      expect(
        (await HomeExpenseCategoryRepository(database).getAll())
            .any((item) => item.id == saved.id),
        isFalse,
      );
      await deleted.undo!();
      expect(
        (await HomeExpenseCategoryRepository(database).getAll())
            .any((item) => item.id == saved.id),
        isTrue,
      );
      await create.undo!();
    });

    test('lists all work records across months when allRecords is requested', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'work-oct',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 10),
        recordedAt: DateTime(2026, 10, 2),
      ));
      await work.saveEntry(WorkEntry(
        id: 'work-nov',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(1200),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 2),
      ));
      final result = await registry.execute('read_work_records', {
        'allRecords': true,
      });
      expect(result.message, contains('work-oct'));
      expect(result.message, contains('work-nov'));
    });

    test('records and reads bill payments by exact bill title', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 500,
        'date': DateTime.now().toIso8601String(),
      });
      await registry.execute('save_home_bill', {
        'title': 'Electricity',
        'kind': 'monthly',
        'amountMinorUnits': 300,
        'year': DateTime.now().year,
        'month': DateTime.now().month,
      });
      final billByTitleId = (await HomeBillRepository(database).getBills()).single.id;
      final payment = await registry.execute('record_home_bill_payment', {
        'billTitle': 'Electricity',
        'amountMinorUnits': 75,
      });
      expect(payment.message, contains('الفاتورة'));
      final history = await registry.execute('read_home_bill_payments', {
        'billTitle': 'Electricity',
      });
      expect(history.message, contains('75'));
      await payment.undo!();
      expect(
        await HomeBillRepository(database).paymentsFor(billByTitleId),
        isEmpty,
      );
    });

    test('records and reads debt payments by exact counterparty', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 500,
        'direction': 'debtor',
        'counterparty': 'Samer',
        'year': DateTime.now().year,
        'month': DateTime.now().month,
      });
      final payment = await WorkRepository(database).saveTransfer(
        WorkHomeTransfer(
          id: 'debt-history-funding-0',
          amount: Money.fromMinorUnits(2000),
          transferredAt: DateTime.now(),
        ),
      );
      await registry.execute('record_debt_payment', {
        'counterparty': 'Samer',
        'direction': 'debtor',
        'amountMinorUnits': 125,
      });
      final history = await registry.execute('read_debt_payments', {
        'counterparty': 'Samer',
        'direction': 'debtor',
      });
      expect(history.message, contains('125'));
      expect(
        (await database.select(database.debts).get()).single.outstandingAmountMinorUnits,
        375,
      );
      await payment.undo!();
      expect(
        (await database.select(database.debts).get()).single.outstandingAmountMinorUnits,
        500,
      );
    });

    test('reads work-to-home transfer history', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 350,
        'date': DateTime.now().toIso8601String(),
      });
      final result = await registry.execute('read_work_transfers', {});
      expect(result.message, contains('350'));
    });

    test('reads debt payment history for the selected debt', () async {
      await registry.execute('save_debt', {
        'amountMinorUnits': 700,
        'direction': 'debtor',
        'counterparty': 'Ali',
        'year': 2026,
        'month': 11,
      });
      final historyDebtId = (await DebtRepository(database).watchAll().first).single.id;
      await WorkRepository(database).saveTransfer(
        WorkHomeTransfer(
          id: 'debt-history-funding-1',
          amount: Money.fromMinorUnits(2000),
          transferredAt: DateTime.now(),
        ),
      );
      await registry.execute('record_debt_payment', {
        'debtId': historyDebtId,
        'amountMinorUnits': 225,
      });
      final result = await registry.execute('read_debt_payments', {
        'debtId': historyDebtId,
      });
      expect(result.message, contains('225'));
    });

    test('reads household bill payment history for the selected bill', () async {
      await seedWorkCash();
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 500, 'date': DateTime.now().toIso8601String(),
      });
      await registry.execute('save_home_bill', {
        'title': 'Internet', 'kind': 'monthly', 'amountMinorUnits': 400,
        'year': DateTime.now().year,
        'month': DateTime.now().month,
      });
      final historyBillId = (await HomeBillRepository(database).getBills()).single.id;
      await registry.execute('record_home_bill_payment', {
        'billId': historyBillId,
        'amountMinorUnits': 125,
      });
      final result = await registry.execute('read_home_bill_payments', {
        'billId': historyBillId,
      });
      expect(result.message, contains('125'));
    });

    test('reads dashboard metrics using the same calculations as the dashboard', () async {
      final now = DateTime.now();
      final month = MonthKey(year: now.year, month: now.month);

      await registry.execute('save_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 1500,
        'year': now.year,
        'month': now.month,
      });
      await registry.execute('save_work_entry', {
        'kind': 'advance',
        'amountMinorUnits': 300,
        'year': now.year,
        'month': now.month,
      });
      await registry.execute('save_work_entry', {
        'kind': 'salaryPayment',
        'amountMinorUnits': 200,
        'year': now.year,
        'month': now.month,
      });
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 400,
        'date': now.toIso8601String(),
      });
      await registry.execute('save_home_expense', {
        'amountMinorUnits': 100,
        'categoryId': 'groceries',
        'date': now.toIso8601String(),
        'year': now.year,
        'month': now.month,
      });
      await registry.execute('save_home_bill', {
        'title': 'Internet',
        'kind': 'monthly',
        'amountMinorUnits': 150,
        'year': now.year,
        'month': now.month,
      });
      final summaryBillId = (await HomeBillRepository(database).getBills()).single.id;
      await registry.execute('record_home_bill_payment', {
        'billId': summaryBillId,
        'amountMinorUnits': 50,
      });

      final result = await registry.execute('read_dashboard_summary', {});
      final summary = result.dashboardSummary!;

      expect(summary.month, month);
      expect(summary.overview.salary.minorUnits, 1500);
      expect(summary.overview.advances.minorUnits, 300);
      expect(summary.overview.payments.minorUnits, 200);
      expect(summary.overview.currentSalaryOutstandingMinorUnits, 1000);
      expect(summary.overview.salaryPaymentsApplied.minorUnits, 200);
      expect(summary.overview.workRemainingMinorUnits, 100);
      expect(summary.overview.homeExpenses.minorUnits, 100);
      expect(summary.overview.transfers.minorUnits, 400);
      expect(summary.homeBillPaymentsMinorUnits, 50);
      expect(summary.outstandingBillsAtMonthEndMinorUnits, 100);
      expect(summary.homeBalanceMinorUnits, 150);
      expect(summary.overview.creditorBalance.minorUnits, 0);
      expect(summary.overview.debtorBalance.minorUnits, 0);
      expect(result.undo, isNull);
    });

    test('uses explicit dashboard month instead of selected month', () async {
      final selectedRegistry = ActionRegistry(
        work: WorkRepository(database),
        home: HomeExpenseRepository(database),
        bills: HomeBillRepository(database),
        debts: DebtRepository(database),
        categories: HomeExpenseCategoryRepository(database),
        selectedMonth: MonthKey(year: 2026, month: 11),
      );

      expect(
        selectedRegistry.validate('read_dashboard_summary', {'year': 2026}),
        isNotNull,
      );
      expect(
        selectedRegistry.validate('read_dashboard_summary', {'month': 10}),
        isNotNull,
      );

      final result = await selectedRegistry.execute(
        'read_dashboard_summary',
        {'year': 2026, 'month': 10},
      );

      expect(result.dashboardSummary!.month, MonthKey(year: 2026, month: 10));
    });

    test('validates only supported navigation destinations', () async {
      const sections = [
        'dashboard',
        'work',
        'home',
        'debts',
        'ai',
        'settings',
      ];
      for (final section in sections) {
        expect(
          registry.validate('navigate_to_section', {'section': section}),
          isNull,
        );
      }
      expect(
        registry.validate('navigate_to_section', {'section': 'payments'}),
        isNotNull,
      );
      expect(
        registry.descriptor('navigate_to_section')!.readOnly,
        isTrue,
      );
    });

    test('reports received work cash minus transfers as remaining at work', () async {
      final now = DateTime.now();
      final month = {'year': now.year, 'month': now.month};

      await registry.execute('save_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 1500,
        ...month,
      });
      await registry.execute('save_work_entry', {
        'kind': 'advance',
        'amountMinorUnits': 300,
        ...month,
      });
      await registry.execute('save_work_entry', {
        'kind': 'salaryPayment',
        'amountMinorUnits': 200,
        ...month,
      });
      await registry.execute('save_work_home_transfer', {
        'amountMinorUnits': 250,
        'date': now.toIso8601String(),
      });

      final result = await registry.execute('read_work_remaining', {});
      expect(result.message, contains('250'));
    });

    test('deletes a work record by unique kind, amount and month and supports undo', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'salary-oct',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(1500),
        dueMonth: MonthKey(year: 2026, month: 10),
        recordedAt: DateTime(2026, 10, 1),
      ));
      await work.saveEntry(WorkEntry(
        id: 'salary-nov',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(1500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 1),
      ));

      final deletion = await registry.execute('delete_work_entry', {
        'kind': 'salary',
        'amountMinorUnits': 1500,
        'year': 2026,
        'month': 11,
      });

      expect((await work.watchEntries().first).map((item) => item.id),
          ['salary-oct']);
      await deletion.undo!();
      expect((await work.watchEntries().first).map((item) => item.id).toSet(),
          {'salary-oct', 'salary-nov'});
    });

    test('deletes a transfer by unique amount and date and supports undo', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'cash-transfer-test',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 1),
      ));
      await work.saveTransfer(WorkHomeTransfer(
        id: 'transfer-one',
        amount: Money.fromMinorUnits(250),
        transferredAt: DateTime(2026, 11, 14),
      ));
      await work.saveTransfer(WorkHomeTransfer(
        id: 'transfer-two',
        amount: Money.fromMinorUnits(250),
        transferredAt: DateTime(2026, 11, 15),
      ));

      final deletion = await registry.execute('delete_work_home_transfer', {
        'amountMinorUnits': 250,
        'date': '2026-11-15',
      });

      expect((await work.watchTransfers().first).map((item) => item.id),
          ['transfer-one']);
      await deletion.undo!();
      expect((await work.watchTransfers().first).map((item) => item.id).toSet(),
          {'transfer-one', 'transfer-two'});
    });

    test('deletes a home expense by a unique category amount and month and supports undo', () async {
      final work = WorkRepository(database);
      await work.saveEntry(WorkEntry(
        id: 'cash-expense-oct',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 10),
        recordedAt: DateTime(2026, 10, 1),
      ));
      await work.saveEntry(WorkEntry(
        id: 'cash-expense-nov',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 1),
      ));
      await work.saveTransfer(WorkHomeTransfer(
        id: 'transfer-oct',
        amount: Money.fromMinorUnits(500),
        transferredAt: DateTime(2026, 10, 1),
      ));
      await work.saveTransfer(WorkHomeTransfer(
        id: 'transfer-nov',
        amount: Money.fromMinorUnits(500),
        transferredAt: DateTime(2026, 11, 1),
      ));
      final home = HomeExpenseRepository(database);
      await home.save(HomeExpense(
        id: 'expense-oct',
        amount: Money.fromMinorUnits(50),
        categoryId: 'groceries',
        expenseDate: DateTime(2026, 10, 12),
        dueMonth: MonthKey(year: 2026, month: 10),
      ));
      await home.save(HomeExpense(
        id: 'expense-nov',
        amount: Money.fromMinorUnits(50),
        categoryId: 'groceries',
        expenseDate: DateTime(2026, 11, 12),
        dueMonth: MonthKey(year: 2026, month: 11),
      ));

      final deletion = await registry.execute('delete_home_expense', {
        'categoryId': 'groceries',
        'amountMinorUnits': 50,
        'year': 2026,
        'month': 11,
      });

      final remaining = await home.watchAll().first;
      expect(remaining.map((item) => item.id), ['expense-oct']);
      await deletion.undo!();
      expect((await home.watchAll().first).map((item) => item.id).toSet(),
          {'expense-oct', 'expense-nov'});
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
