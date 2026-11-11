import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [HomeExpenses, WorkEntries, WorkHomeTransfers, Debts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bye_pro_finance'));

  /// In-memory constructor for deterministic database tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator migrator) => migrator.createAll(),
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
