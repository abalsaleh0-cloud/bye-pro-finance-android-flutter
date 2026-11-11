import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  Future<void> _editDebt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    DebtEntry? existing,
  }) async {
    final counterparty = TextEditingController(text: existing?.counterparty ?? '');
    final original = TextEditingController(
      text: existing?.originalAmount.minorUnits.toString() ?? '',
    );
    final outstanding = TextEditingController(
      text: existing?.outstandingAmount.minorUnits.toString() ?? '',
    );
    final due = TextEditingController(
      text: existing?.dueMonth.toString() ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    var direction = existing?.direction ?? DebtDirection.debtor;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? strings.addDebt : strings.editRecord),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DebtDirection>(
                    initialValue: direction,
                    decoration: InputDecoration(labelText: strings.debtDirection),
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
                      if (value != null) setDialogState(() => direction = value);
                    },
                  ),
                  TextField(
                    controller: counterparty,
                    decoration: InputDecoration(labelText: strings.counterparty),
                  ),
                  TextField(
                    controller: original,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: strings.originalAmount),
                  ),
                  TextField(
                    controller: outstanding,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: strings.outstandingAmount),
                  ),
                  TextField(
                    controller: due,
                    decoration: InputDecoration(
                      labelText: strings.dueMonth,
                      hintText: 'YYYY-MM',
                    ),
                  ),
                  TextField(
                    controller: note,
                    decoration: InputDecoration(labelText: strings.note),
                  ),
                  if (error != null)
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  final outstandingValue = int.tryParse(outstanding.text.trim());
                  final parts = due.text.trim().split('-');
                  final year = parts.length == 2 ? int.tryParse(parts[0]) : null;
                  final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
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
                    await ref.read(debtRepositoryProvider).save(
                      DebtEntry(
                        id: existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        direction: direction,
                        originalAmount: Money.fromMinorUnits(originalValue),
                        outstandingAmount: Money.fromMinorUnits(outstandingValue),
                        dueMonth: MonthKey(year: year, month: month),
                        createdAt: existing?.createdAt ?? DateTime.now(),
                        counterparty: counterparty.text.trim(),
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
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
    final note = TextEditingController();
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(strings.recordDebtPayment),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${strings.outstandingAmount}: ${debt.outstandingAmount.minorUnits}'),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.paymentAmount),
                ),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  if (value == null || value <= 0 ||
                      value > debt.outstandingAmount.minorUnits) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref.read(debtRepositoryProvider).recordPayment(
                      DebtPayment(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        debtId: debt.id,
                        amount: Money.fromMinorUnits(value),
                        paidAt: DateTime.now(),
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
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
      amount.dispose();
      note.dispose();
    }
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
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editDebt(context, ref, strings),
        tooltip: strings.addDebt,
        child: const Icon(Icons.add),
      ),
      body: debts.when(
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
                            leading: const Icon(Icons.account_balance_wallet_outlined),
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
                                  onPressed: () => _recordPayment(context, ref, strings, debt),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: Text(strings.recordDebtPayment),
                                )
                              else
                                Text(strings.settled),
                              IconButton(
                                tooltip: strings.editRecord,
                                onPressed: () => _editDebt(
                                  context, ref, strings, existing: debt,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: strings.deleteRecord,
                                onPressed: () => _deleteDebt(
                                  context, ref, strings, debt.id,
                                ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(strings.paymentHistory),
                          Consumer(
                            builder: (context, ref, child) {
                              final payments = ref.watch(debtPaymentsProvider(debt.id));
                              return payments.when(
                                loading: () => Text(strings.loading),
                                error: (error, stackTrace) => Text(strings.dataError),
                                data: (history) => history.isEmpty
                                    ? Text(strings.noRecords)
                                    : Column(
                                        children: [
                                          for (final payment in history)
                                            ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.receipt_long_outlined),
                                              title: Text(payment.amount.minorUnits.toString()),
                                              subtitle: Text(
                                                '${strings.paidAt}: ${payment.paidAt.toLocal().toString().split(' ').first}'
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
      ),
    );
  }
}
