import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.openManualEntry = false});

  final bool openManualEntry;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  bool _manualEntryOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openManualEntry && !_manualEntryOpened) {
      _manualEntryOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editEntry(context, ref, AppLocalizations.of(context)!);
      });
    }
  }

  String _kindLabel(AppLocalizations strings, WorkEntryKind kind) =>
      switch (kind) {
        WorkEntryKind.salary => strings.salary,
        WorkEntryKind.advance => strings.advance,
        WorkEntryKind.payment => strings.payment,
        WorkEntryKind.salaryPayment => strings.payment,
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
    final recordedAt = TextEditingController(text: formatCalendarDate(existing?.recordedAt ?? DateTime.now()));
    final note = TextEditingController(text: existing?.note ?? '');
    var kind = existing?.kind ?? WorkEntryKind.salary;
    final selectableKinds = <WorkEntryKind>[
      WorkEntryKind.salary,
      WorkEntryKind.advance,
      WorkEntryKind.salaryPayment,
      if (existing?.kind == WorkEntryKind.payment) WorkEntryKind.payment,
    ];
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
                  items: selectableKinds
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
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: due,
                  decoration: InputDecoration(
                    labelText: kind == WorkEntryKind.salaryPayment
                        ? strings.paymentReceivedMonth
                        : strings.dueMonth,
                    hintText: 'YYYY-MM',
                    suffixIcon: calendarSuffix(context, due, strings, monthOnly: true),
                  ),
                ),
                TextField(
                  controller: recordedAt,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    suffixIcon: calendarSuffix(context, recordedAt, strings, monthOnly: false),
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
                  final recordedDate = DateTime.tryParse(recordedAt.text.trim());
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
                      month > 12 ||
                      recordedDate == null) {
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
                            recordedAt: recordedDate,
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
      recordedAt.dispose();
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
    final transferredAt = TextEditingController(text: formatCalendarDate(existing?.transferredAt ?? DateTime.now()));
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
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: transferredAt,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    suffixIcon: calendarSuffix(context, transferredAt, strings, monthOnly: false),
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
                  final transferDate = DateTime.tryParse(transferredAt.text.trim());
                  if (value == null || value <= 0 || transferDate == null) {
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
                            transferredAt: transferDate,
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
      transferredAt.dispose();
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

  Widget _workSummaryCard(
    BuildContext context,
    AppLocalizations strings,
    List<WorkEntry> entries,
    List<WorkHomeTransfer> transfers,
  ) {
    final now = DateTime.now();
    final monthEntries = entries.where((entry) =>
      entry.dueMonth.year == now.year && entry.dueMonth.month == now.month);
    var salary = 0;
    var advances = 0;
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final allocation = WorkBalanceAllocation.calculate(entries);
    var payments = 0;
    final salaryPaymentsApplied = allocation.paymentsFor(currentMonth);
    for (final entry in monthEntries) {
      switch (entry.kind) {
        case WorkEntryKind.salary:
          salary += entry.amount.minorUnits;
        case WorkEntryKind.advance:
          advances += entry.amount.minorUnits;
        case WorkEntryKind.payment:
        case WorkEntryKind.salaryPayment:
          payments += entry.amount.minorUnits;
      }
    }
    final transferred = transfers.where((item) {
      final date = item.transferredAt.toLocal();
      return date.year == now.year && date.month == now.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final rows = <(String, int)>[
      (strings.salaryTotal, salary),
      (strings.advancesTotal, advances),
      (strings.paymentsTotal, payments),
      (strings.salaryPaymentsApplied, salaryPaymentsApplied),
      (strings.transferredToHome, transferred),
      (strings.currentSalaryOutstanding, allocation.outstandingFor(currentMonth)),
      (strings.workRemaining, salary - advances - salaryPaymentsApplied - transferred),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.currentMonth, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [Expanded(child: Text(row.$1)), Text(row.$2.toString())],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          FilledButton.icon(
            onPressed: () => _editTransfer(context, ref, strings),
            icon: const Icon(Icons.swap_horiz),
            label: Text(strings.addTransfer),
          ),
          const SizedBox(height: 12),
          _workSummaryCard(context, strings, entries.value ?? const [], transfers.value ?? const []),
          const SizedBox(height: 16),
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
                              '${entry.kind == WorkEntryKind.salaryPayment ? strings.paymentReceivedMonth : strings.dueMonth}: ${entry.dueMonth}',
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
                            title: Text(strings.transferredToHome),
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
