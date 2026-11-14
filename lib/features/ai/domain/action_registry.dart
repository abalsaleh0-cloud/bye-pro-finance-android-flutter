// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings, prefer_initializing_formals

import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/dashboard/domain/monthly_overview.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';

typedef UndoOperation = Future<void> Function();
final class AssistantDashboardSummary {
  const AssistantDashboardSummary({
    required this.month,
    required this.overview,
    required this.homeBillPaymentsMinorUnits,
    required this.outstandingBillsAtMonthEndMinorUnits,
    required this.homeBalanceMinorUnits,
  });

  final MonthKey month;
  final MonthlyOverview overview;
  final int homeBillPaymentsMinorUnits;
  final int outstandingBillsAtMonthEndMinorUnits;
  final int homeBalanceMinorUnits;
}

final class ActionExecution {
  const ActionExecution({
    required this.message,
    this.undo,
    this.dashboardSummary,
  });

  final String message;
  final UndoOperation? undo;
  final AssistantDashboardSummary? dashboardSummary;
}
final class ActionDescriptor {
  const ActionDescriptor(this.name, this.requiredParameters, {this.readOnly = false});
  final String name;
  final Set<String> requiredParameters;
  final bool readOnly;
}
final class ActionRegistry {
  ActionRegistry({required WorkRepository work, required HomeExpenseRepository home, required HomeBillRepository bills, required DebtRepository debts, MonthKey? selectedMonth})
      : _work = work, _home = home, _bills = bills, _debts = debts, _selectedMonth = selectedMonth;
  final WorkRepository _work;
  final HomeExpenseRepository _home;
  final HomeBillRepository _bills;
  final DebtRepository _debts;
  final MonthKey? _selectedMonth;
  static const descriptors = <ActionDescriptor>[
    ActionDescriptor('save_work_entry', {'kind','amountMinorUnits','year','month'}),
    ActionDescriptor('delete_work_entry', {'id'}),
    ActionDescriptor('save_home_expense', {'amountMinorUnits','categoryId','date','year','month'}),
    ActionDescriptor('delete_home_expense', {'id'}),
    ActionDescriptor('save_home_bill', {'title','kind','amountMinorUnits','year','month'}),
    ActionDescriptor('delete_home_bill', {'id'}),
    ActionDescriptor('record_home_bill_payment', {'billId','amountMinorUnits'}),
    ActionDescriptor('read_home_bills', {}, readOnly: true),
    ActionDescriptor('read_work_records', {}, readOnly: true),
    ActionDescriptor('read_home_expenses', {}, readOnly: true),
    ActionDescriptor('read_debts', {}, readOnly: true),
    ActionDescriptor('read_work_transfers', {}, readOnly: true),
    ActionDescriptor('read_debt_payments', {'debtId'}, readOnly: true),
    ActionDescriptor('read_home_bill_payments', {'billId'}, readOnly: true),
    ActionDescriptor('save_work_home_transfer', {'amountMinorUnits'}),
    ActionDescriptor('delete_work_home_transfer', {'id'}),
    ActionDescriptor('save_debt', {'amountMinorUnits','direction','counterparty','year','month'}),
    ActionDescriptor('delete_debt', {'id'}),
    ActionDescriptor('record_debt_payment', {'debtId','amountMinorUnits'}),
    ActionDescriptor('read_work_remaining', {}, readOnly: true),
    ActionDescriptor('read_month_total', {'section','year','month'}, readOnly: true),
    ActionDescriptor('read_dashboard_summary', {}, readOnly: true),
    ActionDescriptor('navigate_to_section', {'section'}, readOnly: true),
  ];
  List<String> get actionNames => descriptors.map((e) => e.name).toList(growable: false);
  ActionDescriptor? descriptor(String name) {
    for (final item in descriptors) { if (item.name == name) return item; }
    return null;
  }
  String? validate(String name, Map<String,Object?> p) {
    final d = descriptor(name);
    if (d == null) return 'unknown action';
    final types = _typesFor(name);
    for (final entry in p.entries) {
      final expected = types[entry.key];
      if (expected == null) return 'unexpected parameter: ' + entry.key;
      if (entry.value != null && entry.value.runtimeType != expected) return 'invalid parameter type: ' + entry.key;
    }
    for (final key in d.requiredParameters) { if (p[key] == null) return 'missing parameter: ' + key; }
    final amount = p['amountMinorUnits'];
    if (amount != null && (amount is! int || amount <= 0)) return 'invalid amount';
    final year = p['year']; final month = p['month'];
    if (year != null && (year is! int || year < 1 || year > 9999)) return 'invalid year';
    if (month != null && (month is! int || month < 1 || month > 12)) return 'invalid month';
    if (name == 'read_dashboard_summary' && (year == null) != (month == null)) {
      return 'dashboard month requires both year and month';
    }
    if (name == 'save_work_entry' && !{'salary','advance','payment','salaryPayment'}.contains(p['kind'])) return 'invalid kind';
    if (name == 'save_debt' && !{'creditor','debtor'}.contains(p['direction'])) return 'invalid direction';
    if (name == 'save_home_bill' && !{'monthly','rent'}.contains(p['kind'])) return 'invalid bill kind';
    if (name == 'save_home_bill' && (p['title']! as String).trim().isEmpty) return 'missing bill title';
    if (name == 'record_home_bill_payment' && (p['billId']! as String).trim().isEmpty) return 'missing bill';
    if (name == 'read_month_total' && !{'work','home','debts'}.contains(p['section'])) return 'invalid section';
    if (name == 'navigate_to_section' &&
        !{'dashboard','work','home','debts','ai','settings'}.contains(p['section'])) {
      return 'invalid navigation section';
    }
    if (name == 'save_home_expense' && (p['categoryId']! as String).trim().isEmpty) return 'missing category';
    if (name == 'save_home_expense' && DateTime.tryParse(p['date']! as String) == null) return 'invalid date';
    if (name == 'save_work_home_transfer' && p['date'] is String && DateTime.tryParse(p['date']! as String) == null) return 'invalid date';
    if (name == 'save_debt' && (p['counterparty']! as String).trim().isEmpty) return 'missing counterparty';
    if (name == 'record_debt_payment' && (p['debtId']! as String).trim().isEmpty) return 'missing debt';
    return null;
  }
  Future<ActionExecution> execute(String name, Map<String,Object?> p) async {
    final error = validate(name,p); if (error != null) throw ArgumentError(error);
    switch(name) {
      case 'save_work_entry':
        final id = p['id'] as String? ?? _id();
        final all = await _work.watchEntries().first;
        WorkEntry? old; for(final e in all) { if(e.id == id) old=e; }
        final previous = old;
        final item = WorkEntry(id:id, kind:WorkEntryKind.values.byName(p['kind']! as String), amount:Money.fromMinorUnits(p['amountMinorUnits']! as int), dueMonth:MonthKey(year:p['year']! as int,month:p['month']! as int), recordedAt:previous?.recordedAt ?? DateTime.now(),note:p['note'] as String?);
        await _work.saveEntry(item);
        return ActionExecution(message:'تم حفظ سجل العمل',undo:() async { if(previous==null) { await _work.deleteEntry(id); } else { await _work.saveEntry(previous); } });
      case 'delete_work_entry':
        final all=await _work.watchEntries().first; WorkEntry? old; for(final e in all) { if(e.id==p['id']) old=e; }
        if(old==null) throw StateError('Work entry not found'); final deleted = old; await _work.deleteEntry(deleted.id);
        return ActionExecution(message:'تم حذف سجل العمل',undo:()=>_work.saveEntry(deleted));
      case 'save_home_expense':
        final id=p['id'] as String? ?? _id(); final all=await _home.watchAll().first; HomeExpense? old; for(final e in all) { if(e.id==id) old=e; }
        final previous = old;
        final item=HomeExpense(id:id,amount:Money.fromMinorUnits(p['amountMinorUnits']! as int),categoryId:p['categoryId']! as String,expenseDate:DateTime.parse(p['date']! as String),dueMonth:MonthKey(year:p['year']! as int,month:p['month']! as int),note:p['note'] as String?);
        await _home.save(item); return ActionExecution(message:'تم حفظ مصروف المنزل',undo:() async { if(previous==null) { await _home.delete(id); } else { await _home.save(previous); } });
      case 'delete_home_expense':
        final all=await _home.watchAll().first; HomeExpense? old; for(final e in all) { if(e.id==p['id']) old=e; }
        if(old==null) throw StateError('Home expense not found'); final deleted = old; await _home.delete(deleted.id); return ActionExecution(message:'تم حذف مصروف المنزل',undo:()=>_home.save(deleted));
      case 'save_home_bill':
        final id = p['id'] as String? ?? _id();
        final existing = (await _bills.getBills()).where((bill) => bill.id == id).firstOrNull;
        final bill = HomeBill(
          id: id,
          title: p['title']! as String,
          kind: HomeBillKind.values.byName(p['kind']! as String),
          amount: Money.fromMinorUnits(p['amountMinorUnits']! as int),
          dueMonth: MonthKey(year: p['year']! as int, month: p['month']! as int),
          note: p['note'] as String?,
          paidMinorUnits: existing?.paidMinorUnits ?? 0,
        );
        await _bills.saveBill(bill);
        return ActionExecution(
          message: 'تم حفظ الفاتورة المنزلية',
          undo: () async {
            if (existing == null) {
              await _bills.deleteBill(id);
            } else {
              await _bills.saveBill(existing);
            }
          },
        );
      case 'delete_home_bill':
        final existing = (await _bills.getBills()).where((bill) => bill.id == p['id']).firstOrNull;
        if (existing == null) throw StateError('Home bill not found');
        final payments = await _bills.paymentsFor(existing.id);
        if (payments.isNotEmpty) {
          throw StateError('A bill with payment history cannot be deleted');
        }
        await _bills.deleteBill(existing.id);
        return ActionExecution(
          message: 'تم حذف الفاتورة وسجل دفعاتها',
          undo: () async => _bills.saveBill(existing),
        );
      case 'record_home_bill_payment':
        final payment = HomeBillPayment(
          id: _id(),
          billId: p['billId']! as String,
          amount: Money.fromMinorUnits(p['amountMinorUnits']! as int),
          paidAt: DateTime.now(),
          note: p['note'] as String?,
        );
        await _bills.recordPayment(payment);
        return ActionExecution(
          message: 'تم تسجيل دفعة الفاتورة',
          undo: () => _bills.undoPayment(payment.id),
        );
      case 'read_work_records':
        final now = DateTime.now();
        final month = p['year'] == null
            ? (_selectedMonth ?? MonthKey(year: now.year, month: now.month))
            : MonthKey(year: p['year']! as int, month: p['month']! as int);
        final workEntries = (await _work.watchEntries().first)
            .where((entry) => entry.dueMonth == month)
            .toList(growable: false);
        if (workEntries.isEmpty) {
          return ActionExecution(message: 'لا توجد سجلات عمل لشهر $month.');
        }
        return ActionExecution(
          message: workEntries.map((entry) =>
            '${entry.id}: ${entry.kind.name}، ${entry.amount.minorUnits}، ${entry.dueMonth}'
          ).join('؛ '),
        );
      case 'read_home_expenses':
        final now = DateTime.now();
        final month = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final expenses = (await _home.watchAll().first)
            .where((expense) => expense.dueMonth == month)
            .toList(growable: false);
        if (expenses.isEmpty) {
          return ActionExecution(message: 'لا توجد مصروفات منزلية لشهر $month.');
        }
        return ActionExecution(
          message: expenses.map((expense) =>
            '${expense.id}: ${expense.categoryId}، ${expense.amount.minorUnits}، ${expense.expenseDate.toLocal().toIso8601String().split('T').first}'
          ).join('؛ '),
        );
      case 'read_debts':
        final now = DateTime.now();
        final month = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final debts = (await _debts.watchAll().first)
            .where((debt) => debt.dueMonth == month)
            .toList(growable: false);
        if (debts.isEmpty) {
          return ActionExecution(message: 'لا توجد ديون مسجلة لشهر $month.');
        }
        return ActionExecution(
          message: debts.map((debt) =>
            '${debt.id}: ${debt.direction.name}، ${debt.counterparty}، المتبقي ${debt.outstandingAmount.minorUnits}'
          ).join('؛ '),
        );
      case 'read_work_transfers':
        final now = DateTime.now();
        final month = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final transfers = (await _work.watchTransfers().first).where((item) {
          final date = item.transferredAt.toLocal();
          return date.year == month.year && date.month == month.month;
        }).toList(growable: false);
        if (transfers.isEmpty) {
          return ActionExecution(message: 'لا توجد تحويلات إلى المنزل لشهر $month.');
        }
        return ActionExecution(
          message: transfers.map((item) =>
            '${item.id}: ${item.amount.minorUnits}، ${item.transferredAt.toLocal().toIso8601String().split('T').first}'
          ).join('؛ '),
        );
      case 'read_debt_payments':
        final payments = await _debts.watchPayments(p['debtId']! as String).first;
        if (payments.isEmpty) {
          return const ActionExecution(message: 'لا توجد دفعات مسجلة لهذا الدين.');
        }
        return ActionExecution(
          message: payments.map((payment) =>
            '${payment.id}: ${payment.amount.minorUnits}، ${payment.paidAt.toLocal().toIso8601String().split('T').first}'
          ).join('؛ '),
        );
      case 'read_home_bill_payments':
        final payments = await _bills.paymentsFor(p['billId']! as String);
        if (payments.isEmpty) {
          return const ActionExecution(message: 'لا توجد دفعات مسجلة لهذه الفاتورة.');
        }
        return ActionExecution(
          message: payments.map((payment) =>
            '${payment.id}: ${payment.amount.minorUnits}، ${payment.paidAt.toLocal().toIso8601String().split('T').first}'
          ).join('؛ '),
        );
      case 'read_home_bills':
        final now = DateTime.now();
        final month = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final bills = (await _bills.getBills())
            .where((bill) => bill.dueMonth == month)
            .toList(growable: false);
        if (bills.isEmpty) {
          return ActionExecution(message: 'لا توجد فواتير أو إيجارات مسجلة لشهر $month.');
        }
        final summary = bills.map((bill) =>
          '${bill.id}: ${bill.title} (${bill.dueMonth}): المتبقي ${bill.remainingMinorUnits}'
        ).join('؛ ');
        return ActionExecution(message: summary);
      case 'save_work_home_transfer':
        final id=p['id'] as String? ?? _id(); final all=await _work.watchTransfers().first; WorkHomeTransfer? old; for(final e in all) { if(e.id==id) old=e; }
        final previous = old;
        final item=WorkHomeTransfer(id:id,amount:Money.fromMinorUnits(p['amountMinorUnits']! as int),transferredAt:p['date'] is String ? DateTime.parse(p['date']! as String) : DateTime.now(),note:p['note'] as String?);
        await _work.saveTransfer(item); return ActionExecution(message:'تم تسجيل التحويل إلى المنزل',undo:() async { if(previous==null) { await _work.deleteTransfer(id); } else { await _work.saveTransfer(previous); } });
      case 'delete_work_home_transfer':
        final all=await _work.watchTransfers().first; WorkHomeTransfer? old; for(final e in all) { if(e.id==p['id']) old=e; }
        if(old==null) throw StateError('Transfer not found'); final deleted = old; await _work.deleteTransfer(deleted.id); return ActionExecution(message:'تم حذف التحويل',undo:()=>_work.saveTransfer(deleted));
      case 'save_debt':
        final id=p['id'] as String? ?? _id(); final all=await _debts.watchAll().first; DebtEntry? old; for(final e in all) { if(e.id==id) old=e; }
        final previous = old;
        final amount=Money.fromMinorUnits(p['amountMinorUnits']! as int);
        final previousPayments = previous == null
            ? const <DebtPayment>[]
            : await _debts.watchPayments(id).first;
        final paidTotal = previousPayments.fold<int>(
          0,
          (total, payment) => total + payment.amount.minorUnits,
        );
        if (paidTotal > amount.minorUnits) {
          throw ArgumentError(
            'Debt amount cannot be lower than its recorded payments.',
          );
        }
        final item=DebtEntry(id:id,direction:DebtDirection.values.byName(p['direction']! as String),originalAmount:amount,outstandingAmount:Money.fromMinorUnits(amount.minorUnits - paidTotal),dueMonth:MonthKey(year:p['year']! as int,month:p['month']! as int),createdAt:previous?.createdAt ?? DateTime.now(),counterparty:p['counterparty']! as String,note:p['note'] as String?);
        await _debts.save(item); return ActionExecution(message:'تم حفظ الدين',undo:() async { if(previous==null) { await _debts.delete(id); } else { await _debts.save(previous); } });
      case 'delete_debt':
        final all=await _debts.watchAll().first; DebtEntry? old; for(final e in all) { if(e.id==p['id']) old=e; }
        if(old==null) throw StateError('Debt not found'); final deleted = old; final payments=await _debts.watchPayments(deleted.id).first; await _debts.delete(deleted.id);
        return ActionExecution(message:'تم حذف الدين',undo:() async { await _debts.restoreDebt(deleted,payments); });
      case 'record_debt_payment':
        final payment=DebtPayment(id:_id(),debtId:p['debtId']! as String,amount:Money.fromMinorUnits(p['amountMinorUnits']! as int),paidAt:DateTime.now(),note:p['note'] as String?);
        await _debts.recordPayment(payment); return ActionExecution(message:'تم تسجيل دفعة الدين',undo:()=>_debts.undoPayment(payment.id));
      case 'read_work_remaining':
        final all = await _work.watchEntries().first;
        final now = DateTime.now();
        final current = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final received = all
            .where(
              (entry) =>
                  entry.dueMonth == current &&
                  entry.kind != WorkEntryKind.salary,
            )
            .fold<int>(
              0,
              (total, entry) => total + entry.amount.minorUnits,
            );
        final transfers = await _work.watchTransfers().first;
        final transferred = transfers.where((item) {
          final date = item.transferredAt.toLocal();
          return date.year == current.year && date.month == current.month;
        }).fold<int>(0, (total, item) => total + item.amount.minorUnits);
        return ActionExecution(
          message: 'الباقي في العمل: ' + (received - transferred).toString(),
        );
      case 'read_month_total':
        final month=MonthKey(year:p['year']! as int,month:p['month']! as int); final section=p['section']! as String; var total=0;
        if(section=='work') { for(final e in await _work.watchEntries().first) { if(e.dueMonth==month) total+=e.amount.minorUnits; } }
        else if(section=='home') { for(final e in await _home.watchAll().first) { if(e.dueMonth==month) total+=e.amount.minorUnits; } }
        else { for(final e in await _debts.watchAll().first) { if(e.dueMonth==month) total+=e.outstandingAmount.minorUnits; } }
        return ActionExecution(message:'مجموع ' + section + ' لشهر ' + month.toString() + ': ' + total.toString());
      case 'read_dashboard_summary':
        final now = DateTime.now();
        final month = _selectedMonth ?? MonthKey(year: now.year, month: now.month);
        final workEntries = await _work.watchEntries().first;
        final homeExpenses = await _home.watchAll().first;
        final transfers = await _work.watchTransfers().first;
        final debts = await _debts.watchAll().first;
        final overview = MonthlyOverview.calculate(
          month: month,
          workEntries: workEntries,
          homeExpenses: homeExpenses,
          transfers: transfers,
          debts: debts,
        );
        final billPayments = await _bills.paymentsTotalForMonth(month);
        final outstandingBills = await _bills.outstandingForMonthAsOfEnd(month);
        final homeBalance = overview.transfers.minorUnits -
            overview.homeExpenses.minorUnits -
            billPayments -
            outstandingBills;
        return ActionExecution(
          message: '',
          dashboardSummary: AssistantDashboardSummary(
            month: month,
            overview: overview,
            homeBillPaymentsMinorUnits: billPayments,
            outstandingBillsAtMonthEndMinorUnits: outstandingBills,
            homeBalanceMinorUnits: homeBalance,
          ),
        );
      default: throw StateError('Unsupported action');
    }
  }
  Map<String, Type> _typesFor(String name) => switch (name) {
    'save_work_entry' => const {'kind': String, 'amountMinorUnits': int, 'year': int, 'month': int, 'id': String, 'note': String},
    'delete_work_entry' || 'delete_home_expense' || 'delete_work_home_transfer' || 'delete_debt' => const {'id': String},
    'save_home_expense' => const {'amountMinorUnits': int, 'categoryId': String, 'date': String, 'year': int, 'month': int, 'id': String, 'note': String},
    'save_home_bill' => const {'title': String, 'kind': String, 'amountMinorUnits': int, 'year': int, 'month': int, 'id': String, 'note': String},
    'delete_home_bill' => const {'id': String},
    'record_home_bill_payment' => const {'billId': String, 'amountMinorUnits': int, 'note': String},
    'read_home_bills' || 'read_work_records' || 'read_home_expenses' || 'read_debts' || 'read_work_transfers' => const {},
    'read_debt_payments' => const {'debtId': String},
    'read_home_bill_payments' => const {'billId': String},
    'save_work_home_transfer' => const {'amountMinorUnits': int, 'id': String, 'date': String, 'note': String},
    'save_debt' => const {'amountMinorUnits': int, 'direction': String, 'counterparty': String, 'year': int, 'month': int, 'id': String, 'note': String},
    'record_debt_payment' => const {'debtId': String, 'amountMinorUnits': int, 'note': String},
    'read_work_remaining' => const {},
    'read_month_total' => const {'section': String, 'year': int, 'month': int},
    'read_dashboard_summary' => const {'year': int, 'month': int},
    'navigate_to_section' => const {'section': String},
    _ => const {},
  };
  static String _id()=>DateTime.now().microsecondsSinceEpoch.toString();
}