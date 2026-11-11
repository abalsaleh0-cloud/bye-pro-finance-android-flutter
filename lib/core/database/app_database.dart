import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [HomeExpenses, WorkEntries, WorkHomeTransfers, Debts, DebtPayments],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bye_pro_finance'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(migrator.database.debtPayments);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Immutable payment history linked to a debt.
@DataClassName('DebtPaymentRow')
class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get paidAtEpochMillis => integer()();
  TextColumn get note => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}
