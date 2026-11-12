import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';

/// Read-only totals for one calendar month.
final class MonthlyOverview {
  const MonthlyOverview({
    required this.month,
    required this.salary,
    required this.advances,
    required this.payments,
    required this.homeExpenses,
    required this.transfers,
    required this.creditorBalance,
    required this.debtorBalance,
  });

  final MonthKey month;
  final Money salary;
  final Money advances;
  final Money payments;
  final Money homeExpenses;
  final Money transfers;
  final Money creditorBalance;
  final Money debtorBalance;

  Money get workRecordsTotal => salary + advances + payments;

  /// Remaining work amount; a negative value represents an overdrawn balance.
  int get workRemainingMinorUnits =>
      salary.minorUnits -
      advances.minorUnits -
      payments.minorUnits -
      transfers.minorUnits;

  factory MonthlyOverview.calculate({
    required MonthKey month,
    required Iterable<WorkEntry> workEntries,
    required Iterable<HomeExpense> homeExpenses,
    required Iterable<WorkHomeTransfer> transfers,
    required Iterable<DebtEntry> debts,
  }) {
    var salary = Money.zero;
    var advances = Money.zero;
    final entries = workEntries.toList(growable: false);
    var payments = Money.zero;
    for (final entry in entries.where((entry) => entry.dueMonth == month)) {
      switch (entry.kind) {
        case WorkEntryKind.salary:
          salary += entry.amount;
          break;
        case WorkEntryKind.advance:
          advances += entry.amount;
          break;
        case WorkEntryKind.payment:
          break;
      }
    }

    payments = Money.fromMinorUnits(
      WorkBalanceAllocation.calculate(entries).paymentsFor(month),
    );

    var homeTotal = Money.zero;
    for (final expense in homeExpenses.where(
      (item) => item.dueMonth == month,
    )) {
      homeTotal += expense.amount;
    }

    var transferTotal = Money.zero;
    for (final transfer in transfers) {
      final date = transfer.transferredAt.toLocal();
      if (date.year == month.year && date.month == month.month) {
        transferTotal += transfer.amount;
      }
    }

    var creditor = Money.zero;
    var debtor = Money.zero;
    for (final debt in debts) {
      if (debt.direction == DebtDirection.creditor) {
        creditor += debt.outstandingAmount;
      } else {
        debtor += debt.outstandingAmount;
      }
    }

    return MonthlyOverview(
      month: month,
      salary: salary,
      advances: advances,
      payments: payments,
      homeExpenses: homeTotal,
      transfers: transferTotal,
      creditorBalance: creditor,
      debtorBalance: debtor,
    );
  }
}
