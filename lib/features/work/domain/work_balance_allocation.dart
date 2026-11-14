import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';

/// Calculates each month's salary balance independently.
/// Payments are applied only to the month in which they were recorded;
/// no payment is carried backward or forward between months.
final class WorkBalanceAllocation {
  WorkBalanceAllocation._(this._paymentsByMonth, this._remainingByMonth);

  final Map<MonthKey, int> _paymentsByMonth;
  final Map<MonthKey, int> _remainingByMonth;

  int paymentsFor(MonthKey month) => _paymentsByMonth[month] ?? 0;

  int remainingFor(MonthKey month) => _remainingByMonth[month] ?? 0;

  int outstandingFor(MonthKey month) {
    final remaining = remainingFor(month);
    return remaining > 0 ? remaining : 0;
  }

  int outstandingBefore(MonthKey month) => 0;

  int outstandingThrough(MonthKey month) => outstandingFor(month);

  factory WorkBalanceAllocation.calculate(Iterable<WorkEntry> entries) {
    final salaryByMonth = <MonthKey, int>{};
    final advancesByMonth = <MonthKey, int>{};
    final paymentsByMonth = <MonthKey, int>{};

    for (final entry in entries) {
      switch (entry.kind) {
        case WorkEntryKind.salary:
          salaryByMonth.update(
            entry.dueMonth,
            (value) => value + entry.amount.minorUnits,
            ifAbsent: () => entry.amount.minorUnits,
          );
        case WorkEntryKind.advance:
          advancesByMonth.update(
            entry.dueMonth,
            (value) => value + entry.amount.minorUnits,
            ifAbsent: () => entry.amount.minorUnits,
          );
        case WorkEntryKind.salaryPayment:
          paymentsByMonth.update(
            entry.dueMonth,
            (value) => value + entry.amount.minorUnits,
            ifAbsent: () => entry.amount.minorUnits,
          );
      }
    }

    final months = <MonthKey>{
      ...salaryByMonth.keys,
      ...advancesByMonth.keys,
      ...paymentsByMonth.keys,
    };
    final remainingByMonth = <MonthKey, int>{
      for (final month in months)
        month: (salaryByMonth[month] ?? 0) -
            (advancesByMonth[month] ?? 0) -
            (paymentsByMonth[month] ?? 0),
    };

    return WorkBalanceAllocation._(
      Map.unmodifiable(paymentsByMonth),
      Map.unmodifiable(remainingByMonth),
    );
  }
}
