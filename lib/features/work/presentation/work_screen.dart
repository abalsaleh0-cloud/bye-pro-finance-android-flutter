import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum WorkScreenMode { overview, records, transfers }

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.openManualEntry = false, this.mode = WorkScreenMode.overview, this.initialMonth, this.swipePage = false});

  final bool openManualEntry;
  final WorkScreenMode mode;
  final MonthKey? initialMonth;
  final bool swipePage;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  bool _manualEntryOpened = false;
  int _activePage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                  key: const Key('work-entry-amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.amountMinorUnits,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: due,
                  readOnly: true,
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
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    suffixIcon: calendarSuffix(context, recordedAt, strings, monthOnly: false),
                  ),
                ),
                TextField(
                  key: const Key('work-entry-note'),
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
      // Let the dialog route unmount its TextFields before disposing controllers.
      await WidgetsBinding.instance.endOfFrame;
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
                  readOnly: true,
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
      try {
        await ref.read(workRepositoryProvider).deleteTransfer(id);
      } on TransferWouldOverdrawHomeException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.workRecordDeleteBlocked)),
          );
        }
      } on InsufficientWorkBalanceException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.workRecordDeleteBlocked)),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.dataError)),
          );
        }
      }
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
      try {
        await ref.read(workRepositoryProvider).deleteEntry(id);
      } on InsufficientWorkBalanceException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.workRecordDeleteBlocked)),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.dataError)),
          );
        }
      }
    }
  }

  Widget _workSummaryCard(
    BuildContext context,
    AppLocalizations strings,
    List<WorkEntry> entries,
    List<WorkHomeTransfer> transfers,
    MonthKey currentMonth,
  ) {
    final monthEntries = entries.where((entry) => entry.dueMonth == currentMonth);
    var salary = 0;
    var advances = 0;
    final allocation = WorkBalanceAllocation.calculate(entries);
    var payments = 0;
    final salaryPaymentsApplied = allocation.paymentsFor(currentMonth);
    for (final entry in monthEntries) {
      switch (entry.kind) {
        case WorkEntryKind.salary:
          salary += entry.amount.minorUnits;
        case WorkEntryKind.advance:
          advances += entry.amount.minorUnits;
        case WorkEntryKind.salaryPayment:
          payments += entry.amount.minorUnits;
      }
    }
    final transferred = transfers.where((item) {
      final date = item.transferredAt.toLocal();
      return date.year == currentMonth.year && date.month == currentMonth.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final receivedCash = entries.where((entry) =>
      entry.kind != WorkEntryKind.salary && entry.dueMonth == currentMonth,
    ).fold<int>(0, (sum, entry) => sum + entry.amount.minorUnits);
    final rows = <(String, int)>[
      (strings.salaryTotal, salary),
      (strings.advancesTotal, advances),
      (strings.paymentsTotal, payments),
      (strings.salaryPaymentsApplied, salaryPaymentsApplied),
      (strings.transferredToHome, transferred),
      (strings.currentSalaryOutstanding, allocation.outstandingFor(currentMonth)),
      (strings.workRemaining, receivedCash - transferred),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentMonth.toString(), style: Theme.of(context).textTheme.titleMedium),
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


  Widget _buildSwipeShell(AppLocalizations strings) {
    final pages = <WorkScreenMode>[
      WorkScreenMode.overview,
      WorkScreenMode.transfers,
      WorkScreenMode.records,
    ];
    final labels = [strings.work, strings.transfers, strings.entries];

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < labels.length; index++)
                  InkWell(
                    key: Key('work-tab-$index'),
                    onTap: () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[index],
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _activePage == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: _activePage == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2,
                            width: _activePage == index ? 30 : 0,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          child: PageView(
            key: const Key('work-section-pages'),
            controller: _pageController,
            onPageChanged: (index) => setState(() => _activePage = index),
            children: [
              for (final mode in pages)
                WorkScreen(
                  mode: mode,
                  openManualEntry: mode == WorkScreenMode.overview && widget.openManualEntry,
                  initialMonth: ref.read(selectedMonthProvider),
                  swipePage: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    if (!widget.swipePage && widget.mode == WorkScreenMode.overview) {
      return _buildSwipeShell(strings);
    }
    final entries = ref.watch(workEntriesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final allMonths = <MonthKey>{
      currentMonth,
      selectedMonth,
      ...(entries.value ?? const <WorkEntry>[]).map((entry) => entry.dueMonth),
      ...(transfers.value ?? const <WorkHomeTransfer>[]).map((transfer) {
        final date = transfer.transferredAt.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
    }.toList()..sort((a, b) => b.compareTo(a));
    final overview = widget.mode == WorkScreenMode.overview;
    final records = widget.mode == WorkScreenMode.records;
    final transferPage = widget.mode == WorkScreenMode.transfers;
    return Scaffold(
      appBar: overview || widget.swipePage ? null : AppBar(title: Text(records ? strings.entries : strings.transfers)),
      floatingActionButton: overview
          ? FloatingActionButton(onPressed: () => _editEntry(context, ref, strings), tooltip: strings.addEntry, child: const Icon(Icons.add))
          : transferPage
              ? FloatingActionButton(onPressed: () => _editTransfer(context, ref, strings), tooltip: strings.addTransfer, child: const Icon(Icons.add))
              : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<MonthKey>(
          key: const Key('work-selected-month-picker'),
          initialValue: selectedMonth,
          decoration: InputDecoration(labelText: strings.currentMonth),
          items: allMonths.map((month) => DropdownMenuItem(value: month, child: Text(month.toString()))).toList(),
          onChanged: (month) {
            if (month != null) {
              ref.read(selectedMonthProvider.notifier).select(month);
            }
          },
        ),
        const SizedBox(height: 12),
        if (overview) ...[
          _workSummaryCard(context, strings, entries.value ?? const [], transfers.value ?? const [], selectedMonth),
          const SizedBox(height: 16),
        ],
        if (records) ...[
          Text(strings.entries, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          entries.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) {
              final monthItems = items.where((entry) => entry.dueMonth == selectedMonth).toList();
              return monthItems.isEmpty ? Text(strings.noRecords) : Column(children: [
                for (final entry in monthItems)
                  Card(child: ListTile(
                    leading: const Icon(Icons.work_outline),
                    title: Text(_kindLabel(strings, entry.kind)),
                    subtitle: Text([
                      '${entry.kind == WorkEntryKind.salaryPayment ? strings.paymentReceivedMonth : strings.dueMonth}: ${entry.dueMonth}',
                      '${strings.recordedAt}: ${formatCalendarDate(entry.recordedAt)}',
                      if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(entry.amount.minorUnits.toString()),
                      IconButton(tooltip: strings.editRecord, icon: const Icon(Icons.edit_outlined), onPressed: () => _editEntry(context, ref, strings, existing: entry)),
                      IconButton(tooltip: strings.deleteRecord, icon: const Icon(Icons.delete_outline), onPressed: () => _deleteEntry(context, ref, strings, entry.id)),
                    ]),
                  )),
              ]);
            },
          ),
        ],
        if (transferPage) ...[
          transfers.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) {
              final monthItems = items.where((transfer) {
                final date = transfer.transferredAt.toLocal();
                return date.year == selectedMonth.year && date.month == selectedMonth.month;
              }).toList();
              return monthItems.isEmpty ? Text(strings.noRecords) : Column(children: [
                for (final transfer in monthItems)
                  Card(child: ListTile(
                    leading: const Icon(Icons.swap_horiz), title: Text(strings.transferredToHome),
                    subtitle: Text([
                      formatCalendarDate(transfer.transferredAt),
                      if (transfer.note != null && transfer.note!.isNotEmpty) transfer.note!,
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(transfer.amount.minorUnits.toString()),
                      IconButton(tooltip: strings.editRecord, icon: const Icon(Icons.edit_outlined), onPressed: () => _editTransfer(context, ref, strings, existing: transfer)),
                      IconButton(tooltip: strings.deleteRecord, icon: const Icon(Icons.delete_outline), onPressed: () => _deleteTransfer(context, ref, strings, transfer.id)),
                    ]),
                  )),
              ]);
            },
          ),
        ],
      ]),
    );
  }
}
