import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/core/database/app_database.dart' show AppDatabase;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test('persists home expenses with integer money and due month', () async {
    final workRepository = WorkRepository(database);
    await workRepository.saveEntry(
      WorkEntry(
        id: 'fund-home-1-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(2000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 9),
      ),
    );
    await workRepository.saveTransfer(
      WorkHomeTransfer(
        id: 'fund-home-1',
        amount: Money.fromMinorUnits(2000),
        transferredAt: DateTime.utc(2026, 11, 9),
      ),
    );
    final repository = HomeExpenseRepository(database);
    await repository.save(
      HomeExpense(
        id: 'home-1',
        amount: Money.fromMinorUnits(1250),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 10),
        dueMonth: MonthKey(year: 2026, month: 11),
        note: 'Groceries',
      ),
    );
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

  test(
    'records partial payments and updates remaining balance atomically',
    () async {
      final repository = DebtRepository(database);
      await repository.save(
        DebtEntry(
          id: 'debt-payment',
          direction: DebtDirection.debtor,
          originalAmount: Money.fromMinorUnits(1000),
          outstandingAmount: Money.fromMinorUnits(1000),
          dueMonth: MonthKey(year: 2026, month: 11),
          createdAt: DateTime.utc(2026, 11, 1),
          counterparty: 'Counterparty',
        ),
      );
      await repository.recordPayment(
        DebtPayment(
          id: 'payment-1',
          debtId: 'debt-payment',
          amount: Money.fromMinorUnits(300),
          paidAt: DateTime.utc(2026, 11, 12),
        ),
      );
      await repository.recordPayment(
        DebtPayment(
          id: 'payment-2',
          debtId: 'debt-payment',
          amount: Money.fromMinorUnits(200),
          paidAt: DateTime.utc(2026, 11, 13),
        ),
      );
      final debt = (await database.select(database.debts).get()).single;
      final payments = await database.select(database.debtPayments).get();
      expect(debt.outstandingAmountMinorUnits, 500);
      expect(payments, hasLength(2));
      expect(payments.map((p) => p.amountMinorUnits), [300, 200]);
    },
  );

  test(
    'rejects payment above remaining balance without partial writes',
    () async {
      final repository = DebtRepository(database);
      await repository.save(
        DebtEntry(
          id: 'debt-limit',
          direction: DebtDirection.creditor,
          originalAmount: Money.fromMinorUnits(500),
          outstandingAmount: Money.fromMinorUnits(200),
          dueMonth: MonthKey(year: 2026, month: 11),
          createdAt: DateTime.utc(2026, 11, 1),
          counterparty: 'Counterparty',
        ),
      );
      await expectLater(
        repository.recordPayment(
          DebtPayment(
            id: 'payment-too-large',
            debtId: 'debt-limit',
            amount: Money.fromMinorUnits(201),
            paidAt: DateTime.utc(2026, 11, 14),
          ),
        ),
        throwsArgumentError,
      );
      expect(await database.select(database.debtPayments).get(), isEmpty);
      expect(
        (await database.select(database.debts).get())
            .single
            .outstandingAmountMinorUnits,
        200,
      );
    },
  );

  test('supports updating and deleting home expenses', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'fund-home-crud-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(300),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'fund-home-crud',
        amount: Money.fromMinorUnits(300),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeExpenseRepository(database);
    final original = HomeExpense(
      id: 'home-crud',
      amount: Money.fromMinorUnits(100),
      categoryId: 'food',
      expenseDate: DateTime.utc(2026, 11, 1),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.save(original);
    await repository.save(
      HomeExpense(
        id: original.id,
        amount: Money.fromMinorUnits(250),
        categoryId: 'utilities',
        expenseDate: DateTime.utc(2026, 11, 2),
        dueMonth: MonthKey(year: 2026, month: 12),
      ),
    );
    var rows = await database.select(database.homeExpenses).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinorUnits, 250);
    expect(rows.single.categoryId, 'utilities');
    expect(rows.single.dueMonth, 12);
    await repository.delete(original.id);
    expect(await database.select(database.homeExpenses).get(), isEmpty);
  });


  test('home cash from a previous month cannot fund a new month expense', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'november-cash-only',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'november-transfer-only',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );

    await expectLater(
      HomeExpenseRepository(database).save(
        HomeExpense(
          id: 'december-expense-without-december-funds',
          amount: Money.fromMinorUnits(1),
          categoryId: 'food',
          expenseDate: DateTime.utc(2026, 12, 1),
          dueMonth: MonthKey(year: 2026, month: 12),
        ),
      ),
      throwsA(isA<InsufficientHomeBalanceException>()),
    );
  });

  test('rejects an expense above transferred balance without saving it', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'fund-home-limit-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'fund-home-limit',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeExpenseRepository(database);
    await expectLater(
      repository.save(
        HomeExpense(
          id: 'expense-too-large',
          amount: Money.fromMinorUnits(1100),
          categoryId: 'food',
          expenseDate: DateTime.utc(2026, 11, 2),
          dueMonth: MonthKey(year: 2026, month: 11),
        ),
      ),
      throwsA(
        isA<InsufficientHomeBalanceException>()
            .having((error) => error.availableMinorUnits, 'available', 1000)
            .having((error) => error.requestedMinorUnits, 'requested', 1100),
      ),
    );
    expect(await database.select(database.homeExpenses).get(), isEmpty);
  });

  test('editing an expense restores its old amount before balance check', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'fund-home-edit-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'fund-home-edit',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeExpenseRepository(database);
    final original = HomeExpense(
      id: 'expense-edit',
      amount: Money.fromMinorUnits(800),
      categoryId: 'food',
      expenseDate: DateTime.utc(2026, 11, 1),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.save(original);
    await repository.save(
      HomeExpense(
        id: original.id,
        amount: Money.fromMinorUnits(1000),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 2),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );
    await expectLater(
      repository.save(
        HomeExpense(
          id: original.id,
          amount: Money.fromMinorUnits(1001),
          categoryId: 'food',
          expenseDate: DateTime.utc(2026, 11, 3),
          dueMonth: MonthKey(year: 2026, month: 11),
        ),
      ),
      throwsA(isA<InsufficientHomeBalanceException>()),
    );
    final rows = await database.select(database.homeExpenses).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinorUnits, 1000);
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
    await repository.saveEntry(
      WorkEntry(
        id: original.id,
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(750),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime.utc(2026, 11, 2),
      ),
    );
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
    await repository.save(
      DebtEntry(
        id: original.id,
        direction: DebtDirection.creditor,
        originalAmount: Money.fromMinorUnits(1200),
        outstandingAmount: Money.fromMinorUnits(300),
        dueMonth: MonthKey(year: 2026, month: 12),
        createdAt: DateTime.utc(2026, 11, 2),
        counterparty: 'Updated',
      ),
    );
    var rows = await database.select(database.debts).get();
    expect(rows, hasLength(1));
    expect(rows.single.direction, 'creditor');
    expect(rows.single.originalAmountMinorUnits, 1200);
    expect(rows.single.outstandingAmountMinorUnits, 300);
    expect(rows.single.counterparty, 'Updated');
    await repository.delete(original.id);
    expect(await database.select(database.debts).get(), isEmpty);
  });

  test('supports updating and deleting a work-home transfer', () async {
    final repository = WorkRepository(database);
    await repository.saveEntry(
      WorkEntry(
        id: 'transfer-crud-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(450),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final original = WorkHomeTransfer(
      id: 'transfer-crud',
      amount: Money.fromMinorUnits(300),
      transferredAt: DateTime.utc(2026, 11, 1),
    );
    await repository.saveTransfer(original);
    await repository.saveTransfer(
      WorkHomeTransfer(
        id: original.id,
        amount: Money.fromMinorUnits(450),
        transferredAt: DateTime.utc(2026, 11, 2),
        note: 'Updated transfer',
      ),
    );
    var rows = await database.select(database.workHomeTransfers).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinorUnits, 450);
    expect(rows.single.note, 'Updated transfer');
    await repository.deleteTransfer(original.id);
    expect(await database.select(database.workHomeTransfers).get(), isEmpty);
  });

  test('editing a bill preserves its payment history', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-edit-funding-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(2000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-edit-funding',
        amount: Money.fromMinorUnits(2000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-edit-december-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(2000),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime.utc(2026, 12, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-edit-december-funding',
        amount: Money.fromMinorUnits(2000),
        transferredAt: DateTime.utc(2026, 12, 1),
      ),
    );
    final repository = HomeBillRepository(database);
    final original = HomeBill(
      id: 'bill-edit-history',
      title: 'Internet',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(800),
      dueMonth: MonthKey(year: 2026, month: 11),
      note: 'Original note',
    );
    await repository.saveBill(original);
    await repository.recordPayment(
      HomeBillPayment(
        id: 'bill-edit-payment-1',
        billId: original.id,
        amount: Money.fromMinorUnits(300),
        paidAt: DateTime.utc(2026, 11, 10),
        note: 'First partial payment',
      ),
    );

    await repository.saveBill(
      HomeBill(
        id: original.id,
        title: 'Internet updated',
        kind: HomeBillKind.monthly,
        amount: Money.fromMinorUnits(900),
        dueMonth: MonthKey(year: 2026, month: 12),
        note: 'Updated note',
      ),
    );

    final updated = (await repository.getBills()).single;
    final payments = await repository.paymentsFor(original.id);
    expect(updated.title, 'Internet updated');
    expect(updated.amount.minorUnits, 900);
    expect(updated.dueMonth, MonthKey(year: 2026, month: 12));
    expect(updated.paidMinorUnits, 300);
    expect(updated.remainingMinorUnits, 600);
    expect(payments, hasLength(1));
    expect(payments.single.id, 'bill-edit-payment-1');
    expect(payments.single.amount.minorUnits, 300);
    expect(payments.single.note, 'First partial payment');

    await expectLater(
      repository.saveBill(
        HomeBill(
          id: original.id,
          title: 'Internet updated',
          kind: HomeBillKind.monthly,
          amount: Money.fromMinorUnits(299),
          dueMonth: MonthKey(year: 2026, month: 12),
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.paymentsFor(original.id), hasLength(1));
    expect((await repository.getBills()).single.amount.minorUnits, 900);
  });

  test('cannot move a partially paid bill into an unfunded month', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-move-november-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-move-november-transfer',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'bill-move-protected',
      title: 'Internet',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(800),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.saveBill(bill);
    await repository.recordPayment(
      HomeBillPayment(
        id: 'bill-move-protected-payment',
        billId: bill.id,
        amount: Money.fromMinorUnits(300),
        paidAt: DateTime.utc(2026, 11, 10),
      ),
    );

    await expectLater(
      repository.saveBill(
        HomeBill(
          id: bill.id,
          title: bill.title,
          kind: bill.kind,
          amount: Money.fromMinorUnits(800),
          dueMonth: MonthKey(year: 2026, month: 12),
        ),
      ),
      throwsA(isA<InsufficientBillPaymentBalanceException>()),
    );

    final saved = (await repository.getBills()).single;
    expect(saved.dueMonth, MonthKey(year: 2026, month: 11));
    expect(saved.paidMinorUnits, 300);
    expect(saved.remainingMinorUnits, 500);
    expect(await repository.paymentsFor(bill.id), hasLength(1));
  });

  test('cannot increase an existing bill beyond its funded monthly balance', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-increase-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-increase-transfer',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'bill-increase-protected',
      title: 'Internet',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(800),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.saveBill(bill);

    await expectLater(
      repository.saveBill(
        HomeBill(
          id: bill.id,
          title: bill.title,
          kind: bill.kind,
          amount: Money.fromMinorUnits(1001),
          dueMonth: bill.dueMonth,
        ),
      ),
      throwsA(isA<InsufficientBillPaymentBalanceException>()),
    );

    expect((await repository.getBills()).single.amount.minorUnits, 800);
  });

  test('cannot undo a later-month payment if the original due month is no longer funded', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'undo-cross-month-november-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(750),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'undo-cross-month-november-transfer',
        amount: Money.fromMinorUnits(750),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveEntry(
      WorkEntry(
        id: 'undo-cross-month-december-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(580),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime.utc(2026, 12, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'undo-cross-month-december-transfer',
        amount: Money.fromMinorUnits(580),
        transferredAt: DateTime.utc(2026, 12, 1),
      ),
    );
    final bills = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'undo-cross-month-rent',
      title: 'Rent',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(580),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await bills.saveBill(bill);
    await bills.recordPayment(
      HomeBillPayment(
        id: 'undo-cross-month-payment',
        billId: bill.id,
        amount: Money.fromMinorUnits(580),
        paidAt: DateTime.utc(2026, 12, 5),
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'undo-cross-month-later-expense',
        amount: Money.fromMinorUnits(200),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 20),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );

    await expectLater(
      bills.undoPayment('undo-cross-month-payment'),
      throwsA(isA<InsufficientBillPaymentBalanceException>()),
    );
    expect(await bills.paymentsFor(bill.id), hasLength(1));
    expect((await bills.getBills()).single.remainingMinorUnits, 0);
  });

  test('undoing a same-month bill payment preserves the reserved total', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'undo-same-month-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(750),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'undo-same-month-transfer',
        amount: Money.fromMinorUnits(750),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final bills = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'undo-same-month-rent',
      title: 'Rent',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(580),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await bills.saveBill(bill);
    await bills.recordPayment(
      HomeBillPayment(
        id: 'undo-same-month-payment',
        billId: bill.id,
        amount: Money.fromMinorUnits(580),
        paidAt: DateTime.utc(2026, 11, 5),
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'undo-same-month-expense',
        amount: Money.fromMinorUnits(170),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 6),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );

    await bills.undoPayment('undo-same-month-payment');

    expect(await bills.paymentsFor(bill.id), isEmpty);
    expect((await bills.getBills()).single.remainingMinorUnits, 580);
    expect(await bills.outstandingForMonth(MonthKey(year: 2026, month: 11)), 580);
  });

  test('monthly bills remain obligations until payments are made', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-funding-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-funding',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'internet-november',
      title: 'Internet',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(500),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.saveBill(bill);
    expect((await repository.getBills()).single.remainingMinorUnits, 500);
    await repository.recordPayment(
      HomeBillPayment(
        id: 'internet-payment-1',
        billId: bill.id,
        amount: Money.fromMinorUnits(200),
        paidAt: DateTime.utc(2026, 11, 10),
      ),
    );
    final saved = (await repository.getBills()).single;
    expect(saved.paidMinorUnits, 200);
    expect(saved.remainingMinorUnits, 300);
    expect(saved.isSettled, isFalse);
    await expectLater(
      HomeExpenseRepository(database).save(
        HomeExpense(
          id: 'daily-expense-after-bill-payment',
          amount: Money.fromMinorUnits(801),
          categoryId: 'shopping',
          expenseDate: DateTime.utc(2026, 11, 11),
          dueMonth: MonthKey(year: 2026, month: 11),
        ),
      ),
      throwsA(isA<InsufficientHomeBalanceException>()),
    );
  });

  test('reserves unpaid rent and counts it only once after payment', () async {
    final month = MonthKey(year: 2026, month: 11);
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'reserved-rent-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(750),
        dueMonth: month,
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'reserved-rent-transfer',
        amount: Money.fromMinorUnits(750),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );

    final bills = HomeBillRepository(database);
    final rent = HomeBill(
      id: 'reserved-rent',
      title: 'Rent',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(580),
      dueMonth: month,
    );
    await bills.saveBill(rent);
    expect(await bills.outstandingForMonth(month), 580);

    final expenses = HomeExpenseRepository(database);
    await expectLater(
      expenses.save(
        HomeExpense(
          id: 'over-budget-expense',
          amount: Money.fromMinorUnits(171),
          categoryId: 'shopping',
          expenseDate: DateTime.utc(2026, 11, 2),
          dueMonth: month,
        ),
      ),
      throwsA(isA<InsufficientHomeBalanceException>()),
    );
    await expenses.save(
      HomeExpense(
        id: 'allowed-daily-expense',
        amount: Money.fromMinorUnits(150),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 2),
        dueMonth: month,
      ),
    );

    await bills.recordPayment(
      HomeBillPayment(
        id: 'reserved-rent-payment',
        billId: rent.id,
        amount: Money.fromMinorUnits(580),
        paidAt: DateTime.utc(2026, 11, 3),
      ),
    );
    expect(await bills.paymentsTotalForMonth(month), 580);
    expect(await bills.outstandingForMonth(month), 0);

    final availableBalance =
        750 - 150 - await bills.paymentsTotalForMonth(month) -
        await bills.outstandingForMonth(month);
    expect(availableBalance, 20);
  });

  test('rent can be paid in installments and cannot exceed home cash balance', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'rent-funding-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'rent-funding',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'rent-test-daily-expense',
        amount: Money.fromMinorUnits(500),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 2),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );
    final repository = HomeBillRepository(database);
    final rent = HomeBill(
      id: 'rent-november',
      title: 'Rent',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(900),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.saveBill(rent);
    await repository.recordPayment(
      HomeBillPayment(
        id: 'rent-payment-1',
        billId: rent.id,
        amount: Money.fromMinorUnits(400),
        paidAt: DateTime.utc(2026, 11, 5),
      ),
    );
    await expectLater(
      repository.recordPayment(
        HomeBillPayment(
          id: 'rent-payment-2',
          billId: rent.id,
          amount: Money.fromMinorUnits(101),
          paidAt: DateTime.utc(2026, 11, 12),
        ),
      ),
      throwsA(isA<InsufficientBillPaymentBalanceException>()),
    );
    final saved = (await repository.getBills()).single;
    expect(saved.paidMinorUnits, 400);
    expect(saved.remainingMinorUnits, 500);
    expect(await repository.paymentsFor(rent.id), hasLength(1));
  });

  test('bill payments cannot exceed the outstanding bill amount', () async {
    await WorkRepository(database).saveEntry(
      WorkEntry(
        id: 'bill-overpay-funding-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await WorkRepository(database).saveTransfer(
      WorkHomeTransfer(
        id: 'bill-overpay-funding',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final repository = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'water-november',
      title: 'Water',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(300),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await repository.saveBill(bill);
    await repository.recordPayment(
      HomeBillPayment(
        id: 'water-payment-1',
        billId: bill.id,
        amount: Money.fromMinorUnits(200),
        paidAt: DateTime.utc(2026, 11, 5),
      ),
    );
    await expectLater(
      repository.recordPayment(
        HomeBillPayment(
          id: 'water-payment-over',
          billId: bill.id,
          amount: Money.fromMinorUnits(101),
          paidAt: DateTime.utc(2026, 11, 6),
        ),
      ),
      throwsArgumentError,
    );
    expect((await repository.getBills()).single.remainingMinorUnits, 100);
  });



  test('rejects a work-to-home transfer when no cash was received', () async {
    final repository = WorkRepository(database);
    await expectLater(
      repository.saveTransfer(
        WorkHomeTransfer(
          id: 'transfer-without-cash',
          amount: Money.fromMinorUnits(1),
          transferredAt: DateTime.utc(2026, 11, 2),
        ),
      ),
      throwsA(isA<InsufficientWorkBalanceException>()),
    );
    expect(await database.select(database.workHomeTransfers).get(), isEmpty);
  });

  test('limits transfers to cash received in the same month', () async {
    final repository = WorkRepository(database);
    await repository.saveEntry(
      WorkEntry(
        id: 'cash-november',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await expectLater(
      repository.saveTransfer(
        WorkHomeTransfer(
          id: 'transfer-december-with-november-cash',
          amount: Money.fromMinorUnits(1),
          transferredAt: DateTime.utc(2026, 12, 1),
        ),
      ),
      throwsA(isA<InsufficientWorkBalanceException>()),
    );
  });

  test('rejects transfers above cash actually received at work', () async {
    final repository = WorkRepository(database);
    await repository.saveEntry(
      WorkEntry(
        id: 'cash-received',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await repository.saveTransfer(
      WorkHomeTransfer(
        id: 'valid-transfer',
        amount: Money.fromMinorUnits(400),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await expectLater(
      repository.saveTransfer(
        WorkHomeTransfer(
          id: 'over-transfer',
          amount: Money.fromMinorUnits(101),
          transferredAt: DateTime.utc(2026, 11, 3),
        ),
      ),
      throwsA(isA<InsufficientWorkBalanceException>()),
    );
    expect(await database.select(database.workHomeTransfers).get(), hasLength(1));
  });

  test('cannot reduce or delete transfers already committed to home expenses', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'home-funding-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'home-funding-transfer',
        amount: Money.fromMinorUnits(600),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'committed-home-expense',
        amount: Money.fromMinorUnits(500),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 3),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );

    await expectLater(
      work.saveTransfer(
        WorkHomeTransfer(
          id: 'home-funding-transfer',
          amount: Money.fromMinorUnits(400),
          transferredAt: DateTime.utc(2026, 11, 2),
        ),
      ),
      throwsA(isA<TransferWouldOverdrawHomeException>()),
    );
    await expectLater(
      work.deleteTransfer('home-funding-transfer'),
      throwsA(isA<TransferWouldOverdrawHomeException>()),
    );
    expect(
      (await database.select(database.workHomeTransfers).get()).single.amountMinorUnits,
      600,
    );
  });

  test('cannot reduce or delete transfers reserved for unpaid monthly bills', () async {
    final work = WorkRepository(database);
    final month = MonthKey(year: 2026, month: 11);
    await work.saveEntry(
      WorkEntry(
        id: 'unpaid-bill-protection-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: month,
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'unpaid-bill-protection-transfer',
        amount: Money.fromMinorUnits(750),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await HomeBillRepository(database).saveBill(
      HomeBill(
        id: 'unpaid-bill-protection-rent',
        title: 'Rent',
        kind: HomeBillKind.rent,
        amount: Money.fromMinorUnits(580),
        dueMonth: month,
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'unpaid-bill-protection-expense',
        amount: Money.fromMinorUnits(150),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 3),
        dueMonth: month,
      ),
    );

    await expectLater(
      work.saveTransfer(
        WorkHomeTransfer(
          id: 'unpaid-bill-protection-transfer',
          amount: Money.fromMinorUnits(729),
          transferredAt: DateTime.utc(2026, 11, 2),
        ),
      ),
      throwsA(isA<TransferWouldOverdrawHomeException>()),
    );
    await expectLater(
      work.deleteTransfer('unpaid-bill-protection-transfer'),
      throwsA(isA<TransferWouldOverdrawHomeException>()),
    );
    expect(
      (await database.select(database.workHomeTransfers).get()).single.amountMinorUnits,
      750,
    );
  });

  test('cannot move a transfer away from a month with unpaid bill obligations', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'move-protection-november-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveEntry(
      WorkEntry(
        id: 'move-protection-december-income',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime.utc(2026, 12, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'move-protection-transfer',
        amount: Money.fromMinorUnits(750),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await HomeBillRepository(database).saveBill(
      HomeBill(
        id: 'move-protection-rent',
        title: 'November rent',
        kind: HomeBillKind.rent,
        amount: Money.fromMinorUnits(580),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );

    await expectLater(
      work.saveTransfer(
        WorkHomeTransfer(
          id: 'move-protection-transfer',
          amount: Money.fromMinorUnits(750),
          transferredAt: DateTime.utc(2026, 12, 2),
        ),
      ),
      throwsA(isA<TransferWouldOverdrawHomeException>()),
    );
    final saved = await database.select(database.workHomeTransfers).get();
    expect(saved.single.amountMinorUnits, 750);
    expect(
      DateTime.fromMillisecondsSinceEpoch(saved.single.transferredAtEpochMillis).month,
      11,
    );
  });

  test('cannot delete work cash already transferred to home', () async {
    final repository = WorkRepository(database);
    await repository.saveEntry(
      WorkEntry(
        id: 'income-protect',
        kind: WorkEntryKind.advance,
        amount: Money.fromMinorUnits(800),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await repository.saveTransfer(
      WorkHomeTransfer(
        id: 'transfer-protect',
        amount: Money.fromMinorUnits(700),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await expectLater(
      repository.deleteEntry('income-protect'),
      throwsA(isA<InsufficientWorkBalanceException>()),
    );
    expect(await database.select(database.workEntries).get(), hasLength(1));
  });


  test('restores a debt only with matching payment history', () async {
    final repository = DebtRepository(database);
    final debt = DebtEntry(
      id: 'restored-debt-valid',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(1000),
      outstandingAmount: Money.fromMinorUnits(700),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime.utc(2026, 11, 1),
      counterparty: 'Counterparty',
    );
    final payment = DebtPayment(
      id: 'restored-debt-payment-valid',
      debtId: debt.id,
      amount: Money.fromMinorUnits(300),
      paidAt: DateTime.utc(2026, 11, 2),
    );

    await repository.restoreDebt(debt, [payment]);

    final saved = (await database.select(database.debts).get()).single;
    final payments = await database.select(database.debtPayments).get();
    expect(saved.originalAmountMinorUnits, 1000);
    expect(saved.outstandingAmountMinorUnits, 700);
    expect(payments.single.amountMinorUnits, 300);
  });

  test('rejects restored debt when payment total disagrees with outstanding balance', () async {
    final repository = DebtRepository(database);
    final debt = DebtEntry(
      id: 'restored-debt-mismatch',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(1000),
      outstandingAmount: Money.fromMinorUnits(700),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime.utc(2026, 11, 1),
      counterparty: 'Counterparty',
    );

    await expectLater(
      repository.restoreDebt(debt, [
        DebtPayment(
          id: 'restored-debt-payment-mismatch',
          debtId: debt.id,
          amount: Money.fromMinorUnits(250),
          paidAt: DateTime.utc(2026, 11, 2),
        ),
      ]),
      throwsArgumentError,
    );

    expect(await database.select(database.debts).get(), isEmpty);
    expect(await database.select(database.debtPayments).get(), isEmpty);
  });

  test('rejects restored payments linked to a different debt', () async {
    final repository = DebtRepository(database);
    final debt = DebtEntry(
      id: 'restored-debt-owner',
      direction: DebtDirection.creditor,
      originalAmount: Money.fromMinorUnits(500),
      outstandingAmount: Money.fromMinorUnits(400),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime.utc(2026, 11, 1),
      counterparty: 'Counterparty',
    );

    await expectLater(
      repository.restoreDebt(debt, [
        DebtPayment(
          id: 'restored-debt-wrong-owner-payment',
          debtId: 'another-debt',
          amount: Money.fromMinorUnits(100),
          paidAt: DateTime.utc(2026, 11, 2),
        ),
      ]),
      throwsArgumentError,
    );

    expect(await database.select(database.debts).get(), isEmpty);
    expect(await database.select(database.debtPayments).get(), isEmpty);
  });

  test('debt edits cannot desynchronize outstanding balance from payment ledger', () async {
    final repository = DebtRepository(database);
    await repository.save(
      DebtEntry(
        id: 'debt-ledger-integrity',
        direction: DebtDirection.debtor,
        originalAmount: Money.fromMinorUnits(1000),
        outstandingAmount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        createdAt: DateTime.utc(2026, 11, 1),
        counterparty: 'Counterparty',
      ),
    );
    await repository.recordPayment(
      DebtPayment(
        id: 'debt-ledger-payment',
        debtId: 'debt-ledger-integrity',
        amount: Money.fromMinorUnits(300),
        paidAt: DateTime.utc(2026, 11, 2),
      ),
    );

    await expectLater(
      repository.save(
        DebtEntry(
          id: 'debt-ledger-integrity',
          direction: DebtDirection.debtor,
          originalAmount: Money.fromMinorUnits(1200),
          outstandingAmount: Money.fromMinorUnits(800),
          dueMonth: MonthKey(year: 2026, month: 12),
          createdAt: DateTime.utc(2026, 11, 1),
          counterparty: 'Counterparty updated',
        ),
      ),
      throwsArgumentError,
    );
    final saved = (await database.select(database.debts).get()).single;
    expect(saved.originalAmountMinorUnits, 1000);
    expect(saved.outstandingAmountMinorUnits, 700);
    expect(await database.select(database.debtPayments).get(), hasLength(1));
  });

  test('debt with payment history cannot be deleted accidentally', () async {
    final repository = DebtRepository(database);
    await repository.save(
      DebtEntry(
        id: 'debt-protected-history',
        direction: DebtDirection.creditor,
        originalAmount: Money.fromMinorUnits(500),
        outstandingAmount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 11),
        createdAt: DateTime.utc(2026, 11, 1),
        counterparty: 'Counterparty',
      ),
    );
    await repository.recordPayment(
      DebtPayment(
        id: 'debt-protected-payment',
        debtId: 'debt-protected-history',
        amount: Money.fromMinorUnits(100),
        paidAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await expectLater(
      repository.delete('debt-protected-history'),
      throwsStateError,
    );
    expect(await database.select(database.debts).get(), hasLength(1));
    expect(await database.select(database.debtPayments).get(), hasLength(1));
  });

  test('clears financial records but preserves app settings', () async {
    final work = WorkRepository(database);
    await work.saveEntry(
      WorkEntry(
        id: 'reset-cash',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await work.saveTransfer(
      WorkHomeTransfer(
        id: 'reset-transfer',
        amount: Money.fromMinorUnits(1000),
        transferredAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await HomeExpenseRepository(database).save(
      HomeExpense(
        id: 'reset-expense',
        amount: Money.fromMinorUnits(100),
        categoryId: 'food',
        expenseDate: DateTime.utc(2026, 11, 3),
        dueMonth: MonthKey(year: 2026, month: 11),
      ),
    );
    final bills = HomeBillRepository(database);
    final bill = HomeBill(
      id: 'reset-bill',
      title: 'Internet',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(300),
      dueMonth: MonthKey(year: 2026, month: 11),
    );
    await bills.saveBill(bill);
    await bills.recordPayment(
      HomeBillPayment(
        id: 'reset-bill-payment',
        billId: bill.id,
        amount: Money.fromMinorUnits(50),
        paidAt: DateTime.utc(2026, 11, 4),
      ),
    );
    await DebtRepository(database).save(
      DebtEntry(
        id: 'reset-debt',
        direction: DebtDirection.debtor,
        originalAmount: Money.fromMinorUnits(200),
        outstandingAmount: Money.fromMinorUnits(200),
        dueMonth: MonthKey(year: 2026, month: 11),
        createdAt: DateTime.utc(2026, 11, 1),
        counterparty: 'Test',
      ),
    );
    await database.writeSetting('theme_mode', 'dark');

    await database.clearFinancialData();

    expect(await database.select(database.workEntries).get(), isEmpty);
    expect(await database.select(database.workHomeTransfers).get(), isEmpty);
    expect(await database.select(database.homeExpenses).get(), isEmpty);
    expect(await database.select(database.debts).get(), isEmpty);
    expect(await database.select(database.debtPayments).get(), isEmpty);
    expect(await bills.getBills(), isEmpty);
    expect(await database.readSetting('theme_mode'), 'dark');
  });

  test('reads legacy payment rows as salaryPayment without rewriting storage', () async {
    final recordedAt = DateTime.utc(2026, 11, 14);
    await database.customStatement(
      'INSERT INTO work_entries (id, kind, amount_minor_units, due_year, due_month, recorded_at_epoch_millis, note) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'legacy-payment-row',
        'payment',
        750,
        2026,
        11,
        recordedAt.millisecondsSinceEpoch,
        'Legacy salary payment',
      ],
    );

    final entries = await WorkRepository(database).watchEntries().first;
    expect(entries, hasLength(1));
    expect(entries.single.id, 'legacy-payment-row');
    expect(entries.single.kind, WorkEntryKind.salaryPayment);
    expect(entries.single.amount.minorUnits, 750);

    final stored = (await database.select(database.workEntries).get()).single;
    expect(stored.kind, 'payment');
    expect(stored.note, 'Legacy salary payment');
  });

}
