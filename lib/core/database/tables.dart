import 'package:drift/drift.dart';

@DataClassName('HomeExpenseRow')
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

@DataClassName('WorkEntryRow')
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

@DataClassName('WorkHomeTransferRow')
class WorkHomeTransfers extends Table {
  TextColumn get id => text()();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get transferredAtEpochMillis => integer()();
  TextColumn get note => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DebtRow')
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
