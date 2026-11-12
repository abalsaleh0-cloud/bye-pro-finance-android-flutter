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
    final rows = await _database.customSelect('SELECT b.id, b.title, b.kind, b.amount_minor_units, b.due_year, b.due_month, b.note, COALESCE(SUM(p.amount_minor_units), 0) AS paid_minor_units FROM home_bills b LEFT JOIN home_bill_payments p ON p.bill_id = b.id GROUP BY b.id ORDER BY b.due_year DESC, b.due_month DESC, b.title COLLATE NOCASE').watch().map((rows) => rows.map((row) => HomeBill(
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
    if (bill.title.trim().isEmpty || bill.amount.minorUnits <= 0) throw ArgumentError('Invalid bill details');
    await _database.customStatement('INSERT OR REPLACE INTO home_bills (id, title, kind, amount_minor_units, due_year, due_month, note) VALUES (?, ?, ?, ?, ?, ?, ?)', [bill.id, bill.title.trim(), bill.kind.name, bill.amount.minorUnits, bill.dueMonth.year, bill.dueMonth.month, bill.note]);
  }

  Future<void> recordPayment(HomeBillPayment payment) async {
    await ensureTables();
    await _database.transaction(() async {
      final billRows = await _database.customSelect('SELECT amount_minor_units FROM home_bills WHERE id = ?', variables: [Variable.withString(payment.billId)]).get();
      if (billRows.isEmpty) throw ArgumentError('Bill not found');
      final billAmount = billRows.single.read<int>('amount_minor_units');
      final paidRows = await _database.customSelect('SELECT COALESCE(SUM(amount_minor_units), 0) AS paid FROM home_bill_payments WHERE bill_id = ?', variables: [Variable.withString(payment.billId)]).get();
      final paid = paidRows.single.read<int>('paid');
      if (payment.amount.minorUnits <= 0 || paid + payment.amount.minorUnits > billAmount) throw ArgumentError('Payment exceeds outstanding bill amount');
      final transfers = await _database.customSelect('SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM work_home_transfers').get();
      final dailyExpenses = await _database.customSelect('SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_expenses').get();
      final billPayments = await _database.customSelect('SELECT COALESCE(SUM(amount_minor_units), 0) AS total FROM home_bill_payments').get();
      final available = transfers.single.read<int>('total') - dailyExpenses.single.read<int>('total') - billPayments.single.read<int>('total');
      if (payment.amount.minorUnits > available) throw InsufficientBillPaymentBalanceException(available);
      await _database.customStatement('INSERT INTO home_bill_payments (id, bill_id, amount_minor_units, paid_at_epoch_millis, note) VALUES (?, ?, ?, ?, ?)', [payment.id, payment.billId, payment.amount.minorUnits, payment.paidAt.millisecondsSinceEpoch, payment.note]);
    });
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
