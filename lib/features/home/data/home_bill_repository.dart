import 'package:drift/drift.dart';
import 'package:expense_app/core/database/app_database.dart' show AppDatabase;
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';

final class InsufficientBillPaymentBalanceException implements Exception {
  const InsufficientBillPaymentBalanceException(this.availableMinorUnits);
  final int availableMinorUnits;
}

final class HomeBillRepository {
  const HomeBillRepository(this._database);
  final AppDatabase _database;

  Future<void> ensureTables() async {
    await _database.customStatement('CREATE TABLE IF NOT EXISTS home_bills (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN (\'monthly\', \'rent\')), amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0), due_year INTEGER NOT NULL, due_month INTEGER NOT NULL CHECK (due_month BETWEEN 1 AND 12), note TEXT)');
    await _database.customStatement('CREATE TABLE IF NOT EXISTS home_bill_payments (id TEXT PRIMARY KEY NOT NULL, bill_id TEXT NOT NULL REFERENCES home_bills(id) ON DELETE CASCADE, amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0), paid_at_epoch_millis INTEGER NOT NULL, note TEXT)');
  }

  Future<List<HomeBill>> getBills() async {
    await ensureTables();
    final rows = await _database.customSelect(
      'SELECT b.id, b.title, b.kind, b.amount_minor_units, b.due_year, b.due_month, b.note, COALESCE(SUM(p.amount_minor_units), 0) AS paid_minor_units FROM home_bills b LEFT JOIN home_bill_payments p ON p.bill_id = b.id GROUP BY b.id ORDER BY b.due_year DESC, b.due_month DESC, b.title COLLATE NOCASE',
    ).get();
    return rows.map((row) => HomeBill(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      kind: row.read<String>('kind') == 'rent' ? HomeBillKind.rent : HomeBillKind.monthly,
      amount: Money.fromMinorUnits(row.read<int>('amount_minor_units')),
      dueMonth: MonthKey(year: row.read<int>('due_year'), month: row.read<int>('due_month')),
      note: row.read<String?>('note'),
      paidMinorUnits: row.read<int>('paid_minor_units'),
    )).toList(growable: false);
  }

