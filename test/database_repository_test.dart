import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/core/database/app_database.dart' show AppDatabase;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('persists home expenses with integer money and due month', () async {
    final repository = HomeExpenseRepository(database);
    final expense = HomeExpense(
      id: 'home-1',
      amount: Money.fromMinorUnits(1250),
      categoryId: 'food',
      expenseDate: DateTime.utc(2026, 11, 10),
      dueMonth: MonthKey(year: 2026, month: 11),
      note: 'Groceries',
    );

    await repository.save(expense);
    final rows = await database.select(database.homeExpenses).get();

    expect(rows, hasLength(1));
    expect(rows.single.amountMinorUnits, 1250);
    expect(rows.single.dueYear, 2026);
    expect(rows.single.dueMonth, 11);
  });

  test('persists work entries and one transfer record', () async {
    final repository = WorkRepository(database);
    await repository.saveEntry(
      WorkEntry(
        id: 'work-1',
        kind: WorkEntryKind.advance,
        amount: Money.fromMinorUnits(5000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 10),
      ),
    );
    await repository.saveTransfer(
      WorkHomeTransfer(
        id: 'transfer-1',
        amount: Money.fromMinorUnits(2000),
        transferredAt: DateTime.utc(2026, 11, 10),
      ),
    );

    expect(await database.select(database.workEntries).get(), hasLength(1));
    expect(
      await database.select(database.workHomeTransfers).get(),
      hasLength(1),
    );
  });

  test('persists debt direction and outstanding balance', () async {
    final repository = DebtRepository(database);
    await repository.save(
      DebtEntry(
        id: 'debt-1',
        direction: DebtDirection.debtor,
        originalAmount: Money.fromMinorUnits(9000),
        outstandingAmount: Money.fromMinorUnits(4000),
        dueMonth: MonthKey(year: 2026, month: 12),
        createdAt: DateTime.utc(2026, 11, 10),
        counterparty: 'Counterparty',
      ),
    );

    final rows = await database.select(database.debts).get();
    expect(rows.single.direction, 'debtor');
    expect(rows.single.originalAmountMinorUnits, 9000);
    expect(rows.single.outstandingAmountMinorUnits, 4000);
  });

  test('supports updating and deleting home expenses', () async {
    final repository = HomeExpenseRepository(database);
    final original = HomeExpense(
      id: 'home-crud',
      amount: Money.fromMinorUnits(100),
      categoryId: 'food',
      expenseDate: DateTime.utc(2026, 11, 1),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.save(original);
    await repository.save(HomeExpense(
      id: original.id,
      amount: Money.fromMinorUnits(250),
      categoryId: 'utilities',
      expenseDate: DateTime.utc(2026, 11, 2),
      dueMonth: MonthKey(year: 2026, month: 12),
    ));
    var rows = await database.select(database.homeExpenses).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinorUnits, 250);
    expect(rows.single.categoryId, 'utilities');
    expect(rows.single.dueMonth, 12);
    await repository.delete(original.id);
    expect(await database.select(database.homeExpenses).get(), isEmpty);
  });

  test('supports updating and deleting work entries', () async {
    final repository = WorkRepository(database);
    final original = WorkEntry(
      id: 'work-crud',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(500),
      dueMonth: MonthKey(year: 2026, month: 11),
      recordedAt: DateTime.utc(2026, 11, 1),
    );
    await repository.saveEntry(original);
    await repository.saveEntry(WorkEntry(
      id: original.id,
      kind: WorkEntryKind.payment,
      amount: Money.fromMinorUnits(750),
      dueMonth: MonthKey(year: 2026, month: 12),
      recordedAt: DateTime.utc(2026, 11, 2),
    ));
    var rows = await database.select(database.workEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'payment');
    expect(rows.single.amountMinorUnits, 750);
    expect(rows.single.dueMonth, 12);
    await repository.deleteEntry(original.id);
    expect(await database.select(database.workEntries).get(), isEmpty);
  });

  test('supports updating and deleting debts', () async {
    final repository = DebtRepository(database);
    final original = DebtEntry(
      id: 'debt-crud',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(1000),
      outstandingAmount: Money.fromMinorUnits(800),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime.utc(2026, 11, 1),
      counterparty: 'First',
    );
    await repository.save(original);
    await repository.save(DebtEntry(
      id: original.id,
      direction: DebtDirection.creditor,
      originalAmount: Money.fromMinorUnits(1200),
      outstandingAmount: Money.fromMinorUnits(300),
      dueMonth: MonthKey(year: 2026, month: 12),
      createdAt: DateTime.utc(2026, 11, 2),
      counterparty: 'Updated',
    ));
    var rows = await database.select(database.debts).get();
    expect(rows, hasLength(1));
    expect(rows.single.direction, 'creditor');
    expect(rows.single.originalAmountMinorUnits, 1200);
    expect(rows.single.outstandingAmountMinorUnits, 300);
    expect(rows.single.counterparty, 'Updated');
    await repository.delete(original.id);
    expect(await database.select(database.debts).get(), isEmpty);
  });

}
