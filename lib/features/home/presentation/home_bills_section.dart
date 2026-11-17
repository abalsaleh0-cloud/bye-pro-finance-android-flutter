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
  const HomeBillsSection({
    super.key,
    this.selectedMonth,
    this.kindFilter,
  });

  final MonthKey? selectedMonth;
  final HomeBillKind? kindFilter;

  Future<void> _addBill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    HomeBillKind kind, {
    HomeBill? existing,
  }) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final selected = selectedMonth ??
        MonthKey(year: DateTime.now().year, month: DateTime.now().month);
    final now = DateTime.now();
    final lastDay = DateTime(selected.year, selected.month + 1, 0).day;
    final defaultDate = DateTime(
      selected.year,
      selected.month,
      now.day > lastDay ? lastDay : now.day,
    );
    final date = TextEditingController(
      text: formatCalendarDate(
        existing?.dueDate ??
            DateTime(
              existing?.dueMonth.year ?? defaultDate.year,
              existing?.dueMonth.month ?? defaultDate.month,
              existing?.dueDate?.day ?? defaultDate.day,
            ),
      ),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
            title: Text(
              existing != null
                  ? strings.editRecord
                  : kind == HomeBillKind.rent
                      ? strings.addMonthlyRent
                      : strings.addInvoice,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: kind == HomeBillKind.rent
                        ? strings.homeBillOrRentName
                        : strings.billName,
                  ),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.billAmount,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: date,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.homeBillDate,
                    suffixIcon: calendarSuffix(
                      context,
                      date,
                      strings,
                      monthOnly: false,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: date,
                  builder: (context, value, child) {
                    final pickedDate = DateTime.tryParse(value.text);
                    if (pickedDate == null) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          top: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(pickedDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  },
                ),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  final dueDate = DateTime.tryParse(date.text.trim());
                  if (title.text.trim().isEmpty ||
                      value == null ||
                      value <= 0 ||
                      dueDate == null) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref.read(homeBillRepositoryProvider).saveBill(
                          HomeBill(
                            id: existing?.id ??
                                DateTime.now().microsecondsSinceEpoch.toString(),
                            title: title.text.trim(),
                            kind: existing?.kind ?? kind,
                            amount: Money.fromMinorUnits(value),
                            dueMonth: MonthKey(
                              year: dueDate.year,
                              month: dueDate.month,
                            ),
                            dueDate: dueDate,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    ref.invalidate(homeBillsProvider);
                    ref.invalidate(homeBillPaymentsForMonthProvider);
                    ref.invalidate(homeBillOutstandingAsOfMonthProvider);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } on InsufficientBillPaymentBalanceException catch (
                    exception
                  ) {
                    setDialogState(
                      () => error = strings.insufficientHomeBalance(
                        exception.availableMinorUnits.toString(),
                        value.toString(),
                      ),
                    );
                  } catch (_) {
                    setDialogState(() => error = strings.invalidRecord);
                  }
                },
                child: Text(strings.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      title.dispose();
      amount.dispose();
      date.dispose();
      note.dispose();
    }
  }

  Future<void> showAddBill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    HomeBillKind kind,
  ) {
    return _addBill(context, ref, strings, kind);
  }

  Future<void> _payBill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    HomeBill bill,
  ) async {
    final amount = TextEditingController();
    final paidAt = TextEditingController(
      text: formatCalendarDate(DateTime.now()),
    );
    final note = TextEditingController();
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
            title: Text(strings.addBillPayment),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('\${strings.billRemaining}: \${bill.remainingMinorUnits}'),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.paymentAmount,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: paidAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.paidAt,
                    suffixIcon: calendarSuffix(
                      context,
                      paidAt,
                      strings,
                      monthOnly: false,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: paidAt,
                  builder: (context, value, child) {
                    final pickedDate = DateTime.tryParse(value.text);
                    if (pickedDate == null) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          top: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(pickedDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  },
                ),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  final paymentDate = DateTime.tryParse(paidAt.text.trim());
                  if (value == null ||
                      value <= 0 ||
                      value > bill.remainingMinorUnits ||
                      paymentDate == null) {
                    setDialogState(
                      () => error = strings.billPaymentTooLarge,
                    );
                    return;
                  }
                  try {
                    await ref.read(homeBillRepositoryProvider).recordPayment(
                          HomeBillPayment(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            billId: bill.id,
                            amount: Money.fromMinorUnits(value),
                            paidAt: paymentDate,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    ref.invalidate(homeBillsProvider);
                    ref.invalidate(
                      homeBillPaymentsForMonthProvider(
                        MonthKey(
                          year: paymentDate.year,
                          month: paymentDate.month,
                        ),
                      ),
                    );
                    ref.invalidate(homeBillOutstandingAsOfMonthProvider);
                    ref.invalidate(allHomeBillPaymentsProvider);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } on InsufficientBillPaymentBalanceException catch (
                    exception
                  ) {
                    setDialogState(
                      () => error = strings.insufficientHomeBalance(
                        exception.availableMinorUnits.toString(),
                        value.toString(),
                      ),
                    );
                  } catch (_) {
                    setDialogState(
                      () => error = strings.billPaymentTooLarge,
                    );
                  }
                },
                child: Text(strings.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      amount.dispose();
      paidAt.dispose();
      note.dispose();
    }
  }

  Future<void> _deleteBill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    HomeBill bill,
  ) async {
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

  Future<void> _showHistory(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    HomeBill bill,
  ) async {
    final payments = await ref.read(homeBillRepositoryProvider).paymentsFor(
          bill.id,
        );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('\${strings.billHistory}: \${bill.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: payments.isEmpty
              ? Text(strings.noRecords)
              : ListView(
                  shrinkWrap: true,
                  children: payments
                      .map(
                        (payment) => ListTile(
                          title: Text(payment.amount.minorUnits.toString()),
                          subtitle: Text(
                            [
                              MaterialLocalizations.of(context)
                                  .formatFullDate(payment.paidAt.toLocal()),
                              if (payment.note != null &&
                                  payment.note!.trim().isNotEmpty)
                                payment.note!.trim(),
                            ].join(' • '),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final bills = ref.watch(homeBillsProvider);
    final sectionTitle = kindFilter == HomeBillKind.rent
        ? strings.monthlyRents
        : strings.monthlyBills;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        bills.when(
          loading: () => Text(strings.loading),
          error: (error, stack) => Text(strings.dataError),
          data: (items) {
            final filtered = items.where((bill) {
              if (kindFilter != null && bill.kind != kindFilter) return false;
              return selectedMonth == null || bill.dueMonth == selectedMonth;
            }).toList();
            if (filtered.isEmpty) {
              return Text(strings.noBills);
            }
            return Column(
              children: filtered.map((bill) {
                final status = bill.isSettled
                    ? strings.billStatusPaid
                    : bill.paidMinorUnits > 0
                        ? strings.billStatusPartial
                        : strings.billStatusUnpaid;
                final dueDate = bill.dueDate ??
                    DateTime(bill.dueMonth.year, bill.dueMonth.month, 1);
                return Card(
                  child: ListTile(
                    leading: Icon(
                      bill.kind == HomeBillKind.rent
                          ? Icons.home_work_outlined
                          : Icons.receipt_long_outlined,
                    ),
                    title: Text(bill.title),
                    subtitle: Text(
                      [
                        '\${MaterialLocalizations.of(context).formatFullDate(dueDate)} • $status',
                        '\${strings.billPaid}: \${bill.paidMinorUnits} / \${bill.amount.minorUnits} • \${strings.billRemaining}: \${bill.remainingMinorUnits}',
                        if (bill.note != null && bill.note!.trim().isNotEmpty)
                          bill.note!.trim(),
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pay') {
                          _payBill(context, ref, strings, bill);
                        } else if (value == 'history') {
                          _showHistory(context, ref, strings, bill);
                        } else if (value == 'edit') {
                          _addBill(
                            context,
                            ref,
                            strings,
                            bill.kind,
                            existing: bill,
                          );
                        } else if (value == 'delete') {
                          _deleteBill(context, ref, strings, bill);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!bill.isSettled)
                          PopupMenuItem(
                            value: 'pay',
                            child: Text(strings.payBill),
                          ),
                        PopupMenuItem(
                          value: 'history',
                          child: Text(strings.billHistory),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(strings.editRecord),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(strings.deleteRecord),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
