import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/widgets/entry_form_dialog.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/core/widgets/section_pill_tabs.dart';
import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_balance_allocation.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/features/work/presentation/work_quick_action.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum WorkScreenMode { overview, records, transfers }

enum _WorkTimelineType { salary, payment, advance, transfer }

class _WorkTimelineItem {
  const _WorkTimelineItem._({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    this.entry,
    this.transfer,
  });

  factory _WorkTimelineItem.fromEntry(WorkEntry entry) {
    final type = switch (entry.kind) {
      WorkEntryKind.salary => _WorkTimelineType.salary,
      WorkEntryKind.salaryPayment => _WorkTimelineType.payment,
      WorkEntryKind.advance => _WorkTimelineType.advance,
    };
    return _WorkTimelineItem._(
      id: entry.id,
      type: type,
      amount: entry.amount,
      date: entry.recordedAt,
      note: entry.note,
      entry: entry,
    );
  }

  factory _WorkTimelineItem.fromTransfer(WorkHomeTransfer transfer) {
    return _WorkTimelineItem._(
      id: transfer.id,
      type: _WorkTimelineType.transfer,
      amount: transfer.amount,
      date: transfer.transferredAt,
      note: transfer.note,
      transfer: transfer,
    );
  }

  final String id;
  final _WorkTimelineType type;
  final Money amount;
  final DateTime date;
  final String? note;
  final WorkEntry? entry;
  final WorkHomeTransfer? transfer;
}

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

  String _entryActionLabel(AppLocalizations strings, WorkEntryKind kind) =>
      switch (kind) {
        WorkEntryKind.salary => strings.addSalary,
        WorkEntryKind.advance => strings.addAdvance,
        WorkEntryKind.salaryPayment => strings.addPayment,
      };

  IconData _timelineIcon(_WorkTimelineType type) => switch (type) {
    _WorkTimelineType.salary => Icons.payments_outlined,
    _WorkTimelineType.payment => Icons.receipt_long_outlined,
    _WorkTimelineType.advance => Icons.request_quote_outlined,
    _WorkTimelineType.transfer => Icons.swap_horiz_rounded,
  };

  String _timelineLabel(
    AppLocalizations strings,
    _WorkTimelineType type,
  ) => switch (type) {
    _WorkTimelineType.salary => strings.salary,
    _WorkTimelineType.payment => strings.payment,
    _WorkTimelineType.advance => strings.advance,
    _WorkTimelineType.transfer => strings.transferredToHome,
  };

  DateTime _defaultDateForSelectedMonth(MonthKey month) {
    final today = DateTime.now();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = today.day > lastDay ? lastDay : today.day;
    return DateTime(month.year, month.month, day);
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    required WorkEntryKind kind,
    WorkEntry? existing,
  }) async {
    final selectedKind = existing?.kind ?? kind;
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final recordedAt = TextEditingController(
      text: formatCalendarDate(
        existing?.recordedAt ??
            _defaultDateForSelectedMonth(ref.read(selectedMonthProvider)),
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
              existing == null
                  ? _entryActionLabel(strings, selectedKind)
                  : strings.editRecord,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('work-entry-amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.calculatorAmount,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  key: const Key('work-entry-date'),
                  controller: recordedAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    suffixIcon: calendarSuffix(
                      context,
                      recordedAt,
                      strings,
                      monthOnly: false,
                    ),
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
                  if (parsedAmount == null ||
                      parsedAmount <= 0 ||
                      recordedDate == null) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref.read(workRepositoryProvider).saveEntry(
                      WorkEntry(
                        id: existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        kind: selectedKind,
                        amount: Money.fromMinorUnits(parsedAmount),
                        dueMonth: MonthKey(
                          year: recordedDate.year,
                          month: recordedDate.month,
                        ),
                        recordedAt: recordedDate,
                        note: note.text.trim().isEmpty
                            ? null
                            : note.text.trim(),
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } on InsufficientWorkBalanceException {
                    setDialogState(() => error = strings.invalidRecord);
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
      // Wait for the dialog route to unmount its TextFields before disposal.
      await WidgetsBinding.instance.endOfFrame;
      amount.dispose();
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
    final selectedMonth = ref.read(selectedMonthProvider);
    final defaultTransferDate = _defaultDateForSelectedMonth(selectedMonth);
    final transferredAt = TextEditingController(
      text: formatCalendarDate(existing?.transferredAt ?? defaultTransferDate),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
            title: Text(strings.addTransfer),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.calculatorAmount,
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
                  } on InsufficientWorkBalanceException {
                    setDialogState(() => error = strings.invalidRecord);
                  } on TransferWouldOverdrawHomeException {
                    setDialogState(() => error = strings.invalidRecord);
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
      amount.dispose();
      transferredAt.dispose();
      note.dispose();
    }
  }

  Widget _buildRecordsList(
    BuildContext context,
    AppLocalizations strings,
    AsyncValue<List<WorkEntry>> entries,
    AsyncValue<List<WorkHomeTransfer>> transfers,
    MonthKey selectedMonth,
  ) {
    return entries.when(
      loading: () => Text(strings.loading),
      error: (error, stackTrace) => Text(strings.dataError),
      data: (entryItems) => transfers.when(
        loading: () => Text(strings.loading),
        error: (error, stackTrace) => Text(strings.dataError),
        data: (transferItems) {
          final allItems = <_WorkTimelineItem>[
            ...entryItems.map(_WorkTimelineItem.fromEntry),
            ...transferItems.map(_WorkTimelineItem.fromTransfer),
          ]..sort((a, b) => b.date.compareTo(a.date));
          final monthItems = allItems.where((item) {
            final date = item.date.toLocal();
            return date.year == selectedMonth.year &&
                date.month == selectedMonth.month;
          }).toList(growable: false);

          if (monthItems.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text(strings.noRecords)),
            );
          }

          return Column(
            children: [
              for (final item in monthItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FinancialRecordCard(
                    icon: _timelineIcon(item.type),
                    title: _timelineLabel(strings, item.type),
                    amount: item.amount.minorUnits.toString(),
                    details: [
                      '${strings.recordedAt}: ${MaterialLocalizations.of(context).formatFullDate(item.date.toLocal())}',
                      if (item.note != null && item.note!.isNotEmpty)
                        item.note!,
                    ],
                    actions: item.entry != null
                        ? [
                            IconButton(
                              tooltip: strings.editRecord,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editEntry(
                                context,
                                ref,
                                strings,
                                kind: item.entry!.kind,
                                existing: item.entry,
                              ),
                            ),
                            IconButton(
                              tooltip: strings.deleteRecord,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteEntry(
                                context,
                                ref,
                                strings,
                                item.id,
                              ),
                            ),
                          ]
                        : [
                            IconButton(
                              tooltip: strings.editRecord,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editTransfer(
                                context,
                                ref,
                                strings,
                                existing: item.transfer,
                              ),
                            ),
                            IconButton(
                              tooltip: strings.deleteRecord,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteTransfer(
                                context,
                                ref,
                                strings,
                                item.id,
                              ),
                            ),
                          ],
                  ),
                ),
            ],
          );
        },
      ),
    );
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
    final metrics = <SummaryMetricData>[
      SummaryMetricData(
        title: strings.salaryTotal,
        value: salary.toString(),
        icon: Icons.payments_outlined,
      ),
      SummaryMetricData(
        title: strings.advancesTotal,
        value: advances.toString(),
        icon: Icons.request_quote_outlined,
      ),
      SummaryMetricData(
        title: strings.paymentsTotal,
        value: payments.toString(),
        icon: Icons.receipt_long_outlined,
      ),
      SummaryMetricData(
        title: strings.salaryPaymentsApplied,
        value: salaryPaymentsApplied.toString(),
        icon: Icons.check_circle_outline,
      ),
      SummaryMetricData(
        title: strings.transferredToHome,
        value: transferred.toString(),
        icon: Icons.swap_horiz,
      ),
      SummaryMetricData(
        title: strings.currentSalaryOutstanding,
        value: allocation.outstandingFor(currentMonth).toString(),
        icon: Icons.account_balance_outlined,
        emphasized: true,
      ),
      SummaryMetricData(
        title: strings.workRemaining,
        value: (receivedCash - transferred).toString(),
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];
    return SummaryMetricGrid(metrics: metrics);
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
        SectionPillTabs(
          keyPrefix: 'work-tab',
          labels: labels,
          selectedIndex: _activePage,
          onSelected: (index) => _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        ),
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
    if (!widget.swipePage) {
      ref.listen<WorkQuickAction?>(workQuickActionProvider, (previous, next) {
        if (next == null) return;
        ref.read(workQuickActionProvider.notifier).clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (next) {
            case WorkQuickAction.salary:
              _editEntry(
                context,
                ref,
                strings,
                kind: WorkEntryKind.salary,
              );
            case WorkQuickAction.payment:
              _editEntry(
                context,
                ref,
                strings,
                kind: WorkEntryKind.salaryPayment,
              );
            case WorkQuickAction.advance:
              _editEntry(
                context,
                ref,
                strings,
                kind: WorkEntryKind.advance,
              );
            case WorkQuickAction.transfer:
              _editTransfer(context, ref, strings);
          }
        });
      });
    }
    final tokens = AppDesignTokens.of(context);
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
      body: ListView(padding: tokens.pageInsets(), children: [
        MonthSelector(
          pickerKey: const Key('work-selected-month-picker'),
          selectedMonth: selectedMonth,
          availableMonths: allMonths,
          onChanged: (month) =>
              ref.read(selectedMonthProvider.notifier).select(month),
        ),
        SizedBox(height: tokens.sectionSpacing * 0.67),
        if (overview) ...[
          _workSummaryCard(context, strings, entries.value ?? const [], transfers.value ?? const [], selectedMonth),
          const SizedBox(height: 16),
        ],
        if (records)
          _buildRecordsList(
            context,
            strings,
            entries,
            transfers,
            selectedMonth,
          ),
        if (transferPage) ...[
          transfers.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) {
              final monthItems = items.where((transfer) {
                final date = transfer.transferredAt.toLocal();
                return date.year == selectedMonth.year &&
                    date.month == selectedMonth.month;
              }).toList();
              if (monthItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(strings.noRecords)),
                );
              }
              return Column(
                children: [
                  for (final transfer in monthItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FinancialRecordCard(
                        icon: Icons.swap_horiz,
                        title: strings.transferredToHome,
                        amount: transfer.amount.minorUnits.toString(),
                        details: [
                          formatCalendarDate(transfer.transferredAt),
                          if (transfer.note != null && transfer.note!.isNotEmpty)
                            transfer.note!,
                        ],
                        actions: [
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
                ],
              );
            },
          ),
        ],
      ]),
    );
  }
}
