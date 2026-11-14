import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show
        AppDatabase,
        WorkEntriesCompanion,
        WorkEntryRow,
        WorkHomeTransferRow,
        WorkHomeTransfersCompanion;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';

final class InsufficientWorkBalanceException implements Exception {
  const InsufficientWorkBalanceException({
    required this.availableMinorUnits,
    required this.requestedMinorUnits,
  });

  final int availableMinorUnits;
  final int requestedMinorUnits;
}

final class TransferWouldOverdrawHomeException implements Exception {
  const TransferWouldOverdrawHomeException({
    required this.remainingTransfersMinorUnits,
    required this.homeCommittedMinorUnits,
  });

  final int remainingTransfersMinorUnits;
  final int homeCommittedMinorUnits;
}

final class WorkRepository {
  const WorkRepository(this._database);

  final AppDatabase _database;

  Stream<List<WorkEntry>> watchEntries() {
    return (_database.select(_database.workEntries)
          ..orderBy([(row) => OrderingTerm.desc(row.recordedAtEpochMillis)]))
        .watch()
        .map((rows) {
          final entries = rows.map(_entryToDomain).toList();
          entries.sort((a, b) {
            final categoryOrder = a.kind.index.compareTo(b.kind.index);
            return categoryOrder != 0
                ? categoryOrder
                : b.recordedAt.compareTo(a.recordedAt);
          });
          return entries.toList(growable: false);
        });
  }

  Future<void> saveEntry(WorkEntry entry) {
    return _database.transaction(() async {
      final entries = await _database.select(_database.workEntries).get();
      final previous = entries.where((row) => row.id == entry.id).firstOrNull;
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final affectedMonths = <String>{
        if (previous != null && _isCashReceived(previous.kind))
          '${previous.dueYear}-${previous.dueMonth.toString().padLeft(2, '0')}',
        if (_isCashReceived(entry.kind.name)) '${entry.dueMonth.year}-${entry.dueMonth.month.toString().padLeft(2, '0')}',
      };
      for (final monthKey in affectedMonths) {
        final parts = monthKey.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        var receivedAfter = 0;
        for (final row in entries) {
          if (row.id == entry.id || !_isCashReceived(row.kind)) continue;
          if (row.dueYear == year && row.dueMonth == month) {
            receivedAfter += row.amountMinorUnits;
          }
        }
        if (_isCashReceived(entry.kind.name) &&
            entry.dueMonth.year == year &&
            entry.dueMonth.month == month) {
          receivedAfter += entry.amount.minorUnits;
        }
        final receivedBefore = _receivedCashForMonth(entries, year, month);
        final transferred = _transferTotalForMonth(transfers, year, month);
        if (receivedAfter < transferred && receivedAfter < receivedBefore) {
          throw InsufficientWorkBalanceException(
            availableMinorUnits: receivedBefore - transferred,
            requestedMinorUnits: receivedAfter - receivedBefore,
          );
        }
      }

      await _database.into(_database.workEntries).insertOnConflictUpdate(
        WorkEntriesCompanion.insert(
          id: entry.id,
          // Keep the persisted database value stable for existing installations.
          // Both legacy and newly saved salary payments are read as the
          // unified salaryPayment domain kind by _entryToDomain.
          kind: entry.kind == WorkEntryKind.salaryPayment
              ? 'payment'
              : entry.kind.name,
          amountMinorUnits: entry.amount.minorUnits,
          dueYear: entry.dueMonth.year,
          dueMonth: entry.dueMonth.month,
          recordedAtEpochMillis: entry.recordedAt.millisecondsSinceEpoch,
          note: Value(entry.note),
        ),
      );
    });
  }

  Future<void> deleteEntry(String id) {
    return _database.transaction(() async {
      final entries = await _database.select(_database.workEntries).get();
      final target = entries.where((row) => row.id == id).firstOrNull;
      if (target == null) return;
      final transfers = await _database.select(_database.workHomeTransfers).get();
      if (_isCashReceived(target.kind)) {
        final receivedAfter = _receivedCashForMonth(entries, target.dueYear, target.dueMonth) -
            target.amountMinorUnits;
        final transferred = _transferTotalForMonth(transfers, target.dueYear, target.dueMonth);
        if (receivedAfter < transferred) {
          throw InsufficientWorkBalanceException(
            availableMinorUnits: receivedAfter - transferred,
            requestedMinorUnits: 0,
          );
        }
      }
      await (_database.delete(_database.workEntries)
            ..where((row) => row.id.equals(id)))
          .go();
    });
  }

