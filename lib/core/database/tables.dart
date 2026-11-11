import 'package:drift/drift.dart';

/// Home expenses are stored once and assigned to their due month.
class HomeExpenses extends Table {
  TextColumn get id => text()();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get categoryId => text()();
  IntColumn get expenseDateEpochMillis => integer()();
  IntColumn get dueYear => integer()();
  IntColumn get dueMonth => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Work income records. The monthly remainder is derived, never persisted.
class WorkEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get dueYear => integer()();
  IntColumn get dueMonth => integer()();
  IntColumn get recordedAtEpochMillis => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A single row represents a work-to-home transfer on both sides.
class WorkHomeTransfers extends Table {
  TextColumn get id => text()();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get transferredAtEpochMillis => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Outstanding debt is kept as an integer amount in the smallest unit.
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get direction => text()();
  IntColumn get originalAmountMinorUnits => integer()();
  IntColumn get outstandingAmountMinorUnits => integer()();
  IntColumn get dueYear => integer()();
  IntColumn get dueMonth => integer()();
  IntColumn get createdAtEpochMillis => integer()();
  TextColumn get counterparty => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
