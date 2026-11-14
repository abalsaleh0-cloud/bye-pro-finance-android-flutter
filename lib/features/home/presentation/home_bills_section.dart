import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/widgets/entry_form_dialog.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class HomeBillsSection extends ConsumerWidget {
  const HomeBillsSection({super.key, this.selectedMonth});

  final MonthKey? selectedMonth;

  Future<void> _addBill(BuildContext context, WidgetRef ref, AppLocalizations strings, HomeBillKind kind, {HomeBill? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final amount = TextEditingController(text: existing?.amount.minorUnits.toString() ?? '');
    final month = TextEditingController(text: existing?.dueMonth.toString() ?? (selectedMonth ?? MonthKey(year: DateTime.now().year, month: DateTime.now().month)).toString());
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => EntryFormDialog(
        title: Text(existing != null ? strings.editRecord : kind == HomeBillKind.rent ? strings.addRent : strings.addMonthlyBill),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: InputDecoration(labelText: strings.billName)),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: strings.billAmount, suffixIcon: calculatorSuffix(context, amount, strings))),
          TextField(controller: month, readOnly: true, decoration: InputDecoration(labelText: strings.dueMonth, hintText: 'YYYY-MM', suffixIcon: calendarSuffix(context, month, strings, monthOnly: true))),
          TextField(controller: note, decoration: InputDecoration(labelText: strings.note)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(strings.cancel)),
          FilledButton(onPressed: () async {
            final value = int.tryParse(amount.text.trim());
            final parts = month.text.trim().split('-');
            final year = parts.length == 2 ? int.tryParse(parts[0]) : null;
            final monthValue = parts.length == 2 ? int.tryParse(parts[1]) : null;
            if (title.text.trim().isEmpty || value == null || value <= 0 || year == null || year < 1 || monthValue == null || monthValue < 1 || monthValue > 12) {
              setState(() => error = strings.invalidRecord);
              return;
            }
            try {
              await ref.read(homeBillRepositoryProvider).saveBill(HomeBill(
                id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                title: title.text.trim(),
                kind: existing?.kind ?? kind,
                amount: Money.fromMinorUnits(value),
                dueMonth: MonthKey(year: year, month: monthValue),
                note: note.text.trim().isEmpty ? null : note.text.trim(),
              ));
              ref.invalidate(homeBillsProvider);
              ref.invalidate(homeBillPaymentsForMonthProvider);
              ref.invalidate(homeBillOutstandingAsOfMonthProvider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setState(() => error = strings.invalidRecord);
            }
          }, child: Text(strings.save)),
        ],
      )),
    );
    title.dispose(); amount.dispose(); month.dispose(); note.dispose();
  }

  Future<void> _payBill(BuildContext context, WidgetRef ref, AppLocalizations strings, HomeBill bill) async {
    final amount = TextEditingController();
    final paidAt = TextEditingController(text: formatCalendarDate(DateTime.now()));
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => EntryFormDialog(
        title: Text(strings.addBillPayment),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${strings.billRemaining}: ${bill.remainingMinorUnits}'),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: strings.paymentAmount, suffixIcon: calculatorSuffix(context, amount, strings))),
          TextField(controller: paidAt, readOnly: true, decoration: InputDecoration(labelText: strings.paidAt, suffixIcon: calendarSuffix(context, paidAt, strings, monthOnly: false))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(strings.cancel)),
          FilledButton(onPressed: () async {
            final value = int.tryParse(amount.text.trim());
            final paymentDate = DateTime.tryParse(paidAt.text.trim());
            if (value == null || value <= 0 || value > bill.remainingMinorUnits || paymentDate == null) {
              setState(() => error = strings.billPaymentTooLarge);
              return;
            }
            try {
              await ref.read(homeBillRepositoryProvider).recordPayment(HomeBillPayment(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                billId: bill.id,
                amount: Money.fromMinorUnits(value),
                paidAt: paymentDate,
              ));
              ref.invalidate(homeBillsProvider);
              ref.invalidate(
                homeBillPaymentsForMonthProvider(
                  MonthKey(year: paymentDate.year, month: paymentDate.month),
                ),
              );
              ref.invalidate(homeBillOutstandingAsOfMonthProvider);
              ref.invalidate(allHomeBillPaymentsProvider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } on InsufficientBillPaymentBalanceException catch (exception) {
              setState(() => error = strings.insufficientHomeBalance(exception.availableMinorUnits.toString(), value.toString()));
            } catch (_) {
              setState(() => error = strings.billPaymentTooLarge);
            }
          }, child: Text(strings.save)),
        ],
      )),
    );
    amount.dispose();
    paidAt.dispose();
  }

  Future<void> _deleteBill(BuildContext context, WidgetRef ref, AppLocalizations strings, HomeBill bill) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteRecord),
        content: Text(strings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await ref.read(homeBillRepositoryProvider).deleteBill(bill.id);
      ref.invalidate(homeBillsProvider);
      ref.invalidate(homeBillPaymentsForMonthProvider);
      ref.invalidate(homeBillOutstandingAsOfMonthProvider);
    } on BillHasPaymentHistoryException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.billDeleteHasPayments)),
      );
    }
  }

  Future<void> _showHistory(BuildContext context, WidgetRef ref, AppLocalizations strings, HomeBill bill) async {
    final payments = await ref.read(homeBillRepositoryProvider).paymentsFor(bill.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${strings.billHistory}: ${bill.title}'),
        content: SizedBox(width: double.maxFinite, child: payments.isEmpty
          ? Text(strings.noRecords)
          : ListView(shrinkWrap: true, children: payments.map((payment) => ListTile(
              title: Text(payment.amount.minorUnits.toString()),
              subtitle: Text(formatCalendarDate(payment.paidAt)),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.cancel))],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final bills = ref.watch(homeBillsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(strings.monthlyBills, style: Theme.of(context).textTheme.titleMedium)),
        IconButton(tooltip: strings.addMonthlyBill, onPressed: () => _addBill(context, ref, strings, HomeBillKind.monthly), icon: const Icon(Icons.add)),
        IconButton(tooltip: strings.addRent, onPressed: () => _addBill(context, ref, strings, HomeBillKind.rent), icon: const Icon(Icons.home_work_outlined)),
      ]),
      bills.when(
        loading: () => Text(strings.loading),
        error: (error, stack) => Text(strings.dataError),
        data: (items) {
          final monthItems = selectedMonth == null
              ? items
              : items.where((bill) => bill.dueMonth == selectedMonth).toList();
          return monthItems.isEmpty
          ? Text(strings.noBills)
          : Column(children: monthItems.map((bill) {
              final status = bill.isSettled ? strings.billStatusPaid : bill.paidMinorUnits > 0 ? strings.billStatusPartial : strings.billStatusUnpaid;
              return Card(child: ListTile(
                leading: Icon(bill.kind == HomeBillKind.rent ? Icons.home_outlined : Icons.receipt_long_outlined),
                title: Text(bill.title),
                subtitle: Text([
                  '${bill.kind == HomeBillKind.rent ? strings.rent : strings.monthlyBills} • ${bill.dueMonth} • $status',
                  '${strings.billPaid}: ${bill.paidMinorUnits} / ${bill.amount.minorUnits} • ${strings.billRemaining}: ${bill.remainingMinorUnits}',
                  if (bill.note != null && bill.note!.trim().isNotEmpty) bill.note!.trim(),
                ].join('\n')),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'pay') {
                      _payBill(context, ref, strings, bill);
                    } else if (value == 'history') {
                      _showHistory(context, ref, strings, bill);
                    } else if (value == 'edit') {
                      _addBill(context, ref, strings, bill.kind, existing: bill);
                    } else if (value == 'delete') {
                      _deleteBill(context, ref, strings, bill);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!bill.isSettled)
                      PopupMenuItem(value: 'pay', child: Text(strings.payBill)),
                    PopupMenuItem(value: 'history', child: Text(strings.billHistory)),
                    PopupMenuItem(value: 'edit', child: Text(strings.editRecord)),
                    PopupMenuItem(value: 'delete', child: Text(strings.deleteRecord)),
                  ],
                ),
              ));
            }).toList());
        },
      ),
    ]);
  }
}
