import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show AppDatabase, HomeExpensesCompanion, HomeExpenseRow, DebtPaymentsCompanion, DebtsCompanion;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';

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
    if (expense.categoryId == 'debt_repayment') {
      throw StateError('Debt repayments must be recorded through saveDebtRepayment.');
    }
    return _database.transaction(() async {
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final expenses = await _database.select(_database.homeExpenses).get();
      final previous = expenses.where((row) => row.id == expense.id);
      if (previous.isNotEmpty && previous.first.categoryId == 'debt_repayment') {
        throw StateError('A linked debt repayment cannot be edited as a regular expense.');
      }
      final previousAmount = previous.isEmpty
          ? 0
          : previous.first.amountMinorUnits;
      final expenseDate = expense.expenseDate.toLocal();
      final year = expenseDate.year;
      final month = expenseDate.month;
      final monthStart = DateTime(year, month).millisecondsSinceEpoch;
      final nextMonthStart = DateTime(year, month + 1).millisecondsSinceEpoch;
      final transferredTotal = transfers.where((row) {
        final date = DateTime.fromMillisecondsSinceEpoch(row.transferredAtEpochMillis).toLocal();
        return date.year == year && date.month == month;
      }).fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
      final expenseTotal = expenses.where((row) {
        final date = DateTime.fromMillisecondsSinceEpoch(row.expenseDateEpochMillis).toLocal();
        return date.year == year && date.month == month;
      }).fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
      final previousInMonth = previous.isNotEmpty &&
          DateTime.fromMillisecondsSinceEpoch(previous.first.expenseDateEpochMillis).toLocal().year == year &&
          DateTime.fromMillisecondsSinceEpoch(previous.first.expenseDateEpochMillis).toLocal().month == month
          ? previousAmount
          : 0;
      final billPaymentRows = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?',
        variables: [Variable.withInt(monthStart), Variable.withInt(nextMonthStart)],
      ).get();
      final billPaymentTotal = billPaymentRows.single.read<int>('total');
      final outstandingBills = await HomeBillRepository(
        _database,
      ).outstandingForMonth(MonthKey(year: year, month: month));
      final available = transferredTotal -
          expenseTotal -
          billPaymentTotal -
          outstandingBills +
          previousInMonth;

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


  /// Records a debt repayment as a household outflow and updates the debtor
  /// balance in the same transaction so neither side can be saved alone.
  Future<void> saveDebtRepayment(
    DebtPayment payment, {
    required String counterparty,
  }) async {
    await DebtRepository(_database).getActivity();
    await _database.transaction(() async {
      final debt = await (_database.select(_database.debts)
            ..where((row) => row.id.equals(payment.debtId)))
          .getSingleOrNull();
      if (debt == null) {
        throw StateError('Debt not found: ${payment.debtId}');
      }
      if (debt.direction != 'debtor') {
        throw ArgumentError('Only a debt payable by the user can be settled from home.');
      }
      if (payment.amount.minorUnits > debt.outstandingAmountMinorUnits) {
        throw ArgumentError('Payment exceeds the outstanding debt balance.');
      }

      final date = payment.paidAt.toLocal();
      final year = date.year;
      final month = date.month;
      final monthStart = DateTime(year, month).millisecondsSinceEpoch;
      final nextMonthStart = DateTime(year, month + 1).millisecondsSinceEpoch;
      final transfers = await _database.select(_database.workHomeTransfers).get();
      final expenses = await _database.select(_database.homeExpenses).get();
      final transferredTotal = transfers.where((row) {
        final transferredAt = DateTime.fromMillisecondsSinceEpoch(
          row.transferredAtEpochMillis,
        ).toLocal();
        return transferredAt.year == year && transferredAt.month == month;
      }).fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
      final expenseTotal = expenses.where((row) {
        final expenseDate = DateTime.fromMillisecondsSinceEpoch(
          row.expenseDateEpochMillis,
        ).toLocal();
        return expenseDate.year == year && expenseDate.month == month;
      }).fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
      final billPaymentRows = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total '
        'FROM home_bill_payments '
        'WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?',
        variables: [
          Variable.withInt(monthStart),
          Variable.withInt(nextMonthStart),
        ],
      ).get();
      final billPaymentTotal = billPaymentRows.single.read<int>('total');
      final outstandingBills = await HomeBillRepository(_database)
          .outstandingForMonth(MonthKey(year: year, month: month));
      final available = transferredTotal -
          expenseTotal -
          billPaymentTotal -
          outstandingBills;

      if (payment.amount.minorUnits > available) {
        throw InsufficientHomeBalanceException(
          availableMinorUnits: available,
          requestedMinorUnits: payment.amount.minorUnits,
        );
      }

      final expenseId = 'debt-payment-${payment.id}';
      final expenseNote = counterparty
          + (payment.note == null || payment.note!.trim().isEmpty
              ? ''
              : ' — ${payment.note!.trim()}');
      await _database.into(_database.homeExpenses).insert(
        HomeExpensesCompanion.insert(
          id: expenseId,
          amountMinorUnits: payment.amount.minorUnits,
          categoryId: 'debt_repayment',
          expenseDateEpochMillis: payment.paidAt.millisecondsSinceEpoch,
          dueYear: year,
          dueMonth: month,
          note: Value(expenseNote),
        ),
      );
      await _database.into(_database.debtPayments).insert(
        DebtPaymentsCompanion.insert(
          id: payment.id,
          debtId: payment.debtId,
          amountMinorUnits: payment.amount.minorUnits,
          paidAtEpochMillis: payment.paidAt.millisecondsSinceEpoch,
          note: Value(payment.note),
        ),
      );
      await (_database.update(_database.debts)
            ..where((row) => row.id.equals(payment.debtId)))
          .write(DebtsCompanion(
        outstandingAmountMinorUnits: Value(
          debt.outstandingAmountMinorUnits - payment.amount.minorUnits,
        ),
      ));
      await _database.customStatement(
        'INSERT OR IGNORE INTO debt_activity '
        '(id, debt_id, event_type, direction, counterparty, amount_minor_units, occurred_at_epoch_millis, note) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'home-payment-${payment.id}',
          payment.debtId,
          'payment',
          debt.direction,
          counterparty,
          payment.amount.minorUnits,
          payment.paidAt.millisecondsSinceEpoch,
          payment.note,
        ],
      );
    });
  }


  /// Undo an assistant-recorded debtor settlement, restoring the amount and
  /// removing the matching household outflow atomically.
  Future<void> undoDebtRepayment(String paymentId) async {
    await DebtRepository(_database).getActivity();
    await _database.transaction(() async {
      final payment = await (_database.select(_database.debtPayments)
            ..where((row) => row.id.equals(paymentId)))
          .getSingleOrNull();
      if (payment == null) {
        throw StateError('Debt payment not found: $paymentId');
      }
      final debt = await (_database.select(_database.debts)
            ..where((row) => row.id.equals(payment.debtId)))
          .getSingleOrNull();
      if (debt == null) {
        throw StateError('Debt not found: ${payment.debtId}');
      }

      await (_database.delete(_database.homeExpenses)
            ..where((row) => row.id.equals('debt-payment-$paymentId')))
          .go();
      await (_database.delete(_database.debtPayments)
            ..where((row) => row.id.equals(paymentId)))
          .go();
      await (_database.update(_database.debts)
            ..where((row) => row.id.equals(payment.debtId)))
          .write(DebtsCompanion(
        outstandingAmountMinorUnits: Value(
          debt.outstandingAmountMinorUnits + payment.amountMinorUnits,
        ),
      ));
      await _database.customStatement(
        'INSERT OR IGNORE INTO debt_activity '
        '(id, debt_id, event_type, direction, counterparty, amount_minor_units, occurred_at_epoch_millis, note) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'home-payment-reversed-$paymentId',
          payment.debtId,
          'payment_reversed',
          debt.direction,
          debt.counterparty,
          payment.amountMinorUnits,
          DateTime.now().millisecondsSinceEpoch,
          payment.note,
        ],
      );
    });
  }

  Future<void> delete(String id) async {
    final existing = await (_database.select(_database.homeExpenses)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    if (existing?.categoryId == 'debt_repayment') {
      throw StateError('A linked debt repayment must be reverted through its debt payment.');
    }
    await (_database.delete(_database.homeExpenses)
          ..where((row) => row.id.equals(id)))
        .go();
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
