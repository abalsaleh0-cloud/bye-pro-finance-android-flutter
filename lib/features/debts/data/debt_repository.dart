import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart'
    show
        AppDatabase,
        DebtPaymentsCompanion,
        DebtPaymentRow,
        DebtsCompanion,
        DebtRow;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';

final class DebtRepository {
  const DebtRepository(this._database);
  final AppDatabase _database;

  Stream<List<DebtEntry>> watchAll() {
    return (_database.select(_database.debts)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  Stream<List<DebtPayment>> watchPayments(String debtId) {
    return (_database.select(_database.debtPayments)
          ..where((row) => row.debtId.equals(debtId))
          ..orderBy([(row) => OrderingTerm.desc(row.paidAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_paymentToDomain).toList(growable: false));
  }

  Future<void> save(DebtEntry debt) {
    return _database
        .into(_database.debts)
        .insertOnConflictUpdate(
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

  /// Records a payment and reduces the outstanding balance atomically.
  Future<void> recordPayment(DebtPayment payment) {
    return _database.transaction(() async {
      final debt = await (_database.select(
        _database.debts,
      )..where((row) => row.id.equals(payment.debtId))).getSingleOrNull();
      if (debt == null) throw StateError('Debt not found: ${payment.debtId}');
      if (payment.amount.minorUnits > debt.outstandingAmountMinorUnits) {
        throw ArgumentError('Payment exceeds the outstanding balance.');
      }
      await _database
          .into(_database.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              id: payment.id,
              debtId: payment.debtId,
              amountMinorUnits: payment.amount.minorUnits,
              paidAtEpochMillis: payment.paidAt.millisecondsSinceEpoch,
              note: Value(payment.note),
            ),
          );
      await (_database.update(
        _database.debts,
      )..where((row) => row.id.equals(payment.debtId))).write(
        DebtsCompanion(
          outstandingAmountMinorUnits: Value(
            debt.outstandingAmountMinorUnits - payment.amount.minorUnits,
          ),
        ),
      );
    });
  }

  Future<void> delete(String id) => (_database.delete(
    _database.debts,
  )..where((row) => row.id.equals(id))).go();

  /// Reverts a recorded payment and restores its amount atomically.
  Future<void> undoPayment(String paymentId) {
    return _database.transaction(() async {
      final payment = await (_database.select(_database.debtPayments)
            ..where((row) => row.id.equals(paymentId)))
          .getSingleOrNull();
      if (payment == null) throw StateError('Payment not found: $paymentId');
      final debt = await (_database.select(_database.debts)
            ..where((row) => row.id.equals(payment.debtId)))
          .getSingleOrNull();
      if (debt == null) throw StateError('Debt not found: ${payment.debtId}');
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
    });
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

  DebtPayment _paymentToDomain(DebtPaymentRow row) => DebtPayment(
    id: row.id,
    debtId: row.debtId,
    amount: Money.fromMinorUnits(row.amountMinorUnits),
    paidAt: DateTime.fromMillisecondsSinceEpoch(row.paidAtEpochMillis),
    note: row.note,
  );
}