  Stream<List<WorkHomeTransfer>> watchTransfers() {
    return (_database.select(_database.workHomeTransfers)
          ..orderBy([(row) => OrderingTerm.desc(row.transferredAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_transferToDomain).toList(growable: false));
  }

  Future<void> saveTransfer(WorkHomeTransfer transfer) {
    return _database.transaction(() async {
      final entries = await _database.select(_database.workEntries).get();
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final previous = transfers.where((row) => row.id == transfer.id).firstOrNull;
      final previousAmount = previous?.amountMinorUnits ?? 0;
      final targetDate = transfer.transferredAt.toLocal();
      final year = targetDate.year;
      final month = targetDate.month;
      final transferredBefore = _transferTotalForMonth(transfers, year, month);
      final previousInTargetMonth = previous != null &&
          DateTime.fromMillisecondsSinceEpoch(previous.transferredAtEpochMillis).toLocal().year == year &&
          DateTime.fromMillisecondsSinceEpoch(previous.transferredAtEpochMillis).toLocal().month == month
          ? previousAmount
          : 0;
      final transferredAfter = transferredBefore - previousInTargetMonth +
          transfer.amount.minorUnits;
      final received = _receivedCashForMonth(entries, year, month);
      // Keep legacy transfers untouched, but never allow a new or increased
      // transfer to exceed cash actually received in that calendar month.
      if (transferredAfter > received && transferredAfter > transferredBefore) {
        throw InsufficientWorkBalanceException(
          availableMinorUnits: received - transferredBefore,
          requestedMinorUnits: transfer.amount.minorUnits,
        );
      }
      // If an existing transfer is moved to another month, protect the
      // obligations in its original month as well as those in the target.
      if (previous != null) {
        final previousDate = DateTime.fromMillisecondsSinceEpoch(
          previous.transferredAtEpochMillis,
        ).toLocal();
        final previousYear = previousDate.year;
        final previousMonth = previousDate.month;
        if (previousYear != year || previousMonth != month) {
          final remainingPreviousMonth = _transferTotalForMonth(
                transfers,
                previousYear,
                previousMonth,
              ) -
              previousAmount;
          final previousCommitted = await _homeCommittedAmount(
            previousYear,
            previousMonth,
          );
          if (remainingPreviousMonth < previousCommitted) {
            throw TransferWouldOverdrawHomeException(
              remainingTransfersMinorUnits: remainingPreviousMonth,
              homeCommittedMinorUnits: previousCommitted,
            );
          }
        }
      }

      final committed = await _homeCommittedAmount(year, month);
      if (transferredAfter < committed) {
        throw TransferWouldOverdrawHomeException(
          remainingTransfersMinorUnits: transferredAfter,
          homeCommittedMinorUnits: committed,
        );
      }
      await _database.into(_database.workHomeTransfers).insertOnConflictUpdate(
        WorkHomeTransfersCompanion.insert(
          id: transfer.id,
          amountMinorUnits: transfer.amount.minorUnits,
          transferredAtEpochMillis:
              transfer.transferredAt.millisecondsSinceEpoch,
          note: Value(transfer.note),
        ),
      );
    });
  }

  Future<void> deleteTransfer(String id) {
    return _database.transaction(() async {
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final target = transfers.where((row) => row.id == id).firstOrNull;
      if (target == null) return;
      final transferDate = DateTime.fromMillisecondsSinceEpoch(target.transferredAtEpochMillis).toLocal();
      final transferredAfter = _transferTotalForMonth(
            transfers,
            transferDate.year,
            transferDate.month,
          ) -
          target.amountMinorUnits;
      final committed = await _homeCommittedAmount(transferDate.year, transferDate.month);
      if (transferredAfter < committed) {
        throw TransferWouldOverdrawHomeException(
          remainingTransfersMinorUnits: transferredAfter,
          homeCommittedMinorUnits: committed,
        );
      }
      await (_database.delete(_database.workHomeTransfers)
            ..where((row) => row.id.equals(id)))
          .go();
    });
  }

  Future<int> _homeCommittedAmount(int year, int month) async {
    final expenseRows = await _database.select(_database.homeExpenses).get();
    final expenses = expenseRows.where((row) {
      final date = DateTime.fromMillisecondsSinceEpoch(row.expenseDateEpochMillis).toLocal();
      return date.year == year && date.month == month;
    }).fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
    final monthKey = MonthKey(year: year, month: month);
    final outstandingBills = await HomeBillRepository(
      _database,
    ).outstandingForMonth(monthKey);
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final finish = DateTime(year, month + 1).millisecondsSinceEpoch;
    final paymentRows = await _database.customSelect(
      'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?',
      variables: [Variable.withInt(start), Variable.withInt(finish)],
    ).get();
    return expenses +
        paymentRows.single.read<int>('total') +
        outstandingBills;
  }

  int _receivedCashForMonth(List<WorkEntryRow> entries, int year, int month) =>
      entries.where((row) =>
        _isCashReceived(row.kind) && row.dueYear == year && row.dueMonth == month,
      ).fold(0, (sum, row) => sum + row.amountMinorUnits);

  int _transferTotalForMonth(List<WorkHomeTransferRow> transfers, int year, int month) =>
      transfers.where((row) {
        final date = DateTime.fromMillisecondsSinceEpoch(row.transferredAtEpochMillis).toLocal();
        return date.year == year && date.month == month;
      }).fold(0, (sum, row) => sum + row.amountMinorUnits);

  bool _isCashReceived(String kind) =>
      kind == WorkEntryKind.advance.name ||
      kind == 'payment' ||
      kind == WorkEntryKind.salaryPayment.name;

  WorkEntry _entryToDomain(WorkEntryRow row) => WorkEntry(
    id: row.id,
    // Older records stored `payment`; expose it through the current unified
    // salary-payment category without rewriting the persisted record eagerly.
    kind: row.kind == 'payment'
        ? WorkEntryKind.salaryPayment
        : WorkEntryKind.values.byName(row.kind),
    amount: Money.fromMinorUnits(row.amountMinorUnits),
    dueMonth: MonthKey(year: row.dueYear, month: row.dueMonth),
    recordedAt: DateTime.fromMillisecondsSinceEpoch(row.recordedAtEpochMillis),
    note: row.note,
  );

  WorkHomeTransfer _transferToDomain(WorkHomeTransferRow row) =>
      WorkHomeTransfer(
        id: row.id,
        amount: Money.fromMinorUnits(row.amountMinorUnits),
        transferredAt: DateTime.fromMillisecondsSinceEpoch(
          row.transferredAtEpochMillis,
        ),
        note: row.note,
      );
}
