import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show AppDatabase, DebtsCompanion, DebtRow;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';

final class DebtRepository {
  const DebtRepository(this._database);

  final AppDatabase _database;

  Stream<List<DebtEntry>> watchAll() {
    return (_database.select(_database.debts)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  Future<void> save(DebtEntry debt) {
    return _database.into(_database.debts).insertOnConflictUpdate(
          DebtsCompanion.insert(
            id: debt.id,
            direction: debt.direction.name,
            originalAmountMinorUnits: debt.originalAmount.minorUnits,
            outstandingAmountMinorUnits: debt.outstandingAmount.minorUnits,
            dueYear: debt.dueMonth.year,
            dueMonth: debt.dueMonth.month,
            createdAtEpochMillis: debt.createdAt.millisecondsSinceEpoch,
            counterparty: debt.counterparty,
            note: Value(debt.note),
          ),
        );
  }

  Future<void> delete(String id) {
    return (_database.delete(_database.debts)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  DebtEntry _toDomain(DebtRow row) => DebtEntry(
        id: row.id,
        direction: DebtDirection.values.byName(row.direction),
        originalAmount: Money.fromMinorUnits(row.originalAmountMinorUnits),
        outstandingAmount: Money.fromMinorUnits(row.outstandingAmountMinorUnits),
        dueMonth: MonthKey(year: row.dueYear, month: row.dueMonth),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtEpochMillis),
        counterparty: row.counterparty,
        note: row.note,
      );
}