  Future<void> saveBill(HomeBill bill) async {
    await ensureTables();
    if (bill.title.trim().isEmpty || bill.amount.minorUnits <= 0) {
      throw ArgumentError('Invalid bill details');
    }
    await _database.transaction(() async {
      final existing = await _database.customSelect(
        'SELECT id, amount_minor_units, due_year, due_month FROM home_bills WHERE id = ?',
        variables: [Variable.withString(bill.id)],
      ).get();
      if (existing.isEmpty) {
        await _database.customStatement(
          'INSERT INTO home_bills (id, title, kind, amount_minor_units, due_year, due_month, note) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [bill.id, bill.title.trim(), bill.kind.name, bill.amount.minorUnits, bill.dueMonth.year, bill.dueMonth.month, bill.note],
        );
        return;
      }

      final paymentRows = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS paid FROM home_bill_payments WHERE bill_id = ?',
        variables: [Variable.withString(bill.id)],
      ).get();
      final paid = paymentRows.single.read<int>('paid');
      if (bill.amount.minorUnits < paid) {
        throw ArgumentError('Bill amount cannot be lower than its recorded payments');
      }

      final previous = existing.single;
      final previousDueMonth = MonthKey(
        year: previous.read<int>('due_year'),
        month: previous.read<int>('due_month'),
      );
      final previousRemaining =
          previous.read<int>('amount_minor_units') - paid;
      final nextRemaining = bill.amount.minorUnits - paid;
      final targetCommitted = await _homeCommittedAmount(bill.dueMonth);
      final targetTransfers = await _transferredForMonth(bill.dueMonth);
      final targetAlreadyIncluded =
          previousDueMonth == bill.dueMonth ? previousRemaining : 0;
      final projectedCommitted =
          targetCommitted - targetAlreadyIncluded + nextRemaining;
      if (projectedCommitted > targetTransfers &&
          projectedCommitted > targetCommitted) {
        throw InsufficientBillPaymentBalanceException(
          targetTransfers - targetCommitted + targetAlreadyIncluded,
        );
      }

      await _database.customStatement(
        'UPDATE home_bills SET title = ?, kind = ?, amount_minor_units = ?, due_year = ?, due_month = ?, note = ? WHERE id = ?',
        [bill.title.trim(), bill.kind.name, bill.amount.minorUnits, bill.dueMonth.year, bill.dueMonth.month, bill.note, bill.id],
      );
    });
  }

  Future<void> recordPayment(HomeBillPayment payment) async {
    await ensureTables();
    await _database.transaction(() async {
      final billRows = await _database.customSelect('SELECT amount_minor_units, due_year, due_month FROM home_bills WHERE id = ?', variables: [Variable.withString(payment.billId)]).get();
      if (billRows.isEmpty) {
        throw ArgumentError('Bill not found');
      }
      final billAmount = billRows.single.read<int>('amount_minor_units');
      final billDueMonth = MonthKey(
        year: billRows.single.read<int>('due_year'),
        month: billRows.single.read<int>('due_month'),
      );
      final paidRows = await _database.customSelect('SELECT COALESCE(SUM(amount_minor_units), 0) AS paid FROM home_bill_payments WHERE bill_id = ?', variables: [Variable.withString(payment.billId)]).get();
      final paid = paidRows.single.read<int>('paid');
      if (payment.amount.minorUnits <= 0 || paid + payment.amount.minorUnits > billAmount) {
        throw ArgumentError('Payment exceeds outstanding bill amount');
      }
      final paymentDate = payment.paidAt.toLocal();
      final monthStart = DateTime(paymentDate.year, paymentDate.month).millisecondsSinceEpoch;
      final nextMonthStart = DateTime(paymentDate.year, paymentDate.month + 1).millisecondsSinceEpoch;
      final transfers = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM work_home_transfers WHERE transferred_at_epoch_millis >= ? AND transferred_at_epoch_millis < ?',
        variables: [Variable.withInt(monthStart), Variable.withInt(nextMonthStart)],
      ).get();
      final dailyExpenses = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_expenses WHERE expense_date_epoch_millis >= ? AND expense_date_epoch_millis < ?',
        variables: [Variable.withInt(monthStart), Variable.withInt(nextMonthStart)],
      ).get();
      final billPayments = await _database.customSelect(
        'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?',
        variables: [Variable.withInt(monthStart), Variable.withInt(nextMonthStart)],
      ).get();
      final paymentMonth = MonthKey(
        year: paymentDate.year,
        month: paymentDate.month,
      );
      final otherOutstandingBills = await outstandingForMonth(
        paymentMonth,
        excludingBillId: billDueMonth == paymentMonth ? payment.billId : null,
      );
      final available = transfers.single.read<int>('total') -
          dailyExpenses.single.read<int>('total') -
          billPayments.single.read<int>('total') -
          otherOutstandingBills;
      if (payment.amount.minorUnits > available) {
        throw InsufficientBillPaymentBalanceException(available);
      }
      await _database.customStatement('INSERT INTO home_bill_payments (id, bill_id, amount_minor_units, paid_at_epoch_millis, note) VALUES (?, ?, ?, ?, ?)', [payment.id, payment.billId, payment.amount.minorUnits, payment.paidAt.millisecondsSinceEpoch, payment.note]);
    });
  }

  /// Reverts a recorded bill payment without changing any other payment.
  Future<void> undoPayment(String paymentId) async {
    await ensureTables();
    await _database.transaction(() async {
      final rows = await _database.customSelect(
        'SELECT p.amount_minor_units, p.paid_at_epoch_millis, '
        'b.due_year, b.due_month '
        'FROM home_bill_payments p '
        'JOIN home_bills b ON b.id = p.bill_id '
        'WHERE p.id = ?',
        variables: [Variable.withString(paymentId)],
      ).get();
      if (rows.isEmpty) {
        throw StateError('Bill payment not found: $paymentId');
      }

      final payment = rows.single;
      final dueMonth = MonthKey(
        year: payment.read<int>('due_year'),
        month: payment.read<int>('due_month'),
      );
      final paidAt = DateTime.fromMillisecondsSinceEpoch(
        payment.read<int>('paid_at_epoch_millis'),
      ).toLocal();
      final paymentMonth = MonthKey(year: paidAt.year, month: paidAt.month);

      // Undoing a payment in a different month restores the unpaid obligation
      // to the bill's due month. Ensure that month still has enough transfers.
      // In the same month, the payment outflow and outstanding reservation
      // offset each other, so the total commitment does not change.
      if (paymentMonth != dueMonth) {
        final committed = await _homeCommittedAmount(dueMonth);
        final transferred = await _transferredForMonth(dueMonth);
        final available = transferred - committed;
        final amount = payment.read<int>('amount_minor_units');
        if (amount > available) {
          throw InsufficientBillPaymentBalanceException(available);
        }
      }

      await _database.customStatement(
        'DELETE FROM home_bill_payments WHERE id = ?',
        [paymentId],
      );
    });
  }

  Future<int> _homeCommittedAmount(MonthKey month) async {
    final start = DateTime(month.year, month.month).millisecondsSinceEpoch;
    final finish = DateTime(month.year, month.month + 1).millisecondsSinceEpoch;
    final expenses = await _database.customSelect(
      'SELECT COALESCE(SUM(amount_minor_units), 0) AS total '
      'FROM home_expenses WHERE expense_date_epoch_millis >= ? '
      'AND expense_date_epoch_millis < ?',
      variables: [Variable.withInt(start), Variable.withInt(finish)],
    ).get();
    final payments = await paymentsTotalForMonth(month);
    final outstanding = await outstandingForMonth(month);
    return expenses.single.read<int>('total') + payments + outstanding;
  }

  Future<int> _transferredForMonth(MonthKey month) async {
    final start = DateTime(month.year, month.month).millisecondsSinceEpoch;
    final finish = DateTime(month.year, month.month + 1).millisecondsSinceEpoch;
    final rows = await _database.customSelect(
      'SELECT COALESCE(SUM(amount_minor_units), 0) AS total '
      'FROM work_home_transfers WHERE transferred_at_epoch_millis >= ? '
      'AND transferred_at_epoch_millis < ?',
      variables: [Variable.withInt(start), Variable.withInt(finish)],
    ).get();
    return rows.single.read<int>('total');
  }

  /// Returns the unpaid portion of bills due in [month].
  ///
  /// Payments are already counted as cash outflow in the month they were made,
  /// so callers combine this value with that month's recorded bill payments.
  Future<int> outstandingForMonth(
    MonthKey month, {
    String? excludingBillId,
  }) async {
    await ensureTables();
    final exclusion = excludingBillId == null ? '' : ' AND b.id != ?';
    final variables = <Variable<Object>>[
      Variable.withInt(month.year),
      Variable.withInt(month.month),
      if (excludingBillId != null) Variable.withString(excludingBillId),
    ];
    final rows = await _database.customSelect(
      'SELECT COALESCE(SUM(b.amount_minor_units - COALESCE(p.paid_minor_units, 0)), 0) AS total '
      'FROM home_bills b '
      'LEFT JOIN (SELECT bill_id, SUM(amount_minor_units) AS paid_minor_units '
      'FROM home_bill_payments GROUP BY bill_id) p ON p.bill_id = b.id '
      'WHERE b.due_year = ? AND b.due_month = ?$exclusion',
      variables: variables,
    ).get();
    return rows.single.read<int>('total');
  }

  Future<int> paymentsTotalForMonth(MonthKey month) async {
    await ensureTables();
    final start = DateTime(month.year, month.month).millisecondsSinceEpoch;
    final finish = DateTime(month.year, month.month + 1).millisecondsSinceEpoch;
    final rows = await _database.customSelect(
      'SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?',
      variables: [Variable.withInt(start), Variable.withInt(finish)],
    ).get();
    return rows.single.read<int>('total');
  }

  Future<List<HomeBillPayment>> paymentsFor(String billId) async {
    await ensureTables();
    final rows = await _database.customSelect('SELECT id, bill_id, amount_minor_units, paid_at_epoch_millis, note FROM home_bill_payments WHERE bill_id = ? ORDER BY paid_at_epoch_millis', variables: [Variable.withString(billId)]).get();
    return rows.map((row) => HomeBillPayment(id: row.read<String>('id'), billId: row.read<String>('bill_id'), amount: Money.fromMinorUnits(row.read<int>('amount_minor_units')), paidAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('paid_at_epoch_millis')), note: row.read<String?>('note'))).toList(growable: false);
  }

  Future<void> deleteBill(String id) async {
    await ensureTables();
    await _database.customStatement('DELETE FROM home_bills WHERE id = ?', [id]);
  }
}
