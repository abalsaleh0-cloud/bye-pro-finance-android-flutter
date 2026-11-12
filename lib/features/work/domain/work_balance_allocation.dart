import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';

/// Allocates received salary payments to the oldest eligible salary month first.
final class WorkBalanceAllocation {
  WorkBalanceAllocation._(
    this._paymentsBySalaryMonth,
    this._remainingByMonth,
  );

  final Map<MonthKey, int> _paymentsBySalaryMonth;
  final Map<MonthKey, int> _remainingByMonth;

  int paymentsFor(MonthKey month) => _paymentsBySalaryMonth[month] ?? 0;

  int remainingFor(MonthKey month) => _remainingByMonth[month] ?? 0;

  int outstandingBefore(MonthKey month) => _remainingByMonth.entries
      .where((entry) => entry.key.compareTo(month) < 0 && entry.value > 0)
      .fold(0, (total, entry) => total + entry.value);

  int outstandingThrough(MonthKey month) => _remainingByMonth.entries
      .where((entry) => entry.key.compareTo(month) <= 0 && entry.value > 0)
      .fold(0, (total, entry) => total + entry.value);

  factory WorkBalanceAllocation.calculate(Iterable<WorkEntry> entries) {
    final allEntries = entries.toList(growable: false);
    final salaryByMonth = <MonthKey, int>{};
    final advancesByMonth = <MonthKey, int>{};

    for (final entry in allEntries) {
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
        case WorkEntryKind.payment:
          break;
      }
    }

    final remainingByMonth = <MonthKey, int>{
      for (final month in {...salaryByMonth.keys, ...advancesByMonth.keys})
        month: (salaryByMonth[month] ?? 0) - (advancesByMonth[month] ?? 0),
    };
    final paymentsByMonth = <MonthKey, int>{};
    final payments = allEntries
        .where((entry) => entry.kind == WorkEntryKind.payment)
        .toList()
      ..sort((a, b) {
        final monthOrder = a.dueMonth.compareTo(b.dueMonth);
        if (monthOrder != 0) return monthOrder;
        final dateOrder = a.recordedAt.compareTo(b.recordedAt);
        return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
      });

    for (final payment in payments) {
      var unallocated = payment.amount.minorUnits;
      final eligibleMonths = remainingByMonth.keys
          .where((month) => month.compareTo(payment.dueMonth) <= 0)
          .toList()
        ..sort();

      for (final month in eligibleMonths) {
        if (unallocated == 0) break;
        final outstanding = remainingByMonth[month] ?? 0;
        if (outstanding <= 0) continue;
        final allocated = outstanding < unallocated ? outstanding : unallocated;
        remainingByMonth[month] = outstanding - allocated;
        paymentsByMonth.update(
          month,
          (value) => value + allocated,
          ifAbsent: () => allocated,
        );
        unallocated -= allocated;
      }

      // Preserve any excess as a negative balance in the latest eligible month.
      // If no salary month exists yet, keep it against the payment's own month.
      if (unallocated > 0) {
        final targetMonth = eligibleMonths.isEmpty
            ? payment.dueMonth
            : eligibleMonths.last;
        remainingByMonth.update(
          targetMonth,
          (value) => value - unallocated,
          ifAbsent: () => -unallocated,
        );
        paymentsByMonth.update(
          targetMonth,
          (value) => value + unallocated,
          ifAbsent: () => unallocated,
        );
      }
    }

    return WorkBalanceAllocation._(
      Map.unmodifiable(paymentsByMonth),
      Map.unmodifiable(remainingByMonth),
    );
  }
}
