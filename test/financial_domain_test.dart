import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores and adds integer minor units', () {
      final first = Money.fromMinorUnits(1250);
      final second = Money.fromMinorUnits(275);

      expect((first + second).minorUnits, 1525);
    });

    test('rejects negative values and subtraction below zero', () {
      expect(() => Money.fromMinorUnits(-1), throwsArgumentError);
      expect(
        () => Money.fromMinorUnits(10) - Money.fromMinorUnits(11),
        throwsArgumentError,
      );
    });
  });

  group('MonthKey', () {
    test('moves to the next month including year rollover', () {
      expect(
        MonthKey(year: 2026, month: 12).next(),
        MonthKey(year: 2027, month: 1),
      );
    });

    test('rejects invalid calendar months', () {
      expect(() => MonthKey(year: 2026, month: 13), throwsArgumentError);
    });
  });

  test('work entries require a positive amount and a due month', () {
    final entry = WorkEntry(
      id: 'work-1',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(5000),
      dueMonth: MonthKey(year: 2026, month: 11),
      recordedAt: DateTime(2026, 11, 11),
    );

    expect(entry.kind, WorkEntryKind.advance);
    expect(entry.dueMonth, MonthKey(year: 2026, month: 11));
    expect(
      () => WorkEntry(
        id: 'work-2',
        kind: WorkEntryKind.salary,
        amount: Money.zero,
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 11),
      ),
      throwsArgumentError,
    );
  });

  test('home expenses require a category and due month', () {
    final expense = HomeExpense(
      id: 'home-1',
      amount: Money.fromMinorUnits(1200),
      categoryId: 'groceries',
      expenseDate: DateTime(2026, 11, 10),
      dueMonth: MonthKey(year: 2026, month: 11),
    );

    expect(expense.amount.minorUnits, 1200);
    expect(expense.dueMonth.month, 11);
  });

  test('debt tracks creditor/debtor direction and settled state', () {
    final debt = DebtEntry(
      id: 'debt-1',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(10000),
      outstandingAmount: Money.fromMinorUnits(2500),
      dueMonth: MonthKey(year: 2026, month: 11),
      createdAt: DateTime(2026, 11, 1),
      counterparty: 'Counterparty',
    );

    expect(debt.direction, DebtDirection.debtor);
    expect(debt.isSettled, isFalse);
    expect(
      () => DebtEntry(
        id: 'debt-2',
        direction: DebtDirection.creditor,
        originalAmount: Money.fromMinorUnits(100),
        outstandingAmount: Money.fromMinorUnits(101),
        dueMonth: MonthKey(year: 2026, month: 11),
        createdAt: DateTime(2026, 11, 1),
        counterparty: 'Counterparty',
      ),
      throwsArgumentError,
    );
  });


  test('work balances do not carry payments or arrears between months', () {
    final allocation = WorkBalanceAllocation.calculate([
      WorkEntry(
        id: 'salary-nov',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(3000),
        dueMonth: MonthKey(year: 2026, month: 11),
        recordedAt: DateTime(2026, 11, 1),
      ),
      WorkEntry(
        id: 'advance-dec',
        kind: WorkEntryKind.advance,
        amount: Money.fromMinorUnits(500),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime(2026, 12, 1),
      ),
      WorkEntry(
        id: 'payment-dec',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(700),
        dueMonth: MonthKey(year: 2026, month: 12),
        recordedAt: DateTime(2026, 12, 5),
      ),
    ]);

    expect(allocation.outstandingFor(MonthKey(year: 2026, month: 11)), 3000);
    expect(allocation.outstandingFor(MonthKey(year: 2026, month: 12)), 0);
    expect(allocation.paymentsFor(MonthKey(year: 2026, month: 11)), 0);
    expect(allocation.paymentsFor(MonthKey(year: 2026, month: 12)), 700);
    expect(allocation.outstandingBefore(MonthKey(year: 2026, month: 12)), 0);
  });

  test('work-to-home transfer is represented as one record', () {
    final transfer = WorkHomeTransfer(
      id: 'transfer-1',
      amount: Money.fromMinorUnits(7500),
      transferredAt: DateTime(2026, 11, 11),
    );

    expect(transfer.amount.minorUnits, 7500);
    expect(transfer.id, 'transfer-1');
  });
}
