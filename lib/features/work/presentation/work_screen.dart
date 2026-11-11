import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  String _kindLabel(AppLocalizations strings, WorkEntryKind kind) =>
      switch (kind) {
        WorkEntryKind.salary => strings.salary,
        WorkEntryKind.advance => strings.advance,
        WorkEntryKind.payment => strings.payment,
      };

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    WorkEntry? existing,
  }) async {
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final due = TextEditingController(
      text:
          existing?.dueMonth.toString() ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    var kind = existing?.kind ?? WorkEntryKind.salary;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? strings.addEntry : strings.editRecord,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<WorkEntryKind>(
                  initialValue: kind,
                  decoration: InputDecoration(labelText: strings.entryType),
                  items: WorkEntryKind.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_kindLabel(strings, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => kind = value);
                    }
                  },
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.amountMinorUnits,
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
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                  final parsedAmount = int.tryParse(amount.text.trim());
                  final parts = due.text.trim().split('-');
                  final year = parts.length == 2
                      ? int.tryParse(parts[0])
                      : null;
                  final month = parts.length == 2
                      ? int.tryParse(parts[1])
                      : null;
                  if (parsedAmount == null ||
                      parsedAmount <= 0 ||
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
                        .read(workRepositoryProvider)
                        .saveEntry(
                          WorkEntry(
                            id:
                                existing?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            kind: kind,
                            amount: Money.fromMinorUnits(parsedAmount),
                            dueMonth: MonthKey(year: year, month: month),
                            recordedAt: existing?.recordedAt ?? DateTime.now(),
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
      amount.dispose();
      due.dispose();
      note.dispose();
    }
  }

  Future<void> _editTransfer(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    WorkHomeTransfer? existing,
  }) async {
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(strings.addTransfer),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.transferAmount,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  if (value == null || value <= 0) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref
                        .read(workRepositoryProvider)
                        .saveTransfer(
                          WorkHomeTransfer(
                            id:
                                existing?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            amount: Money.fromMinorUnits(value),
                            transferredAt:
                                existing?.transferredAt ?? DateTime.now(),
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
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> _deleteTransfer(
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
      await ref.read(workRepositoryProvider).deleteTransfer(id);
    }
  }

  Future<void> _deleteEntry(
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
      await ref.read(workRepositoryProvider).deleteEntry(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final entries = ref.watch(workEntriesProvider);
    final transfers = ref.watch(workTransfersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editEntry(context, ref, strings),
        tooltip: strings.addEntry,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(strings.entries, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          entries.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) => items.isEmpty
                ? Text(strings.noRecords)
                : Column(
                    children: [
                      for (final entry in items)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.work_outline),
                            title: Text(_kindLabel(strings, entry.kind)),
                            subtitle: Text(
                              '${strings.dueMonth}: ${entry.dueMonth}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.amount.minorUnits.toString()),
                                IconButton(
                                  tooltip: strings.editRecord,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editEntry(
                                    context,
                                    ref,
                                    strings,
                                    existing: entry,
                                  ),
                                ),
                                IconButton(
                                  tooltip: strings.deleteRecord,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteEntry(
                                    context,
                                    ref,
                                    strings,
                                    entry.id,
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(transfer.amount.minorUnits.toString()),
                                IconButton(
                                  tooltip: strings.editRecord,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editTransfer(
                                    context,
                                    ref,
                                    strings,
                                    existing: transfer,
                                  ),
                                ),
                                IconButton(
                                  tooltip: strings.deleteRecord,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteTransfer(
                                    context,
                                    ref,
                                    strings,
                                    transfer.id,
                                  ),
                                ),
                              ],
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
}
