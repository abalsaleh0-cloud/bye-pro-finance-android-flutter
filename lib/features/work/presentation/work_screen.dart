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
import 'package:expense_app/features/work/presentation/work_add_request_provider.dart';
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
  String _searchQuery = '';
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
        if (mounted) {
          _showAddActionPicker(context, ref, AppLocalizations.of(context)!);
        }
      });
    }
  }

  bool _matchesSearch({
    required String title,
    required int amount,
    required DateTime date,
    String? note,
  }) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = '$title ${note ?? ''} $amount ${date.toIso8601String()}';
    return searchable.toLowerCase().contains(query);
  }

  Widget _searchField(AppLocalizations strings) => TextField(
        key: const Key('work-record-search'),
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: strings.searchRecords,
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: strings.clearSearch,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
        ),
      );

  String _kindLabel(AppLocalizations strings, WorkEntryKind kind) =>
      switch (kind) {
        WorkEntryKind.salary => strings.salary,
        WorkEntryKind.advance => strings.advance,
        WorkEntryKind.salaryPayment => strings.payment,
      };


  String _addKindLabel(AppLocalizations strings, WorkEntryKind kind) =>
      switch (kind) {
        WorkEntryKind.salary => strings.addSalary,
        WorkEntryKind.advance => strings.addAdvance,
        WorkEntryKind.salaryPayment => strings.addPayment,
      };

  DateTime _defaultSelectedDate() {
    final selectedMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    return DateTime(
      selectedMonth.year,
      selectedMonth.month,
      now.day > lastDay ? lastDay : now.day,
    );
  }

  Future<void> _showAddActionPicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final action = await showModalBottomSheet<WorkQuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              key: const Key('work-add-action-salary'),
              leading: const Icon(Icons.payments_outlined),
              title: Text(strings.addSalary),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.salary),
            ),
            ListTile(
              key: const Key('work-add-action-payment'),
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(strings.addPayment),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.payment),
            ),
            ListTile(
              key: const Key('work-add-action-advance'),
              leading: const Icon(Icons.request_quote_outlined),
              title: Text(strings.addAdvance),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.advance),
            ),
              ListTile(
                key: const Key('work-add-action-transfer'),
                leading: const Icon(Icons.swap_horiz),
                title: Text(strings.transferredToHome),
                onTap: () => Navigator.pop(sheetContext, WorkQuickAction.transfer),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case WorkQuickAction.salary:
        await _editEntry(context, ref, strings, kind: WorkEntryKind.salary);
        break;
      case WorkQuickAction.payment:
        await _editEntry(context, ref, strings, kind: WorkEntryKind.salaryPayment);
        break;
      case WorkQuickAction.advance:
        await _editEntry(context, ref, strings, kind: WorkEntryKind.advance);
        break;
      case WorkQuickAction.transfer:
        await _editTransfer(context, ref, strings);
        break;
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    WorkEntryKind kind = WorkEntryKind.salary,
    WorkEntry? existing,
  }) async {
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final recordedAt = TextEditingController(
      text: formatCalendarDate(existing?.recordedAt ?? _defaultSelectedDate()),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final entryKind = existing?.kind ?? kind;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
            title: Text(
              existing == null ? _addKindLabel(strings, entryKind) : strings.editRecord,
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
                      context, recordedAt, strings, monthOnly: false,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  if (parsedAmount == null || parsedAmount <= 0 || recordedDate == null) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref.read(workRepositoryProvider).saveEntry(
                      WorkEntry(
                        id: existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        kind: entryKind,
                        amount: Money.fromMinorUnits(parsedAmount),
                        // Selected operation date defines the allocated month.
                        dueMonth: MonthKey(
                          year: recordedDate.year,
                          month: recordedDate.month,
                        ),
                        recordedAt: recordedDate,
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
    final defaultTransferDate = _defaultSelectedDate();
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
                  key: const Key('work-transfer-amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.calculatorAmount,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  key: const Key('work-transfer-date'),
                  controller: transferredAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    suffixIcon: calendarSuffix(context, transferredAt, strings, monthOnly: false),
                  ),
                ),
                TextField(
                  key: const Key('work-transfer-note'),
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
      // Wait until the dialog route detaches its TextFields before disposing
      // the controllers, matching the work-entry form lifecycle.
      await WidgetsBinding.instance.endOfFrame;
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



  Widget _buildSwipeShell(AppLocalizations strings) {
    final pages = <WorkScreenMode>[
      WorkScreenMode.overview,
      WorkScreenMode.transfers,
      WorkScreenMode.records,
    ];
    final labels = [strings.work, strings.workTransfersTab, strings.entries];

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
    ref.listen<int>(workAddRequestProvider, (previous, next) {
      if (widget.swipePage ||
          widget.mode != WorkScreenMode.overview ||
          next <= (previous ?? 0)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddActionPicker(context, ref, strings);
      });
    });
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
        if (!records)
          MonthSelector(
            pickerKey: const Key('work-selected-month-picker'),
            selectedMonth: selectedMonth,
            availableMonths: allMonths,
            onChanged: (month) =>
                ref.read(selectedMonthProvider.notifier).select(month),
          ),
        SizedBox(height: tokens.sectionSpacing * 0.67),
        if (records || transferPage) _searchField(strings),
        if (overview) ...[
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
          if (entries.isLoading || transfers.isLoading)
            Text(strings.loading)
          else if (entries.hasError || transfers.hasError)
            Text(strings.dataError)
          else
            Builder(
              builder: (context) {
                final logItems = <_WorkLogItem>[
                  for (final entry in entries.value ?? const <WorkEntry>[])
                    _WorkLogItem(
                        date: entry.recordedAt,
                        title: _kindLabel(strings, entry.kind),
                        amount: entry.amount.minorUnits,
                        icon: switch (entry.kind) {
                          WorkEntryKind.salary => Icons.payments_outlined,
                          WorkEntryKind.advance => Icons.request_quote_outlined,
                          WorkEntryKind.salaryPayment => Icons.receipt_long_outlined,
                        },
                        note: entry.note,
                        entry: entry,
                      ),
                  for (final transfer in transfers.value ?? const <WorkHomeTransfer>[])
                    _WorkLogItem(
                        date: transfer.transferredAt,
                        title: strings.transferredToHome,
                        amount: transfer.amount.minorUnits,
                        icon: Icons.swap_horiz,
                        note: transfer.note,
                        transfer: transfer,
                      ),
                ]..sort((left, right) => right.date.compareTo(left.date));

                final filteredLogItems = logItems.where((item) => _matchesSearch(
                  title: item.title, amount: item.amount, date: item.date, note: item.note,
                )).toList();
                if (filteredLogItems.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text(strings.noRecords)),
                  );
                }

                return Column(
                  children: [
                    for (final item in filteredLogItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FinancialRecordCard(
                          icon: item.icon,
                          title: item.title,
                          amount: formatMinorUnits(context, item.amount),
                          details: [
                            toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(item.date)),
                            if (item.note != null && item.note!.isNotEmpty) item.note!,
                          ],
                          actions: [
                            if (item.entry != null) ...[
                              IconButton(
                                tooltip: strings.editRecord,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editEntry(
                                  context, ref, strings, existing: item.entry,
                                ),
                              ),
                              IconButton(
                                tooltip: strings.deleteRecord,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteEntry(
                                  context, ref, strings, item.entry!.id,
                                ),
                              ),
                            ],
                            if (item.transfer != null) ...[
                              IconButton(
                                tooltip: strings.editRecord,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editTransfer(
                                  context, ref, strings, existing: item.transfer,
                                ),
                              ),
                              IconButton(
                                tooltip: strings.deleteRecord,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteTransfer(
                                  context, ref, strings, item.transfer!.id,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
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
                return date.year == selectedMonth.year &&
                    date.month == selectedMonth.month;
              }).where((transfer) => _matchesSearch(
                title: strings.transferredToHome,
                amount: transfer.amount.minorUnits,
                date: transfer.transferredAt,
                note: transfer.note,
              )).toList();
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
                        amount: formatMinorUnits(context, transfer.amount.minorUnits),
                        details: [
                          toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(transfer.transferredAt)),
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

class _WorkLogItem {
  const _WorkLogItem({
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
