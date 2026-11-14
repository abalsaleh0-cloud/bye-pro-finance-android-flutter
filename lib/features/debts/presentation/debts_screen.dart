import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key, this.openManualEntry = false});

  final bool openManualEntry;

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _manualEntryOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openManualEntry && !_manualEntryOpened) {
      _manualEntryOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editDebt(context, ref, AppLocalizations.of(context)!);
      });
    }
  }

  Future<void> _editDebt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    DebtEntry? existing,
  }) async {
    final counterparty = TextEditingController(
      text: existing?.counterparty ?? '',
    );
    final original = TextEditingController(
      text: existing?.originalAmount.minorUnits.toString() ?? '',
    );
    final outstanding = TextEditingController(
      text: existing?.outstandingAmount.minorUnits.toString() ?? '',
    );
    final due = TextEditingController(
      text:
          existing?.dueMonth.toString() ?? ref.read(selectedMonthProvider).toString(),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    var direction = existing?.direction ?? DebtDirection.debtor;
    String? error;
    try {
      await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? strings.addDebt : strings.editRecord,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DebtDirection>(
                    initialValue: direction,
                    decoration: InputDecoration(
                      labelText: strings.debtDirection,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: DebtDirection.creditor,
                        child: Text(strings.creditor),
                      ),
                      DropdownMenuItem(
                        value: DebtDirection.debtor,
                        child: Text(strings.debtor),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => direction = value);
                      }
                    },
                  ),
                  TextField(
                    controller: counterparty,
                    decoration: InputDecoration(
                      labelText: strings.counterparty,
                    ),
                  ),
                  TextField(
                    controller: original,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.originalAmount,
                      suffixIcon: calculatorSuffix(context, original, strings),
                    ),
                  ),
                  TextField(
                    controller: outstanding,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.outstandingAmount,
                      suffixIcon: calculatorSuffix(context, outstanding, strings),
                    ),
                  ),
                  TextField(
                    controller: due,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: strings.dueMonth,
                      hintText: 'YYYY-MM',
                      suffixIcon: calendarSuffix(context, due, strings, monthOnly: true),
                    ),
                  ),
                  TextField(
                    controller: note,
                    decoration: InputDecoration(labelText: strings.note),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final originalValue = int.tryParse(original.text.trim());
                  final outstandingValue = int.tryParse(
                    outstanding.text.trim(),
                  );
                  final parts = due.text.trim().split('-');
                  final year = parts.length == 2
                      ? int.tryParse(parts[0])
                      : null;
                  final month = parts.length == 2
                      ? int.tryParse(parts[1])
                      : null;
                  if (counterparty.text.trim().isEmpty ||
                      originalValue == null ||
                      originalValue <= 0 ||
                      outstandingValue == null ||
                      outstandingValue < 0 ||
                      outstandingValue > originalValue ||
                      year == null ||
                      year < 1 ||
                      month == null ||
                      month < 1 ||
                      month > 12) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref
                        .read(debtRepositoryProvider)
                        .save(
                          DebtEntry(
                            id:
                                existing?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            direction: direction,
                            originalAmount: Money.fromMinorUnits(originalValue),
                            outstandingAmount: Money.fromMinorUnits(
                              outstandingValue,
                            ),
                            dueMonth: MonthKey(year: year, month: month),
                            createdAt: existing?.createdAt ?? DateTime.now(),
                            counterparty: counterparty.text.trim(),
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
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
      counterparty.dispose();
      original.dispose();
      outstanding.dispose();
      due.dispose();
      note.dispose();
    }
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    DebtEntry debt,
  ) async {
    final amount = TextEditingController();
    final now = DateTime.now();
    final paidAt = TextEditingController(text: formatCalendarDate(now));
    var paymentTime = TimeOfDay.fromDateTime(now);
    final paidTime = TextEditingController(text: paymentTime.format(context));
    final note = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(strings.recordDebtPayment),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  '${strings.outstandingAmount}: ${debt.outstandingAmount.minorUnits}',
                ),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.paymentAmount, suffixIcon: calculatorSuffix(context, amount, strings)),
                ),
                TextField(
                  controller: paidAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.paidAt,
                    suffixIcon: calendarSuffix(context, paidAt, strings, monthOnly: false),
                  ),
                ),
                TextField(
                  controller: paidTime,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.time,
                    suffixIcon: IconButton(
                      tooltip: strings.time,
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final selectedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: paymentTime,
                        );
                        if (selectedTime == null || !dialogContext.mounted) {
                          return;
                        }
                        setDialogState(() {
                          paymentTime = selectedTime;
                          paidTime.text = selectedTime.format(dialogContext);
                        });
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  final paymentDay = DateTime.tryParse(paidAt.text.trim());
                  if (paymentDay == null || value == null ||
                      value <= 0 ||
                      value > debt.outstandingAmount.minorUnits) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    final paymentDate = DateTime(
                      paymentDay.year,
                      paymentDay.month,
                      paymentDay.day,
                      paymentTime.hour,
                      paymentTime.minute,
                    );
                    await ref
                        .read(debtRepositoryProvider)
                        .recordPayment(
                          DebtPayment(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            debtId: debt.id,
                            amount: Money.fromMinorUnits(value),
                            paidAt: paymentDate,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
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
  }

  Future<void> _deleteDebt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteRecord),
        content: Text(strings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(debtRepositoryProvider).delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editDebt(context, ref, strings),
        tooltip: strings.addDebt,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (debts.hasValue) _debtSummaryCard(context, strings, debts.value ?? const []),
          Expanded(child: debts.when(
        loading: () => Center(child: Text(strings.loading)),
        error: (error, stackTrace) => Center(child: Text(strings.dataError)),
        data: (items) => items.isEmpty
            ? Center(child: Text(strings.noRecords))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final debt = items[index];
                  final direction = debt.direction == DebtDirection.creditor
                      ? strings.creditor
                      : strings.debtor;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            title: Text('${debt.counterparty} • $direction'),
                            subtitle: Text(
                              '${strings.dueMonth}: ${debt.dueMonth}\n'
                              '${strings.originalAmount}: ${debt.originalAmount.minorUnits}\n'
                              '${strings.outstandingAmount}: ${debt.outstandingAmount.minorUnits}',
                            ),
                            isThreeLine: true,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (!debt.isSettled)
                                FilledButton.tonalIcon(
                                  onPressed: () => _recordPayment(
                                    context,
                                    ref,
                                    strings,
                                    debt,
                                  ),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: Text(strings.recordDebtPayment),
                                )
                              else
                                Text(strings.settled),
                              IconButton(
                                tooltip: strings.editRecord,
                                onPressed: () => _editDebt(
                                  context,
                                  ref,
                                  strings,
                                  existing: debt,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: strings.deleteRecord,
                                onPressed: () =>
                                    _deleteDebt(context, ref, strings, debt.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(strings.paymentHistory),
                          Consumer(
                            builder: (context, ref, child) {
                              final payments = ref.watch(
                                debtPaymentsProvider(debt.id),
                              );
                              return payments.when(
                                loading: () => Text(strings.loading),
                                error: (error, stackTrace) =>
                                    Text(strings.dataError),
                                data: (history) => history.isEmpty
                                    ? Text(strings.noRecords)
                                    : Column(
                                        children: [
                                          for (final payment in history)
                                            ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(
                                                Icons.receipt_long_outlined,
                                              ),
                                              title: Text(
                                                payment.amount.minorUnits
                                                    .toString(),
                                              ),
                                              subtitle: Text(
                                                '${strings.paidAt}: ${formatCalendarDate(payment.paidAt)}'
                                                '\n${strings.time}: ${TimeOfDay.fromDateTime(payment.paidAt).format(context)}'
                                                '${payment.note == null ? '' : '\n${payment.note}'}',
                                              ),
                                            ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      )),
        ],
      ),
    );
  }

  Widget _debtSummaryCard(BuildContext context, AppLocalizations strings, List<DebtEntry> items) {
    final creditor = items.where((item) => item.direction == DebtDirection.creditor)
      .fold<int>(0, (sum, item) => sum + item.outstandingAmount.minorUnits);
    final debtor = items.where((item) => item.direction == DebtDirection.debtor)
      .fold<int>(0, (sum, item) => sum + item.outstandingAmount.minorUnits);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [Expanded(child: Text(strings.totalCreditor)), Text(creditor.toString())]),
          const SizedBox(height: 6),
          Row(children: [Expanded(child: Text(strings.totalDebtor)), Text(debtor.toString())]),
        ]),
      ),
    );
  }
}
