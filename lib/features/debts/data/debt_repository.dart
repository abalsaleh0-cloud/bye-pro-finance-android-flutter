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
import 'package:expense_app/features/debts/domain/debt_activity.dart';
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

  Stream<List<DebtPayment>> watchAllPayments() {
    return (_database.select(_database.debtPayments)
          ..orderBy([
            (row) => OrderingTerm.desc(row.paidAtEpochMillis),
            (row) => OrderingTerm.desc(row.id),
          ]))
        .watch()
        .map((rows) => rows.map(_paymentToDomain).toList(growable: false));
  }

  Stream<List<DebtPayment>> watchPayments(String debtId) {
    return (_database.select(_database.debtPayments)
          ..where((row) => row.debtId.equals(debtId))
          ..orderBy([(row) => OrderingTerm.desc(row.paidAtEpochMillis)]))
        .watch()
        .map((rows) => rows.map(_paymentToDomain).toList(growable: false));
  }

  Future<void> save(DebtEntry debt) async {
    await getActivity();
    await _database.transaction(() async {
      final previous = await (_database.select(_database.debts)
            ..where((row) => row.id.equals(debt.id)))
          .getSingleOrNull();
      final payments = await (_database.select(_database.debtPayments)
            ..where((row) => row.debtId.equals(debt.id)))
          .get();
      final paidTotal = payments.fold<int>(
        0,
        (sum, payment) => sum + payment.amountMinorUnits,
      );
      if (payments.isNotEmpty &&
          debt.outstandingAmount.minorUnits !=
              debt.originalAmount.minorUnits - paidTotal) {
        throw ArgumentError(
          'Outstanding balance must equal original amount minus recorded payments.',
        );
      }
      if (debt.originalAmount.minorUnits < paidTotal) {
        throw ArgumentError(
          'Original amount cannot be less than recorded payments.',
        );
      }
      await _database.into(_database.debts).insertOnConflictUpdate(
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
      final eventType = previous == null ? 'created' : 'updated';
      if (previous == null ||
          previous.direction != debt.direction.name ||
          previous.originalAmountMinorUnits != debt.originalAmount.minorUnits ||
          previous.outstandingAmountMinorUnits != debt.outstandingAmount.minorUnits ||
          previous.counterparty != debt.counterparty ||
          previous.note != debt.note) {
        await _writeActivity(
          id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
          debtId: debt.id,
          eventType: eventType,
          direction: debt.direction.name,
          counterparty: debt.counterparty,
          amountMinorUnits: debt.originalAmount.minorUnits,
          occurredAt: DateTime.now(),
          note: eventType == 'updated'
              ? 'Updated from ${previous!.originalAmountMinorUnits} to ${debt.originalAmount.minorUnits}'
              : debt.note,
        );
      }
    });
  }

  /// Records a payment and reduces the outstanding balance atomically.
  Future<void> recordPayment(DebtPayment payment) async {
    await getActivity();
    await _database.transaction(() async {
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
      await _writeActivity(
        id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
        debtId: payment.debtId,
        eventType: 'payment',
        direction: debt.direction,
        counterparty: debt.counterparty,
        amountMinorUnits: payment.amount.minorUnits,
        occurredAt: payment.paidAt,
        note: payment.note,
      );
    });
  }

  Future<void> delete(String id) async {
    await getActivity();
    await _database.transaction(() async {
      final payments = await (_database.select(_database.debtPayments)
            ..where((row) => row.debtId.equals(id)))
          .get();
      if (payments.isNotEmpty) {
        throw StateError(
          'Debt has payment history. Restore or archive it instead of deleting.',
        );
      }
      final debt = await (_database.select(_database.debts)
            ..where((row) => row.id.equals(id)))
          .getSingleOrNull();
      if (debt != null) {
        await _writeActivity(
          id: 'activity-${DateTime.now().microsecondsSinceEpoch}',
          debtId: debt.id,
          eventType: 'deleted',
          direction: debt.direction,
          counterparty: debt.counterparty,
          amountMinorUnits: debt.originalAmountMinorUnits,
          occurredAt: DateTime.now(),
          note: debt.note,
        );
      }
      await (_database.delete(_database.debts)
            ..where((row) => row.id.equals(id)))
          .go();
    });
  }

  /// Restores a deleted debt together with its immutable payment history.
  Future<void> restoreDebt(DebtEntry debt, List<DebtPayment> payments) {
    return _database.transaction(() async {
      if (payments.any((payment) => payment.debtId != debt.id)) {
        throw ArgumentError('Every restored payment must belong to the restored debt.');
      }
      final paidTotal = payments.fold<int>(
        0,
        (total, payment) => total + payment.amount.minorUnits,
      );
      if (payments.isNotEmpty &&
          paidTotal !=
              debt.originalAmount.minorUnits -
                  debt.outstandingAmount.minorUnits) {
        throw ArgumentError(
          'Restored payment history must match the debt outstanding balance.',
        );
      }

      await _database.into(_database.debts).insert(
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
      for (final payment in payments) {
        await _database.into(_database.debtPayments).insert(
          DebtPaymentsCompanion.insert(
            id: payment.id,
            debtId: payment.debtId,
            amountMinorUnits: payment.amount.minorUnits,
            paidAtEpochMillis: payment.paidAt.millisecondsSinceEpoch,
            note: Value(payment.note),
          ),
        );
      }
    });
  }

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
      await _writeActivity(
        id: 'activity-reversed-${DateTime.now().microsecondsSinceEpoch}',
        debtId: debt.id,
        eventType: 'payment_reversed',
        direction: debt.direction,
        counterparty: debt.counterparty,
        amountMinorUnits: payment.amountMinorUnits,
        occurredAt: DateTime.now(),
        note: payment.note,
      );
    });
  }


  /// Returns a newest-first audit trail. Older installations are backfilled
  /// once from their existing debt and payment records.
  Future<List<DebtActivity>> getActivity() async {
    if (await _database.readSetting('debt_activity_backfill_v1') != 'done') {
      await _database.transaction(() async {
        final existingDebts = await _database.select(_database.debts).get();
        for (final debt in existingDebts) {
          await _writeActivity(
            id: 'legacy-created-${debt.id}',
            debtId: debt.id,
            eventType: 'created',
            direction: debt.direction,
            counterparty: debt.counterparty,
            amountMinorUnits: debt.originalAmountMinorUnits,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(debt.createdAtEpochMillis),
            note: debt.note,
          );
        }
        final existingPayments = await _database.select(_database.debtPayments).get();
        for (final payment in existingPayments) {
          DebtRow? matchingDebt;
          for (final candidate in existingDebts) {
            if (candidate.id == payment.debtId) {
              matchingDebt = candidate;
              break;
            }
          }
          if (matchingDebt == null) continue;
          await _writeActivity(
            id: 'legacy-payment-${payment.id}',
            debtId: matchingDebt.id,
            eventType: 'payment',
            direction: matchingDebt.direction,
            counterparty: matchingDebt.counterparty,
            amountMinorUnits: payment.amountMinorUnits,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(payment.paidAtEpochMillis),
            note: payment.note,
          );
        }
        await _database.writeSetting('debt_activity_backfill_v1', 'done');
      });
    }

    final rows = await _database.customSelect(
      'SELECT * FROM debt_activity ORDER BY occurred_at_epoch_millis DESC, id DESC',
    ).get();
    return rows.map((row) => DebtActivity(
      id: row.read<String>('id'),
      debtId: row.read<String>('debt_id'),
      eventType: row.read<String>('event_type'),
      direction: row.read<String>('direction'),
      counterparty: row.read<String>('counterparty'),
      amountMinorUnits: row.read<int>('amount_minor_units'),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('occurred_at_epoch_millis'),
      ),
      note: row.read<String?>('note'),
    )).toList(growable: false);
  }

  Future<void> _writeActivity({
    required String id,
    required String debtId,
    required String eventType,
    required String direction,
    required String counterparty,
    required int amountMinorUnits,
    required DateTime occurredAt,
    String? note,
  }) {
    return _database.customStatement(
      'INSERT OR IGNORE INTO debt_activity '
      '(id, debt_id, event_type, direction, counterparty, amount_minor_units, occurred_at_epoch_millis, note) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        debtId,
        eventType,
        direction,
        counterparty,
        amountMinorUnits,
        occurredAt.millisecondsSinceEpoch,
        note,
      ],
    );
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
