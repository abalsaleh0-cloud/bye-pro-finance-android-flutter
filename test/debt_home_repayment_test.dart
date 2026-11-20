import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => database.close());

  Future<void> fundHome(String id, int amount) async {
    final work = WorkRepository(database);
    await work.saveEntry(WorkEntry(
      id: '$id-salary',
      kind: WorkEntryKind.salaryPayment,
      amount: Money.fromMinorUnits(amount),
      dueMonth: MonthKey(year: 2026, month: 11),
      recordedAt: DateTime(2026, 11, 1),
    ));
    await work.saveTransfer(WorkHomeTransfer(
      id: id,
      amount: Money.fromMinorUnits(amount),
      transferredAt: DateTime(2026, 11, 1),
    ));
  }

  Future<DebtEntry> addDebtor({int amount = 600}) async {
    final debt = DebtEntry(
      id: 'repay-debt',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(amount),
      outstandingAmount: Money.fromMinorUnits(amount),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime(2026, 11, 2),
      counterparty: 'Test person',
    );
    await DebtRepository(database).save(debt);
    return debt;
  }

  test('home repayment updates debt and records one matching household outflow atomically', () async {
    final debt = await addDebtor();
    await fundHome('home-funding', 1000);

    await HomeExpenseRepository(database).saveDebtRepayment(
      DebtPayment(
        id: 'home-repayment-1',
        debtId: debt.id,
        amount: Money.fromMinorUnits(200),
        paidAt: DateTime(2026, 11, 10, 14, 30),
      ),
      counterparty: debt.counterparty,
    );

    final refreshed = (await DebtRepository(database).watchAll().first).single;
    expect(refreshed.outstandingAmount.minorUnits, 400);
    final expenses = await database.select(database.homeExpenses).get();
    expect(expenses, hasLength(1));
    expect(expenses.single.id, 'debt-payment-home-repayment-1');
    expect(expenses.single.categoryId, 'debt_repayment');
    expect(expenses.single.amountMinorUnits, 200);
    final payments = await database.select(database.debtPayments).get();
    expect(payments, hasLength(1));
    expect(payments.single.amountMinorUnits, 200);
    final activity = await DebtRepository(database).getActivity();
    expect(activity.where((item) => item.eventType == 'payment'), hasLength(1));
    expect(activity.where((item) => item.eventType == 'payment').single.counterparty, 'Test person');
  });

  test('linked home repayment cannot be edited or deleted as a normal expense', () async {
    final debt = await addDebtor();
    await fundHome('protected-home-funding', 1000);
    final home = HomeExpenseRepository(database);
    await home.saveDebtRepayment(
      DebtPayment(
        id: 'protected-repayment',
        debtId: debt.id,
        amount: Money.fromMinorUnits(100),
        paidAt: DateTime(2026, 11, 10),
      ),
      counterparty: debt.counterparty,
    );
    final linkedExpense = (await database.select(database.homeExpenses).get()).single;

    await expectLater(
      home.save(linkedExpense),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      home.delete(linkedExpense.id),
      throwsA(isA<StateError>()),
    );
    expect(await database.select(database.debtPayments).get(), hasLength(1));
    expect((await DebtRepository(database).watchAll().first).single.outstandingAmount.minorUnits, 500);
  });

  test('insufficient home balance leaves the debt and payment history unchanged', () async {
    final debt = await addDebtor();
    await fundHome('small-home-funding', 100);

    await expectLater(
      HomeExpenseRepository(database).saveDebtRepayment(
        DebtPayment(
          id: 'home-repayment-too-large',
          debtId: debt.id,
          amount: Money.fromMinorUnits(200),
          paidAt: DateTime(2026, 11, 10),
        ),
        counterparty: debt.counterparty,
      ),
      throwsA(isA<InsufficientHomeBalanceException>()),
    );

    final refreshed = (await DebtRepository(database).watchAll().first).single;
    expect(refreshed.outstandingAmount.minorUnits, 600);
    expect(await database.select(database.debtPayments).get(), isEmpty);
    expect(await database.select(database.homeExpenses).get(), isEmpty);
  });

  test('creditor debt cannot be settled through the home outflow action', () async {
    final debt = DebtEntry(
      id: 'creditor-debt',
      direction: DebtDirection.creditor,
      originalAmount: Money.fromMinorUnits(300),
      outstandingAmount: Money.fromMinorUnits(300),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime(2026, 11, 2),
      counterparty: 'Owes me',
    );
    await DebtRepository(database).save(debt);
    await fundHome('creditor-funding', 1000);

    await expectLater(
      HomeExpenseRepository(database).saveDebtRepayment(
        DebtPayment(
          id: 'wrong-direction-payment',
          debtId: debt.id,
          amount: Money.fromMinorUnits(100),
          paidAt: DateTime(2026, 11, 10),
        ),
        counterparty: debt.counterparty,
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.homeExpenses).get(), isEmpty);
    expect(await database.select(database.debtPayments).get(), isEmpty);
  });
}
