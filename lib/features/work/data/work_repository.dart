import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';

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
    return _database.into(_database.workEntries).insertOnConflictUpdate(
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
  }

  Future<void> deleteEntry(String id) {
    return (_database.delete(_database.workEntries)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  Stream<List<WorkHomeTransfer>> watchTransfers() {
    return (_database.select(_database.workHomeTransfers)
          ..orderBy([(row) => OrderingTerm.desc(row.transferredAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_transferToDomain).toList(growable: false));
  }

  Future<void> saveTransfer(WorkHomeTransfer transfer) {
    return _database
        .into(_database.workHomeTransfers)
        .insertOnConflictUpdate(
          WorkHomeTransfersCompanion.insert(
            id: transfer.id,
            amountMinorUnits: transfer.amount.minorUnits,
            transferredAtEpochMillis:
                transfer.transferredAt.millisecondsSinceEpoch,
            note: Value(transfer.note),
          ),
        );
  }

  WorkEntry _entryToDomain(WorkEntryRow row) => WorkEntry(
        id: row.id,
        kind: WorkEntryKind.values.byName(row.kind),
        amount: Money.fromMinorUnits(row.amountMinorUnits),
        dueMonth: MonthKey(year: row.dueYear, month: row.dueMonth),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          row.recordedAtEpochMillis,
        ),
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
