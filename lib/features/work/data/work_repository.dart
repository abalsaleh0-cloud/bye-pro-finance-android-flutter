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
        .map((rows) => rows.map(_entryToDomain).toList(growable: false));
  }

  Future<void> saveEntry(WorkEntry entry) {
    return _database.transaction(() async {
      final entries = await _database.select(_database.workEntries).get();
      final previous = entries.where((row) => row.id == entry.id).firstOrNull;
      final receivedBefore = _receivedCash(entries);
      final previousCash = previous != null && _isCashReceived(previous.kind)
          ? previous.amountMinorUnits
          : 0;
      final newCash = _isCashReceived(entry.kind) ? entry.amount.minorUnits : 0;
      final receivedAfter = receivedBefore - previousCash + newCash;
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final transferredTotal = transfers.fold<int>(
        0,
        (sum, row) => sum + row.amountMinorUnits,
      );

      // Older installations may contain transfers without recorded salary
      // receipts. Preserve those historical records until the user records
      // work income; once work entries exist, enforce the real cash limit.
      if (entries.isNotEmpty && receivedAfter < transferredTotal) {
        throw InsufficientWorkBalanceException(
          availableMinorUnits: receivedBefore - previousCash - transferredTotal,
          requestedMinorUnits: newCash,
        );
      }

      await _database.into(_database.workEntries).insertOnConflictUpdate(
        WorkEntriesCompanion.insert(
          id: entry.id,
          kind: entry.kind.name,
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
      final receivedAfter = _receivedCash(entries) -
          (_isCashReceived(target.kind) ? target.amountMinorUnits : 0);
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final transferredTotal = transfers.fold<int>(
        0,
        (sum, row) => sum + row.amountMinorUnits,
      );
      if (entries.length > 1 && receivedAfter < transferredTotal) {
        throw InsufficientWorkBalanceException(
          availableMinorUnits: receivedAfter - transferredTotal,
          requestedMinorUnits: 0,
        );
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
      final transferredAfter = transfers.fold<int>(
            0,
            (sum, row) => sum + row.amountMinorUnits,
          ) -
          previousAmount +
          transfer.amount.minorUnits;
      if (entries.isNotEmpty) {
        final received = _receivedCash(entries);
        if (transferredAfter > received) {
          throw InsufficientWorkBalanceException(
            availableMinorUnits: received -
                (transferredAfter - transfer.amount.minorUnits),
            requestedMinorUnits: transfer.amount.minorUnits,
          );
        }
      }
      final committed = await _homeCommittedAmount();
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
      final transferredAfter = transfers.fold<int>(
            0,
            (sum, row) => sum + row.amountMinorUnits,
          ) -
          target.amountMinorUnits;
      final committed = await _homeCommittedAmount();
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

  Future<int> _homeCommittedAmount() async {
    final expenseRows = await _database.select(_database.homeExpenses).get();
    final expenses = expenseRows.fold<int>(
      0,
      (sum, row) => sum + row.amountMinorUnits,
    );
    final tableRows = await _database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'home_bill_payments'",
    ).get();
    if (tableRows.isEmpty) return expenses;
    final paymentRows = await _database.customSelect(
      'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments',
    ).get();
    return expenses + paymentRows.single.read<int>('total');
  }

  int _receivedCash(List<WorkEntryRow> entries) => entries
      .where((row) => _isCashReceived(row.kind))
      .fold(0, (sum, row) => sum + row.amountMinorUnits);

  bool _isCashReceived(String kind) =>
      kind == WorkEntryKind.advance.name ||
      kind == WorkEntryKind.payment.name ||
      kind == WorkEntryKind.salaryPayment.name;

  WorkEntry _entryToDomain(WorkEntryRow row) => WorkEntry(
    id: row.id,
    kind: WorkEntryKind.values.byName(row.kind),
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
