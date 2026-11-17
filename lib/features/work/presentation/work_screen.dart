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
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum WorkScreenMode { overview, records, transfers }

enum WorkQuickAction { salary, payment, advance, transfer }

final workQuickActionProvider =
    NotifierProvider<WorkQuickActionNotifier, WorkQuickAction?>(
  WorkQuickActionNotifier.new,
);

class WorkQuickActionNotifier extends Notifier<WorkQuickAction?> {
  @override
  WorkQuickAction? build() => null;

  void request(WorkQuickAction action) => state = action;

  void clear() => state = null;
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

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    WorkEntry? existing,
    WorkEntryKind? initialKind,
  }) async {
    final selectedMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final defaultDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      now.day > lastDay ? lastDay : now.day,
    );
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final recordedAt = TextEditingController(
      text: formatCalendarDate(existing?.recordedAt ?? defaultDate),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final kind = existing?.kind ?? initialKind ?? WorkEntryKind.salary;
    final title = switch (kind) {
      WorkEntryKind.salary => strings.addSalaryAction,
      WorkEntryKind.salaryPayment => strings.addPaymentAction,
      WorkEntryKind.advance => strings.addAdvanceAction,
    };
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
            title: Text(existing == null ? title : strings.editRecord),
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: recordedAt,
                  builder: (context, value, child) {
                    final date = DateTime.tryParse(value.text);
                    if (date == null) return const SizedBox.shrink();
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          top: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context).formatFullDate(date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  },
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
                  final dueMonth = existing != null &&
                          formatCalendarDate(recordedDate) ==
                              formatCalendarDate(existing.recordedAt)
                      ? existing.dueMonth
                      : MonthKey(
                          year: recordedDate.year,
                          month: recordedDate.month,
                        );
                  try {
                    await ref.read(workRepositoryProvider).saveEntry(
                          WorkEntry(
                            id: existing?.id ??
                                DateTime.now().microsecondsSinceEpoch.toString(),
                            kind: kind,
                            amount: Money.fromMinorUnits(parsedAmount),
                            dueMonth: dueMonth,
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
    final now = DateTime.now();
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final defaultTransferDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      now.day > lastDay ? lastDay : now.day,
    );
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: transferredAt,
                  builder: (context, value, child) {
                    final date = DateTime.tryParse(value.text);
                    if (date == null) return const SizedBox.shrink();
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          top: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context).formatFullDate(date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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


  Widget _workActionGrid(AppLocalizations strings) {
    final tokens = AppDesignTokens.of(context);
    Widget actionCard({
      required String key,
      required String title,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key(key),
          onTap: onTap,
          child: SizedBox(
            height: 108,
            child: Padding(
              padding: EdgeInsets.all(tokens.cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: tokens.standardIconSize + 6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: tokens.sectionSpacing,
      mainAxisSpacing: tokens.sectionSpacing,
      childAspectRatio: 1.55,
      children: [
        actionCard(
          key: 'work-add-salary',
          title: strings.addSalaryAction,
          icon: Icons.payments_outlined,
          onTap: () => _editEntry(
            context,
            ref,
            strings,
            initialKind: WorkEntryKind.salary,
          ),
        ),
        actionCard(
          key: 'work-add-payment',
          title: strings.addPaymentAction,
          icon: Icons.receipt_long_outlined,
          onTap: () => _editEntry(
            context,
            ref,
            strings,
            initialKind: WorkEntryKind.salaryPayment,
          ),
        ),
        actionCard(
          key: 'work-add-advance',
          title: strings.addAdvanceAction,
          icon: Icons.request_quote_outlined,
          onTap: () => _editEntry(
            context,
            ref,
            strings,
            initialKind: WorkEntryKind.advance,
          ),
        ),
        actionCard(
          key: 'work-add-home-transfer',
          title: strings.transferToHomeAction,
          icon: Icons.swap_horiz_rounded,
          onTap: () => _editTransfer(context, ref, strings),
        ),
      ],
    );
  }

  Widget _buildHistory(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    List<WorkEntry> entries,
    List<WorkHomeTransfer> transfers,
    MonthKey selectedMonth,
  ) {
    final history = <_WorkHistoryRecord>[
      for (final entry in entries.where((entry) {
        final date = entry.recordedAt.toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _WorkHistoryRecord(
          date: entry.recordedAt,
          title: _kindLabel(strings, entry.kind),
          amount: entry.amount.minorUnits,
          note: entry.note,
          icon: switch (entry.kind) {
            WorkEntryKind.salary => Icons.payments_outlined,
            WorkEntryKind.advance => Icons.request_quote_outlined,
            WorkEntryKind.salaryPayment => Icons.receipt_long_outlined,
          },
          entry: entry,
        ),
      for (final transfer in transfers.where((transfer) {
        final date = transfer.transferredAt.toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _WorkHistoryRecord(
          date: transfer.transferredAt,
          title: strings.transferredToHome,
          amount: transfer.amount.minorUnits,
          note: transfer.note,
          icon: Icons.swap_horiz_rounded,
          transfer: transfer,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(strings.noRecords)),
      );
    }

    return Column(
      children: [
        for (final record in history)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FinancialRecordCard(
              icon: record.icon,
              title: record.title,
              amount: record.amount.toString(),
              details: [
                MaterialLocalizations.of(context).formatFullDate(
                  record.date.toLocal(),
                ),
                if (record.note != null && record.note!.isNotEmpty)
                  record.note!,
              ],
              actions: record.entry != null
                  ? [
                      IconButton(
                        tooltip: strings.editRecord,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editEntry(
                          context,
                          ref,
                          strings,
                          existing: record.entry,
                        ),
                      ),
                      IconButton(
                        tooltip: strings.deleteRecord,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteEntry(
                          context,
                          ref,
                          strings,
                          record.entry!.id,
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
                          existing: record.transfer,
                        ),
                      ),
                      IconButton(
                        tooltip: strings.deleteRecord,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTransfer(
                          context,
                          ref,
                          strings,
                          record.transfer!.id,
                        ),
                      ),
                    ],
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeShell(AppLocalizations strings) {
    final pages = <WorkScreenMode>[
      WorkScreenMode.overview,
      WorkScreenMode.transfers,
      WorkScreenMode.records,
    ];
    final labels = [strings.work, strings.workTransfers, strings.workHistory];

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
    final tokens = AppDesignTokens.of(context);
    if (!widget.swipePage && widget.mode == WorkScreenMode.overview) {
      ref.listen<WorkQuickAction?>(workQuickActionProvider, (previous, action) {
        if (action == null) return;
        ref.read(workQuickActionProvider.notifier).clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (action) {
            case WorkQuickAction.salary:
              _editEntry(context, ref, strings, initialKind: WorkEntryKind.salary);
              break;
            case WorkQuickAction.payment:
              _editEntry(context, ref, strings, initialKind: WorkEntryKind.salaryPayment);
              break;
            case WorkQuickAction.advance:
              _editEntry(context, ref, strings, initialKind: WorkEntryKind.advance);
              break;
            case WorkQuickAction.transfer:
              _editTransfer(context, ref, strings);
              break;
          }
        });
      });
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
          _workActionGrid(strings),
          SizedBox(height: tokens.sectionSpacing),
          _workSummaryCard(
            context,
            strings,
            entries.value ?? const [],
            transfers.value ?? const [],
            selectedMonth,
          ),
          const SizedBox(height: 16),
        ],
        if (records) ...[
          entries.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (entryItems) => transfers.when(
              loading: () => Text(strings.loading),
              error: (error, stackTrace) => Text(strings.dataError),
              data: (transferItems) => _buildHistory(
                context,
                ref,
                strings,
                entryItems,
                transferItems,
                selectedMonth,
              ),
            ),
          ),
        ],
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


final class _WorkHistoryRecord {
  const _WorkHistoryRecord({
    required this.date,
    required this.title,
    required this.amount,
    required this.icon,
    this.note,
    this.entry,
    this.transfer,
  });

  final DateTime date;
  final String title;
  final int amount;
  final IconData icon;
  final String? note;
  final WorkEntry? entry;
  final WorkHomeTransfer? transfer;
}
