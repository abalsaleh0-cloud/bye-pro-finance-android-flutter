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

  Future<String?> readSetting(String key) async {
    final rows = await customSelect(
      'SELECT setting_value FROM app_settings WHERE setting_key = ?',
      variables: [Variable.withString(key)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('setting_value');
  }

  Future<void> writeSetting(String key, String value) async {
    await customStatement(
      'INSERT OR REPLACE INTO app_settings (setting_key, setting_value) VALUES (?, ?)',
      [key, value],
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(debtPayments);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement("CREATE TABLE IF NOT EXISTS home_bills (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN ('monthly', 'rent')), amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0), due_year INTEGER NOT NULL, due_month INTEGER NOT NULL CHECK (due_month BETWEEN 1 AND 12), note TEXT)");
      await customStatement('CREATE TABLE IF NOT EXISTS home_bill_payments (id TEXT PRIMARY KEY NOT NULL, bill_id TEXT NOT NULL REFERENCES home_bills(id) ON DELETE CASCADE, amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0), paid_at_epoch_millis INTEGER NOT NULL, note TEXT)');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS app_settings (
          setting_key TEXT PRIMARY KEY NOT NULL,
          setting_value TEXT NOT NULL
        )
      ''');
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
