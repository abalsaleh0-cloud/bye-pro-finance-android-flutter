import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show AppDatabase, HomeExpensesCompanion, HomeExpenseRow;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';

final class HomeExpenseRepository {
  const HomeExpenseRepository(this._database);

  final AppDatabase _database;

  Stream<List<HomeExpense>> watchAll() {
    return (_database.select(_database.homeExpenses)
          ..orderBy([(row) => OrderingTerm.desc(row.expenseDateEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  Future<void> save(HomeExpense expense) {
    return _database
        .into(_database.homeExpenses)
        .insertOnConflictUpdate(
          HomeExpensesCompanion.insert(
            id: expense.id,
            amountMinorUnits: expense.amount.minorUnits,
            categoryId: expense.categoryId,
            expenseDateEpochMillis: expense.expenseDate.millisecondsSinceEpoch,
            dueYear: expense.dueMonth.year,
            dueMonth: expense.dueMonth.month,
            note: Value(expense.note),
          ),
        );
  }

  Future<void> delete(String id) {
    return (_database.delete(
      _database.homeExpenses,
    )..where((row) => row.id.equals(id))).go();
  }

  HomeExpense _toDomain(HomeExpenseRow row) => HomeExpense(
    id: row.id,
    amount: Money.fromMinorUnits(row.amountMinorUnits),
    categoryId: row.categoryId,
    expenseDate: DateTime.fromMillisecondsSinceEpoch(
      row.expenseDateEpochMillis,
    ),
    dueMonth: MonthKey(year: row.dueYear, month: row.dueMonth),
    note: row.note,
  );
}
