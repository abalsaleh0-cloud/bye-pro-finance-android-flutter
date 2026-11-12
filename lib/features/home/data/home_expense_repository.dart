import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show AppDatabase, HomeExpensesCompanion, HomeExpenseRow;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';

final class InsufficientHomeBalanceException implements Exception {
  const InsufficientHomeBalanceException({
    required this.availableMinorUnits,
    required this.requestedMinorUnits,
  });

  final int availableMinorUnits;
  final int requestedMinorUnits;
}

final class HomeExpenseRepository {
  const HomeExpenseRepository(this._database);

  final AppDatabase _database;

  Stream<List<HomeExpense>> watchAll() {
    return (_database.select(_database.homeExpenses)
          ..orderBy([(row) => OrderingTerm.desc(row.expenseDateEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  /// Saves an expense only when cumulative work transfers cover all home
  /// expenses. The balance check and write share one transaction.
  Future<void> save(HomeExpense expense) {
    return _database.transaction(() async {
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final expenses = await _database.select(_database.homeExpenses).get();
      final previous = expenses.where((row) => row.id == expense.id);
      final previousAmount = previous.isEmpty
          ? 0
          : previous.first.amountMinorUnits;
      final transferredTotal = transfers.fold<int>(
        0,
        (sum, row) => sum + row.amountMinorUnits,
      );
      final expenseTotal = expenses.fold<int>(
        0,
        (sum, row) => sum + row.amountMinorUnits,
      );
      final billPaymentRows = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments',
      ).get();
      final billPaymentTotal = billPaymentRows.single.read<int>('total');
      final available =
          transferredTotal - expenseTotal - billPaymentTotal + previousAmount;

      if (expense.amount.minorUnits > available) {
        throw InsufficientHomeBalanceException(
          availableMinorUnits: available,
          requestedMinorUnits: expense.amount.minorUnits,
        );
      }

      await _database
          .into(_database.homeExpenses)
          .insertOnConflictUpdate(
            HomeExpensesCompanion.insert(
              id: expense.id,
              amountMinorUnits: expense.amount.minorUnits,
              categoryId: expense.categoryId,
              expenseDateEpochMillis:
                  expense.expenseDate.millisecondsSinceEpoch,
              dueYear: expense.dueMonth.year,
              dueMonth: expense.dueMonth.month,
              note: Value(expense.note),
            ),
          );
    });
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
