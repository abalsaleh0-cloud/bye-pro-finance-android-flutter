import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _editExpense(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    HomeExpense? existing,
  }) async {
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final category = TextEditingController(text: existing?.categoryId ?? '');
    final date = TextEditingController(
      text: _dateText(existing?.expenseDate ?? DateTime.now()),
    );
    final due = TextEditingController(
      text:
          existing?.dueMonth.toString() ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? strings.addExpense : strings.editRecord,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.amountMinorUnits,
                    ),
                  ),
                  TextField(
                    controller: category,
                    decoration: InputDecoration(labelText: strings.category),
                  ),
                  TextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: strings.expenseDate,
                      hintText: 'YYYY-MM-DD',
                    ),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final parsedAmount = int.tryParse(amount.text.trim());
                  final parsedDate = DateTime.tryParse(date.text.trim());
                  final dueParts = due.text.trim().split('-');
                  final year = dueParts.length == 2
                      ? int.tryParse(dueParts[0])
                      : null;
                  final month = dueParts.length == 2
                      ? int.tryParse(dueParts[1])
                      : null;
                  if (parsedAmount == null ||
                      parsedAmount <= 0 ||
                      category.text.trim().isEmpty ||
                      parsedDate == null ||
                      year == null ||
                      month == null ||
                      month < 1 ||
                      month > 12 ||
                      year < 1) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    final expense = HomeExpense(
                      id:
                          existing?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      amount: Money.fromMinorUnits(parsedAmount),
                      categoryId: category.text.trim(),
                      expenseDate: parsedDate,
                      dueMonth: MonthKey(year: year, month: month),
                      note: note.text.trim().isEmpty ? null : note.text.trim(),
                    );
                    await ref.read(homeExpenseRepositoryProvider).save(expense);
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
      category.dispose();
      date.dispose();
      due.dispose();
      note.dispose();
    }
  }

  Future<void> _deleteExpense(
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
    if (confirmed == true) {
      await ref.read(homeExpenseRepositoryProvider).delete(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final expenses = ref.watch(homeExpensesProvider);
    final transfers = ref.watch(workTransfersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editExpense(context, ref, strings),
        tooltip: strings.addExpense,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(strings.expenses, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          expenses.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) => items.isEmpty
                ? Text(strings.noRecords)
                : Column(
                    children: [
                      for (final expense in items)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(expense.categoryId),
                            subtitle: Text(
                              '${strings.dueMonth}: ${expense.dueMonth}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(expense.amount.minorUnits.toString()),
                                IconButton(
                                  tooltip: strings.editRecord,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editExpense(
                                    context,
                                    ref,
                                    strings,
                                    existing: expense,
                                  ),
                                ),
                                IconButton(
                                  tooltip: strings.deleteRecord,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteExpense(
                                    context,
                                    ref,
                                    strings,
                                    expense.id,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.transfers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          transfers.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) => items.isEmpty
                ? Text(strings.noRecords)
                : Column(
                    children: [
                      for (final transfer in items)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: Text(strings.transfers),
                            subtitle: Text(
                              transfer.transferredAt
                                  .toLocal()
                                  .toString()
                                  .split(' ')
                                  .first,
                            ),
                            trailing: Text(
                              transfer.amount.minorUnits.toString(),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _dateText(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
