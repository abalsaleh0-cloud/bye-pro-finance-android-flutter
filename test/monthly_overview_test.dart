import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/dashboard/domain/monthly_overview.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final month = MonthKey(year: 2026, month: 11);

  test('calculates month-scoped work, home and transfer totals', () {
    final overview = MonthlyOverview.calculate(
      month: month,
      workEntries: [
        WorkEntry(
          id: 'salary',
          kind: WorkEntryKind.salary,
          amount: Money.fromMinorUnits(100000),
          dueMonth: month,
          recordedAt: DateTime(2026, 11, 1),
        ),
        WorkEntry(
          id: 'advance',
          kind: WorkEntryKind.advance,
          amount: Money.fromMinorUnits(10000),
          dueMonth: month,
          recordedAt: DateTime(2026, 11, 2),
        ),
        WorkEntry(
          id: 'old-payment',
          kind: WorkEntryKind.salaryPayment,
          amount: Money.fromMinorUnits(5000),
          dueMonth: MonthKey(year: 2026, month: 10),
          recordedAt: DateTime(2026, 10, 2),
        ),
      ],
      homeExpenses: [
        HomeExpense(
          id: 'home-current',
          amount: Money.fromMinorUnits(2500),
          categoryId: 'food',
          expenseDate: DateTime(2026, 11, 3),
          dueMonth: month,
        ),
        HomeExpense(
          id: 'home-next',
          amount: Money.fromMinorUnits(9000),
          categoryId: 'rent',
          expenseDate: DateTime(2026, 12, 1),
          dueMonth: MonthKey(year: 2026, month: 12),
        ),
      ],
      transfers: [
        WorkHomeTransfer(
          id: 'transfer-current',
          amount: Money.fromMinorUnits(7000),
          transferredAt: DateTime(2026, 11, 5),
        ),
        WorkHomeTransfer(
          id: 'transfer-old',
          amount: Money.fromMinorUnits(8000),
          transferredAt: DateTime(2026, 10, 5),
        ),
      ],
      debts: const [],
    );

    expect(overview.salary.minorUnits, 100000);
    expect(overview.advances.minorUnits, 10000);
    expect(overview.payments.minorUnits, 0);
    expect(overview.workRecordsTotal.minorUnits, 110000);
    expect(overview.workRemainingMinorUnits, 3000);
    expect(overview.homeExpenses.minorUnits, 2500);
    expect(overview.transfers.minorUnits, 7000);
  });

  test('keeps partial salary payments within their own month', () {
    final october = MonthKey(year: 2026, month: 10);
    final november = MonthKey(year: 2026, month: 11);
    final entries = [
      WorkEntry(
        id: 'october-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(3000),
        dueMonth: october,
        recordedAt: DateTime(2026, 10, 1),
      ),
      WorkEntry(
        id: 'november-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(2000),
        dueMonth: november,
        recordedAt: DateTime(2026, 11, 1),
      ),
      WorkEntry(
        id: 'october-receipt',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(1000),
        dueMonth: october,
        recordedAt: DateTime(2026, 10, 10),
      ),
      WorkEntry(
        id: 'november-receipt',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: november,
        recordedAt: DateTime(2026, 11, 10),
      ),
    ];

    final allocation = WorkBalanceAllocation.calculate(entries);
    expect(allocation.paymentsFor(october), 1000);
    expect(allocation.paymentsFor(november), 500);

    final octoberOverview = MonthlyOverview.calculate(
      month: october,
      workEntries: entries,
      homeExpenses: const [],
      transfers: const [],
      debts: const [],
    );
    final novemberOverview = MonthlyOverview.calculate(
      month: november,
      workEntries: entries,
      homeExpenses: const [],
      transfers: const [],
      debts: const [],
    );
    expect(octoberOverview.payments.minorUnits, 1000);
    expect(novemberOverview.payments.minorUnits, 500);
    expect(octoberOverview.salaryPaymentsApplied.minorUnits, 1000);
    expect(novemberOverview.salaryPaymentsApplied.minorUnits, 500);
    expect(octoberOverview.workRemainingMinorUnits, 1000);
    expect(novemberOverview.workRemainingMinorUnits, 500);
    expect(novemberOverview.previousWorkOutstandingMinorUnits, 0);
    expect(novemberOverview.totalWorkOutstandingMinorUnits, 1500);
  });

  test('preserves historical payments against their original salary month', () {
    final september = MonthKey(year: 2026, month: 9);
    final october = MonthKey(year: 2026, month: 10);
    final november = MonthKey(year: 2026, month: 11);
    final allocation = WorkBalanceAllocation.calculate([
      WorkEntry(
        id: 'september-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(500),
        dueMonth: september,
        recordedAt: DateTime(2026, 9, 1),
      ),
      WorkEntry(
        id: 'october-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(300),
        dueMonth: october,
        recordedAt: DateTime(2026, 10, 1),
      ),
      WorkEntry(
        id: 'historical-october-payment',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(100),
        dueMonth: october,
        recordedAt: DateTime(2026, 10, 15),
      ),
      WorkEntry(
        id: 'new-november-payment',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(200),
        dueMonth: november,
        recordedAt: DateTime(2026, 11, 15),
      ),
    ]);

    expect(allocation.paymentsFor(september), 0);
    expect(allocation.paymentsFor(october), 100);
    expect(allocation.outstandingFor(september), 500);
    expect(allocation.outstandingFor(october), 200);
  });

  test('keeps a payment in its own month without splitting across months', () {
    final october = MonthKey(year: 2026, month: 10);
    final november = MonthKey(year: 2026, month: 11);
    final allocation = WorkBalanceAllocation.calculate([
      WorkEntry(
        id: 'october-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(300),
        dueMonth: october,
        recordedAt: DateTime(2026, 10, 1),
      ),
      WorkEntry(
        id: 'november-salary',
        kind: WorkEntryKind.salary,
        amount: Money.fromMinorUnits(400),
        dueMonth: november,
        recordedAt: DateTime(2026, 11, 1),
      ),
      WorkEntry(
        id: 'november-payment',
        kind: WorkEntryKind.salaryPayment,
        amount: Money.fromMinorUnits(500),
        dueMonth: november,
        recordedAt: DateTime(2026, 11, 15),
      ),
    ]);

    expect(allocation.paymentsFor(october), 0);
    expect(allocation.paymentsFor(november), 500);
  });

  test('reports a negative balance for historical transfers above received cash', () {
    final overview = MonthlyOverview.calculate(
      month: month,
      workEntries: [
        WorkEntry(
          id: 'salary',
          kind: WorkEntryKind.salary,
          amount: Money.fromMinorUnits(500),
          dueMonth: month,
          recordedAt: DateTime(2026, 11, 1),
        ),
        WorkEntry(
          id: 'advance',
          kind: WorkEntryKind.advance,
          amount: Money.fromMinorUnits(300),
          dueMonth: month,
          recordedAt: DateTime(2026, 11, 2),
        ),
        WorkEntry(
          id: 'payment',
          kind: WorkEntryKind.salaryPayment,
          amount: Money.fromMinorUnits(250),
          dueMonth: month,
          recordedAt: DateTime(2026, 11, 3),
        ),
      ],
      homeExpenses: const [],
      transfers: [
        WorkHomeTransfer(
          id: 'historical-over-transfer',
          amount: Money.fromMinorUnits(600),
          transferredAt: DateTime(2026, 11, 4),
        ),
      ],
      debts: const [],
    );

    expect(overview.workRemainingMinorUnits, -50);
  });

  test('separates outstanding creditor and debtor balances', () {
    final overview = MonthlyOverview.calculate(
      month: month,
      workEntries: const [],
      homeExpenses: const [],
      transfers: const [],
      debts: [
        DebtEntry(
          id: 'owed-to-user',
          direction: DebtDirection.creditor,
          originalAmount: Money.fromMinorUnits(10000),
          outstandingAmount: Money.fromMinorUnits(4000),
          dueMonth: month,
          createdAt: DateTime(2026, 11, 1),
          counterparty: 'A',
        ),
        DebtEntry(
          id: 'user-owes',
          direction: DebtDirection.debtor,
          originalAmount: Money.fromMinorUnits(8000),
          outstandingAmount: Money.fromMinorUnits(3000),
          dueMonth: month,
          createdAt: DateTime(2026, 11, 2),
          counterparty: 'B',
        ),
        DebtEntry(
          id: 'settled',
          direction: DebtDirection.debtor,
          originalAmount: Money.fromMinorUnits(500),
          outstandingAmount: Money.zero,
          dueMonth: month,
          createdAt: DateTime(2026, 11, 3),
          counterparty: 'C',
        ),
      ],
    );

    expect(overview.creditorBalance.minorUnits, 4000);
    expect(overview.debtorBalance.minorUnits, 3000);
  });
}
