// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings, prefer_initializing_formals

import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/dashboard/domain/monthly_overview.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/data/home_expense_category_repository.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';
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
  ActionRegistry({required WorkRepository work, required HomeExpenseRepository home, required HomeBillRepository bills, required DebtRepository debts, required HomeExpenseCategoryRepository categories, MonthKey? selectedMonth})
      : _work = work, _home = home, _bills = bills, _debts = debts, _categories = categories, _selectedMonth = selectedMonth;
  final WorkRepository _work;
  final HomeExpenseRepository _home;
  final HomeBillRepository _bills;
  final DebtRepository _debts;
  final HomeExpenseCategoryRepository _categories;
  final MonthKey? _selectedMonth;
  static const descriptors = <ActionDescriptor>[
    ActionDescriptor('save_work_entry', {'kind','amountMinorUnits','year','month'}),
    ActionDescriptor('delete_work_entry', {}),
    ActionDescriptor('save_home_expense', {'amountMinorUnits','date','year','month'}),
    ActionDescriptor('read_home_categories', {}, readOnly: true),
    ActionDescriptor('save_home_category', {'name'}),
    ActionDescriptor('delete_home_category', {}),
    ActionDescriptor('delete_home_expense', {}),
    ActionDescriptor('save_home_bill', {'title','kind','amountMinorUnits','year','month'}),
    ActionDescriptor('delete_home_bill', {}),
    ActionDescriptor('record_home_bill_payment', {'amountMinorUnits'}),
    ActionDescriptor('read_home_bills', {}, readOnly: true),
    ActionDescriptor('read_work_records', {}, readOnly: true),
    ActionDescriptor('read_home_expenses', {}, readOnly: true),
    ActionDescriptor('read_debts', {}, readOnly: true),
    ActionDescriptor('read_work_transfers', {}, readOnly: true),
    ActionDescriptor('read_debt_payments', {}, readOnly: true),
    ActionDescriptor('read_home_bill_payments', {}, readOnly: true),
    ActionDescriptor('save_work_home_transfer', {'amountMinorUnits'}),
    ActionDescriptor('delete_work_home_transfer', {}),
    ActionDescriptor('save_debt', {'amountMinorUnits','direction','counterparty','year','month'}),
    ActionDescriptor('delete_debt', {}),
    ActionDescriptor('record_debt_payment', {'amountMinorUnits'}),
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
    for (final key in d.requiredParameters) {
      if (p[key] != null) continue;
      // The local parser and Gemma may resolve a named bill/debt to one exact
      // record. The execution validator below rejects a missing or ambiguous target.
      if (name == 'read_home_bill_payments' &&
          key == 'billId' && (p['billTitle'] != null || p['id'] != null)) {
        continue;
      }
      if (name == 'read_debt_payments' &&
          key == 'debtId' && (p['counterparty'] != null || p['id'] != null)) {
        continue;
      }
      return 'missing parameter: ' + key;
    }
    final amount = p['amountMinorUnits'];
    if (amount != null && (amount is! int || amount <= 0)) return 'invalid amount';
    final year = p['year']; final month = p['month'];
    if (year != null && (year is! int || year < 1 || year > 9999)) return 'invalid year';
    if (month != null && (month is! int || month < 1 || month > 12)) return 'invalid month';
    if (name == 'read_dashboard_summary' && (year == null) != (month == null)) {
      return 'dashboard month requires both year and month';
    }
    if (name == 'delete_home_expense' && (year == null) != (month == null)) {
      return 'expense deletion month requires both year and month';
    }
    if (const {'delete_work_entry', 'delete_work_home_transfer'}.contains(name) &&
        (year == null) != (month == null)) {
      return 'deletion month requires both year and month';
    }
    if (const {'delete_work_entry', 'delete_work_home_transfer'}.contains(name) &&
        p['date'] is String && year != null) {
      final date = DateTime.tryParse(p['date']! as String);
      if (date == null) return 'invalid date';
      if (date.year != year || date.month != month) {
        return 'deletion date and month differ';
      }
    }
    if (name == 'delete_home_expense' && p['date'] is String) {
      final date = DateTime.tryParse(p['date']! as String);
      if (date == null) return 'invalid date';
      if (year != null && (date.year != year || date.month != month)) {
        return 'expense deletion date and month differ';
      }
    }
    if (const {
      'read_work_records',
      'read_home_expenses',
      'read_debts',
      'read_work_transfers',
      'read_home_bills',
    }.contains(name) && (year == null) != (month == null)) {
      return 'list month requires both year and month';
    }
    if (name == 'save_work_entry' && !{'salary','advance','payment','salaryPayment'}.contains(p['kind'])) return 'invalid kind';
    if (name == 'save_debt' && !{'creditor','debtor'}.contains(p['direction'])) return 'invalid direction';
    if (name == 'save_home_bill' && !{'monthly','rent'}.contains(p['kind'])) return 'invalid bill kind';
    if (name == 'save_home_bill' && (p['title']! as String).trim().isEmpty) return 'missing bill title';
    if (name == 'record_home_bill_payment' &&
        (p['billId'] == null && p['billTitle'] == null)) return 'missing bill';
    if (name == 'delete_home_expense' && p['id'] == null &&
        ((p['categoryId'] == null && p['categoryName'] == null) ||
            p['amountMinorUnits'] == null)) {
      return 'expense deletion needs an ID or a unique category and amount';
    }
    if (name == 'delete_work_entry' && p['id'] == null &&
        (p['kind'] == null || p['amountMinorUnits'] == null ||
            (year == null && p['date'] == null))) {
      return 'work record deletion needs an ID or unique kind, amount and date/month';
    }
    if (name == 'delete_work_home_transfer' && p['id'] == null &&
        (p['amountMinorUnits'] == null ||
            (p['date'] == null && (year == null || month == null)))) {
      return 'transfer deletion needs an ID or a unique amount and date/month';
    }
    if (name == 'delete_work_entry' &&
        p['kind'] != null &&
        !{'salary', 'advance', 'payment', 'salaryPayment'}.contains(p['kind'])) {
      return 'invalid work record kind';
    }
    if ((name == 'read_home_bill_payments' || name == 'delete_home_bill') &&
        p['billId'] == null && p['billTitle'] == null && p['id'] == null) {
      return 'missing bill';
    }
    if ((name == 'read_debt_payments' || name == 'delete_debt') &&
        p['debtId'] == null && p['counterparty'] == null && p['id'] == null) {
      return 'missing debt';
    }
    if (name == 'read_home_bill_payments' &&
        p['billTitle'] is String && (p['billTitle']! as String).trim().isEmpty) {
      return 'missing bill';
    }
    if (name == 'read_debt_payments' &&
        p['counterparty'] is String && (p['counterparty']! as String).trim().isEmpty) {
      return 'missing debt';
    }
    if (name == 'record_home_bill_payment' &&
        p['billTitle'] is String && (p['billTitle']! as String).trim().isEmpty) return 'missing bill';
    if (name == 'read_month_total' && !{'work','home','debts'}.contains(p['section'])) return 'invalid section';
    if (name == 'navigate_to_section' &&
        !{'dashboard','work','home','debts','ai','settings'}.contains(p['section'])) {
      return 'invalid navigation section';
    }
    if (name == 'save_home_expense' && p['categoryId'] == null && p['categoryName'] == null) return 'missing category';
    if (name == 'save_home_expense' && p['categoryName'] is String && (p['categoryName']! as String).trim().isEmpty) return 'missing category';
    if (name == 'save_home_category' && (p['name']! as String).trim().isEmpty) return 'missing category name';
    if (name == 'delete_home_category' && p['id'] == null && p['name'] == null) return 'missing category';
    if (name == 'delete_home_category' && p['name'] is String && (p['name']! as String).trim().isEmpty) return 'missing category';
    if ((name == 'save_home_expense' || name == 'save_home_bill' || name == 'save_debt' || name == 'save_work_entry' || name == 'record_home_bill_payment' || name == 'record_debt_payment' || name == 'save_work_home_transfer' || name == 'delete_home_expense' || name == 'delete_work_entry' || name == 'delete_work_home_transfer') && p['date'] is String && DateTime.tryParse(p['date']! as String) == null) return 'invalid date';
    if (name == 'save_home_expense' && p['date'] is String && (year != DateTime.parse(p['date']! as String).year || month != DateTime.parse(p['date']! as String).month)) return 'expense date and due month differ';
    if (const {'save_work_entry', 'save_home_bill', 'save_debt'}.contains(name) &&
        p['date'] is String && year is int && month is int) {
      final date = DateTime.parse(p['date']! as String);
      if (date.year != year || date.month != month) {
        return 'operation date and due month differ';
      }
    }
    if (name == 'save_work_home_transfer' && p['date'] is String && DateTime.tryParse(p['date']! as String) == null) return 'invalid date';
    if (name == 'save_debt' && (p['counterparty']! as String).trim().isEmpty) return 'missing counterparty';
    if (name == 'record_debt_payment' && p['debtId'] == null && p['counterparty'] == null) return 'missing debt';
    if (name == 'record_debt_payment' && p['counterparty'] is String && (p['counterparty']! as String).trim().isEmpty) return 'missing debt';
    if (name == 'record_debt_payment' && p['direction'] != null && !{'creditor','debtor'}.contains(p['direction'])) return 'invalid debt direction';
    return null;
  }
  Future<ActionExecution> execute(String name, Map<String,Object?> p) async {
    final error = validate(name,p); if (error != null) throw ArgumentError(error);
    switch(name) {
      case 'read_home_categories':
        final categories = await _categories.getAll();
        return ActionExecution(
          message: categories.map((category) =>
            '${category.id}: ${_categoryLabel(category)}'
          ).join('؛ '),
        );
      case 'save_home_category':
        final name = (p['name']! as String).trim();
        final id = (p['id'] as String?)?.trim().isNotEmpty == true
            ? (p['id']! as String).trim()
            : 'custom_${_id()}';
        final existing = (await _categories.getAll())
            .where((category) => category.id == id)
            .firstOrNull;
        final category = HomeExpenseCategory(id: id, name: name);
        await _categories.save(category);
        return ActionExecution(
          message: 'تم حفظ التصنيف: $name',
          undo: () async {
            if (existing == null) {
              await _categories.removeCustom(id);
            } else {
              await _categories.save(existing);
            }
          },
        );
      case 'delete_home_category':
        final allCategories = await _categories.getAll();
        final requestedId = p['id'] as String?;
        final requestedName = p['name'] as String?;
        final matches = allCategories.where((category) =>
          requestedId != null ? category.id == requestedId :
          (_normalizeCategoryText(_categoryLabel(category)) == _normalizeCategoryText(requestedName ?? '') ||
            _normalizeCategoryText(category.id) == _normalizeCategoryText(requestedName ?? ''))
        ).toList(growable: false);
        if (matches.length != 1) throw StateError(matches.isEmpty ? 'Category not found' : 'Category name is ambiguous');
        final existing = matches.single;
        final id = existing.id;
        await _categories.removeCustom(id);
        return ActionExecution(
          message: 'تم حذف التصنيف: ${_categoryLabel(existing)}',
          undo: () => _categories.save(existing),
        );
      case 'save_work_entry':
        final id = p['id'] as String? ?? _id();
        final all = await _work.watchEntries().first;
        WorkEntry? old; for(final e in all) { if(e.id == id) old=e; }
        final previous = old;
        final item = WorkEntry(id:id, kind:(p['kind'] == 'payment'
            ? WorkEntryKind.salaryPayment
            : WorkEntryKind.values.byName(p['kind']! as String)), amount:Money.fromMinorUnits(p['amountMinorUnits']! as int), dueMonth:MonthKey(year:p['year']! as int,month:p['month']! as int), recordedAt:p['date'] is String ? DateTime.parse(p['date']! as String) : previous?.recordedAt ?? DateTime.now(),note:p.containsKey('note') ? p['note'] as String? : previous?.note);
        await _work.saveEntry(item);
        return ActionExecution(message:'تم حفظ سجل العمل',undo:() async { if(previous==null) { await _work.deleteEntry(id); } else { await _work.saveEntry(previous); } });
      case 'delete_work_entry': {
        final requestedId = p['id'] as String?;
        final date = p['date'] is String ? DateTime.parse(p['date']! as String) : null;
        final month = p['year'] is int && p['month'] is int
            ? MonthKey(year: p['year']! as int, month: p['month']! as int)
            : null;
        final matches = (await _work.watchEntries().first).where((entry) {
          if (requestedId != null) return entry.id == requestedId;
          final requestedKind = p['kind'] as String?;
          final kindMatches = requestedKind == 'payment'
              ? entry.kind == WorkEntryKind.salaryPayment
              : entry.kind.name == requestedKind;
          if (!kindMatches) return false;
          if (p['amountMinorUnits'] is int &&
              entry.amount.minorUnits != p['amountMinorUnits']) return false;
          if (month != null && entry.dueMonth != month) return false;
          if (date != null) {
            final savedDate = entry.recordedAt.toLocal();
            if (savedDate.year != date.year ||
                savedDate.month != date.month ||
                savedDate.day != date.day) return false;
          }
          return true;
        }).toList(growable: false);
        if (matches.length != 1) {
          throw StateError(matches.isEmpty
              ? 'Work record not found'
              : 'More than one work record matches; specify the exact date or ID.');
        }
        final deleted = matches.single;
        await _work.deleteEntry(deleted.id);
        return ActionExecution(
          message: 'تم حذف سجل العمل',
          undo: () => _work.saveEntry(deleted),
        );
      }
      case 'save_home_expense':
        final id=p['id'] as String? ?? _id(); final all=await _home.watchAll().first; HomeExpense? old; for(final e in all) { if(e.id==id) old=e; }
        final previous = old;
        final availableCategories = await _categories.getAll();
        final requestedCategoryId = p['categoryId'] as String?;
        final requestedCategoryName = p['categoryName'] as String?;
        final selectedCategory = availableCategories.where((category) =>
          category.id == requestedCategoryId ||
          (requestedCategoryName != null &&
            _normalizeCategoryText(_categoryLabel(category)) == _normalizeCategoryText(requestedCategoryName))
        ).firstOrNull;
        if (selectedCategory == null) {
          throw StateError('The requested expense category does not exist.');
        }
        final expenseDate = DateTime.parse(p['date']! as String);
        final item=HomeExpense(id:id,amount:Money.fromMinorUnits(p['amountMinorUnits']! as int),categoryId:selectedCategory.id,expenseDate:expenseDate,dueMonth:MonthKey(year:expenseDate.year,month:expenseDate.month),note:p.containsKey('note') ? p['note'] as String? : previous?.note);
        await _home.save(item); return ActionExecution(message:'تم حفظ مصروف المنزل',undo:() async { if(previous==null) { await _home.delete(id); } else { await _home.save(previous); } });
      case 'delete_home_expense': {
        final requestedId = p['id'] as String?;
        final categoryId = p['categoryId'] as String?;
        final categoryName = p['categoryName'] as String?;
        final categories = await _categories.getAll();
        final category = categories.where((item) =>
          item.id == categoryId ||
          (categoryName != null &&
            _normalizeCategoryText(_categoryLabel(item)) ==
                _normalizeCategoryText(categoryName))
        ).firstOrNull;
        if (requestedId == null && category == null) {
          throw StateError('The requested expense category was not found.');
        }
        final date = p['date'] is String
            ? DateTime.parse(p['date']! as String)
            : null;
        final month = p['year'] is int && p['month'] is int
            ? MonthKey(year: p['year']! as int, month: p['month']! as int)
            : null;
        final matches = (await _home.watchAll().first).where((expense) {
          if (requestedId != null) return expense.id == requestedId;
          if (expense.categoryId != category!.id) return false;
          if (p['amountMinorUnits'] is int &&
              expense.amount.minorUnits != p['amountMinorUnits']) return false;
          if (month != null && expense.dueMonth != month) return false;
          if (date != null) {
            final savedDate = expense.expenseDate.toLocal();
            if (savedDate.year != date.year ||
                savedDate.month != date.month ||
                savedDate.day != date.day) return false;
          }
          return true;
        }).toList(growable: false);
        if (matches.length != 1) {
          throw StateError(matches.isEmpty
              ? 'Home expense not found'
              : 'More than one expense matches; specify the month/date or ID.');
        }
        final deleted = matches.single;
        await _home.delete(deleted.id);
        return ActionExecution(
          message: 'تم حذف مصروف المنزل',
          undo: () => _home.save(deleted),
        );
      }
      case 'save_home_bill':
        final id = p['id'] as String? ?? _id();
        final existing = (await _bills.getBills()).where((bill) => bill.id == id).firstOrNull;
        final bill = HomeBill(
          id: id,
          title: p['title']! as String,
          kind: HomeBillKind.values.byName(p['kind']! as String),
          amount: Money.fromMinorUnits(p['amountMinorUnits']! as int),
          dueMonth: MonthKey(year: p['year']! as int, month: p['month']! as int),
          dueDate: p['date'] is String ? DateTime.parse(p['date']! as String) : existing?.dueDate,
          note: p.containsKey('note') ? p['note'] as String? : existing?.note,
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
        final requestedId = (p['id'] ?? p['billId']) as String?;
        final requestedTitle = p['billTitle'] as String?;
        final matchingBills = (await _bills.getBills()).where((bill) =>
          requestedId != null ? bill.id == requestedId :
          _normalizeCategoryText(bill.title) == _normalizeCategoryText(requestedTitle ?? '')
        ).toList(growable: false);
        if (matchingBills.length != 1) throw StateError(matchingBills.isEmpty ? 'Home bill not found' : 'Bill title is ambiguous');
        final existing = matchingBills.single;
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
        final bills = await _bills.getBills();
        final requestedBillId = p['billId'] as String?;
        final requestedBillTitle = p['billTitle'] as String?;
        final matchingBills = bills.where((bill) =>
          requestedBillId != null
              ? bill.id == requestedBillId
              : _normalizeCategoryText(bill.title) == _normalizeCategoryText(requestedBillTitle ?? '')
        ).toList(growable: false);
        if (matchingBills.length != 1) {
          throw StateError(matchingBills.isEmpty
              ? 'The requested bill was not found.'
              : 'More than one bill has this name; select the exact bill first.');
        }
        final paidAt = p['date'] is String ? DateTime.parse(p['date']! as String) : DateTime.now();
        final payment = HomeBillPayment(
          id: _id(),
          billId: matchingBills.single.id,
          amount: Money.fromMinorUnits(p['amountMinorUnits']! as int),
          paidAt: paidAt,
          note: p['note'] as String?,
        );
        await _bills.recordPayment(payment);
        return ActionExecution(
          message: 'تم تسجيل دفعة الفاتورة',
          undo: () => _bills.undoPayment(payment.id),
        );
      case 'read_work_records': {
        final month = _listMonthFilter(p);
        final entries = (await _work.watchEntries().first).where((entry) =>
          month == null || entry.dueMonth == month
        ).toList(growable: false);
        if (entries.isEmpty) {
          return ActionExecution(message: month == null
              ? 'لا توجد سجلات عمل.'
              : 'لا توجد سجلات عمل لشهر $month.');
        }
        return ActionExecution(message: entries.map((entry) =>
          '${entry.id}: ${entry.kind.name}، ${entry.amount.minorUnits}، ${entry.dueMonth}، ${entry.recordedAt.toLocal().toIso8601String().split('T').first}${entry.note == null ? '' : '، ملاحظة: ${entry.note}'}'
        ).join('؛ '));
      }
      case 'read_home_expenses': {
        final month = _listMonthFilter(p);
        final labels = {for (final c in await _categories.getAll()) c.id: _categoryLabel(c)};
        final expenses = (await _home.watchAll().first).where((expense) =>
          month == null || expense.dueMonth == month
        ).toList(growable: false);
        if (expenses.isEmpty) {
          return ActionExecution(message: month == null
              ? 'لا توجد مصروفات منزلية.'
              : 'لا توجد مصروفات منزلية لشهر $month.');
        }
        return ActionExecution(message: expenses.map((expense) =>
          '${expense.id}: ${labels[expense.categoryId] ?? expense.categoryId}، ${expense.amount.minorUnits}، ${expense.expenseDate.toLocal().toIso8601String().split('T').first}${expense.note == null ? '' : '، ملاحظة: ${expense.note}'}'
        ).join('؛ '));
      }
      case 'read_debts': {
        final month = _listMonthFilter(p);
        final debts = (await _debts.watchAll().first).where((debt) =>
          month == null || debt.dueMonth == month
        ).toList(growable: false);
        if (debts.isEmpty) {
          return ActionExecution(message: month == null
              ? 'لا توجد ديون مسجلة.'
              : 'لا توجد ديون مسجلة لشهر $month.');
        }
        return ActionExecution(message: debts.map((debt) =>
          '${debt.id}: ${debt.direction.name}، ${debt.counterparty}، الأصل ${debt.originalAmount.minorUnits}، المتبقي ${debt.outstandingAmount.minorUnits}، ${debt.dueMonth}${debt.note == null ? '' : '، ملاحظة: ${debt.note}'}'
        ).join('؛ '));
      }
      case 'read_work_transfers': {
        final month = _listMonthFilter(p);
        final transfers = (await _work.watchTransfers().first).where((item) {
          if (month == null) return true;
          final date = item.transferredAt.toLocal();
          return date.year == month.year && date.month == month.month;
        }).toList(growable: false);
        if (transfers.isEmpty) {
          return ActionExecution(message: month == null
              ? 'لا توجد تحويلات إلى المنزل.'
              : 'لا توجد تحويلات إلى المنزل لشهر $month.');
        }
        return ActionExecution(message: transfers.map((item) =>
          '${item.id}: ${item.amount.minorUnits}، ${item.transferredAt.toLocal().toIso8601String().split('T').first}${item.note == null ? '' : '، ملاحظة: ${item.note}'}'
        ).join('؛ '));
      }
      case 'read_debt_payments': {
        final all = await _debts.watchAll().first;
        final id = (p['debtId'] ?? p['id']) as String?;
        final counterparty = p['counterparty'] as String?;
        final direction = p['direction'] as String?;
        final matching = all.where((debt) =>
          id != null ? debt.id == id :
          _normalizeCategoryText(debt.counterparty) == _normalizeCategoryText(counterparty ?? '') &&
          (direction == null || debt.direction.name == direction)
        ).toList(growable: false);
        if (matching.length != 1) {
          throw StateError(matching.isEmpty ? 'Debt not found.' : 'More than one debt matches this party.');
        }
        final payments = await _debts.watchPayments(matching.single.id).first;
        if (payments.isEmpty) return const ActionExecution(message: 'لا توجد دفعات مسجلة لهذا الدين.');
        return ActionExecution(message: payments.map((payment) =>
          '${payment.id}: ${payment.amount.minorUnits}، ${payment.paidAt.toLocal().toIso8601String().split('T').first}${payment.note == null ? '' : '، ملاحظة: ${payment.note}'}'
        ).join('؛ '));
      }
      case 'read_home_bill_payments': {
        final bills = await _bills.getBills();
        final id = (p['billId'] ?? p['id']) as String?;
        final title = p['billTitle'] as String?;
        final matching = bills.where((bill) =>
          id != null ? bill.id == id :
          _normalizeCategoryText(bill.title) == _normalizeCategoryText(title ?? '')
        ).toList(growable: false);
        if (matching.length != 1) {
          throw StateError(matching.isEmpty ? 'Bill not found.' : 'More than one bill matches this title.');
        }
        final payments = await _bills.paymentsFor(matching.single.id);
        if (payments.isEmpty) return const ActionExecution(message: 'لا توجد دفعات مسجلة لهذه الفاتورة.');
        return ActionExecution(message: payments.map((payment) =>
          '${payment.id}: ${payment.amount.minorUnits}، ${payment.paidAt.toLocal().toIso8601String().split('T').first}${payment.note == null ? '' : '، ملاحظة: ${payment.note}'}'
        ).join('؛ '));
      }
      case 'read_home_bills': {
        final month = _listMonthFilter(p);
        final bills = (await _bills.getBills()).where((bill) =>
          month == null || bill.dueMonth == month
        ).toList(growable: false);
        if (bills.isEmpty) {
          return ActionExecution(message: month == null
              ? 'لا توجد فواتير أو إيجارات مسجلة.'
              : 'لا توجد فواتير أو إيجارات مسجلة لشهر $month.');
        }
        final summary = bills.map((bill) =>
          '${bill.id}: ${bill.title} (${bill.kind.name}) (${bill.dueMonth}): الأصل ${bill.amount.minorUnits}، المدفوع ${bill.paidMinorUnits}، المتبقي ${bill.remainingMinorUnits}${bill.note == null ? '' : '، ملاحظة: ${bill.note}'}'
        ).join('؛ ');
        return ActionExecution(message: summary);
      }
      case 'save_work_home_transfer':
        final id=p['id'] as String? ?? _id(); final all=await _work.watchTransfers().first; WorkHomeTransfer? old; for(final e in all) { if(e.id==id) old=e; }
        final previous = old;
        final item=WorkHomeTransfer(id:id,amount:Money.fromMinorUnits(p['amountMinorUnits']! as int),transferredAt:p['date'] is String ? DateTime.parse(p['date']! as String) : DateTime.now(),note:p.containsKey('note') ? p['note'] as String? : previous?.note);
        await _work.saveTransfer(item); return ActionExecution(message:'تم تسجيل التحويل إلى المنزل',undo:() async { if(previous==null) { await _work.deleteTransfer(id); } else { await _work.saveTransfer(previous); } });
      case 'delete_work_home_transfer': {
        final requestedId = p['id'] as String?;
        final date = p['date'] is String ? DateTime.parse(p['date']! as String) : null;
        final month = p['year'] is int && p['month'] is int
            ? MonthKey(year: p['year']! as int, month: p['month']! as int)
            : null;
        final matches = (await _work.watchTransfers().first).where((item) {
          if (requestedId != null) return item.id == requestedId;
          if (item.amount.minorUnits != p['amountMinorUnits']) return false;
          final savedDate = item.transferredAt.toLocal();
          if (date != null &&
              (savedDate.year != date.year ||
                  savedDate.month != date.month ||
                  savedDate.day != date.day)) return false;
          if (month != null &&
              (savedDate.year != month.year || savedDate.month != month.month)) {
            return false;
          }
          return true;
        }).toList(growable: false);
        if (matches.length != 1) {
          throw StateError(matches.isEmpty
              ? 'Transfer not found'
              : 'More than one transfer matches; specify the exact date or ID.');
        }
        final deleted = matches.single;
        await _work.deleteTransfer(deleted.id);
        return ActionExecution(
          message: 'تم حذف التحويل',
          undo: () => _work.saveTransfer(deleted),
        );
      }
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
        final item=DebtEntry(id:id,direction:DebtDirection.values.byName(p['direction']! as String),originalAmount:amount,outstandingAmount:Money.fromMinorUnits(amount.minorUnits - paidTotal),dueMonth:MonthKey(year:p['year']! as int,month:p['month']! as int),createdAt:p['date'] is String ? DateTime.parse(p['date']! as String) : previous?.createdAt ?? DateTime.now(),counterparty:p['counterparty']! as String,note:p.containsKey('note') ? p['note'] as String? : previous?.note);
        await _debts.save(item); return ActionExecution(message:'تم حفظ الدين',undo:() async { if(previous==null) { await _debts.delete(id); } else { await _debts.save(previous); } });
      case 'delete_debt':
        final all=await _debts.watchAll().first;
        final requestedId = (p['id'] ?? p['debtId']) as String?;
        final counterparty = p['counterparty'] as String?;
        final direction = p['direction'] as String?;
        final matches = all.where((debt) =>
          requestedId != null ? debt.id == requestedId :
          _normalizeCategoryText(debt.counterparty) == _normalizeCategoryText(counterparty ?? '') &&
          (direction == null || debt.direction.name == direction)
        ).toList(growable: false);
        if(matches.length != 1) throw StateError(matches.isEmpty ? 'Debt not found' : 'Debt party is ambiguous');
        final deleted = matches.single; final payments=await _debts.watchPayments(deleted.id).first; await _debts.delete(deleted.id);
        return ActionExecution(message:'تم حذف الدين',undo:() async { await _debts.restoreDebt(deleted,payments); });
      case 'record_debt_payment':
        final allDebts = await _debts.watchAll().first;
        final requestedDebtId = p['debtId'] as String?;
        final requestedCounterparty = p['counterparty'] as String?;
        final requestedDirection = p['direction'] as String?;
        final matchingDebts = allDebts.where((debt) =>
          requestedDebtId != null
              ? debt.id == requestedDebtId
              : _normalizeCategoryText(debt.counterparty) == _normalizeCategoryText(requestedCounterparty ?? '') &&
                  (requestedDirection == null || debt.direction.name == requestedDirection)
        ).toList(growable: false);
        if (matchingDebts.length != 1) {
          throw StateError(matchingDebts.isEmpty
              ? 'The requested debt was not found.'
              : 'More than one debt matches this name; select the exact debt first.');
        }
        final payment = DebtPayment(
          id: _id(),
          debtId: matchingDebts.single.id,
          amount: Money.fromMinorUnits(p['amountMinorUnits']! as int),
          paidAt: p['date'] is String ? DateTime.parse(p['date']! as String) : DateTime.now(),
          note: p['note'] as String?,
        );
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
        final month = p['year'] == null
            ? (_selectedMonth ?? MonthKey(year: now.year, month: now.month))
            : MonthKey(year: p['year']! as int, month: p['month']! as int);
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
    'save_work_entry' => const {
      'kind': String, 'amountMinorUnits': int, 'year': int, 'month': int,
      'date': String, 'id': String, 'note': String,
    },
    'delete_work_entry' => const {
      'id': String, 'kind': String, 'amountMinorUnits': int,
      'year': int, 'month': int, 'date': String,
    },
    'delete_work_home_transfer' => const {
      'id': String, 'amountMinorUnits': int, 'date': String,
      'year': int, 'month': int,
    },
    'delete_home_expense' => const {
      'id': String, 'categoryId': String, 'categoryName': String,
      'amountMinorUnits': int, 'date': String, 'year': int, 'month': int,
    },
    'delete_debt' => const {
      'id': String, 'debtId': String, 'counterparty': String, 'direction': String,
    },
    'delete_home_category' => const {'id': String, 'name': String},
    'save_home_expense' => const {
      'amountMinorUnits': int, 'categoryId': String, 'categoryName': String,
      'date': String, 'year': int, 'month': int, 'id': String, 'note': String,
    },
    'save_home_category' => const {'name': String, 'id': String},
    'save_home_bill' => const {
      'title': String, 'kind': String, 'amountMinorUnits': int,
      'year': int, 'month': int, 'date': String, 'id': String, 'note': String,
    },
    'delete_home_bill' => const {'id': String, 'billId': String, 'billTitle': String},
    'record_home_bill_payment' => const {
      'billId': String, 'billTitle': String, 'amountMinorUnits': int,
      'date': String, 'note': String,
    },
    'read_home_bills' || 'read_work_records' || 'read_home_expenses' ||
    'read_debts' || 'read_work_transfers' => const {
      'year': int, 'month': int, 'allRecords': bool,
    },
    'read_home_categories' => const {},
    'read_debt_payments' => const {
      'debtId': String, 'id': String, 'counterparty': String, 'direction': String,
    },
    'read_home_bill_payments' => const {
      'billId': String, 'id': String, 'billTitle': String,
    },
    'save_work_home_transfer' => const {
      'amountMinorUnits': int, 'id': String, 'date': String, 'note': String,
    },
    'save_debt' => const {
      'amountMinorUnits': int, 'direction': String, 'counterparty': String,
      'year': int, 'month': int, 'date': String, 'id': String, 'note': String,
    },
    'record_debt_payment' => const {
      'debtId': String, 'counterparty': String, 'direction': String,
      'amountMinorUnits': int, 'date': String, 'note': String,
    },
    'read_work_remaining' || 'read_month_total' || 'read_dashboard_summary' ||
    'navigate_to_section' => const {'section': String, 'year': int, 'month': int},
    _ => const {},
  };
  MonthKey? _listMonthFilter(Map<String, Object?> parameters) {
    if (parameters['year'] is int && parameters['month'] is int) {
      return MonthKey(
        year: parameters['year']! as int,
        month: parameters['month']! as int,
      );
    }
    if (parameters['allRecords'] == true) return null;
    final now = DateTime.now();
    return _selectedMonth ?? MonthKey(year: now.year, month: now.month);
  }

  static String _categoryLabel(HomeExpenseCategory category) =>
      category.name.trim().isEmpty ? category.id : category.name.trim();

  static String _normalizeCategoryText(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _id()=>DateTime.now().microsecondsSinceEpoch.toString();
}