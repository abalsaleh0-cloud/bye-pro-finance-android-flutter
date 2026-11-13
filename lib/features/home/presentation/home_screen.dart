import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/presentation/home_bills_section.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum HomeScreenMode { overview, transfers, dailyExpenses, monthlyBills }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.openManualEntry = false, this.mode = HomeScreenMode.overview, this.initialMonth, this.swipePage = false});

  final bool openManualEntry;
  final HomeScreenMode mode;
  final MonthKey? initialMonth;
  final bool swipePage;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
        if (mounted) _editExpense(context, ref, AppLocalizations.of(context)!);
      });
    }
  }

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
      text: formatCalendarDate(existing?.expenseDate ?? DateTime.now()),
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
                      suffixIcon: calculatorSuffix(context, amount, strings),
                    ),
                  ),
                  TextField(
                    controller: category,
                    decoration: InputDecoration(labelText: strings.category),
                  ),
                  TextField(
                    controller: date,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: strings.expenseDate,
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: calendarSuffix(context, date, strings, monthOnly: false),
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
                  } on InsufficientHomeBalanceException catch (exception) {
                    setDialogState(
                      () => error = strings.insufficientHomeBalance(
                        exception.availableMinorUnits.toString(),
                        exception.requestedMinorUnits.toString(),
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

  Widget _homeSummaryCard(
    BuildContext context,
    AppLocalizations strings,
    List<HomeExpense> expenses,
    List<WorkHomeTransfer> transfers,
    List<HomeBill> bills,
    MonthKey month,
    int billPaymentsThisMonth,
  ) {
    final expenseTotal = expenses.where((item) {
      final date = item.expenseDate.toLocal();
      return date.year == month.year && date.month == month.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final transferTotal = transfers.where((item) {
      final date = item.transferredAt.toLocal();
      return date.year == month.year && date.month == month.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final outstandingBills = bills.where((bill) => bill.dueMonth == month)
      .fold<int>(0, (sum, bill) => sum + bill.remainingMinorUnits);
    // Reserve unpaid bills as well as amounts already paid this month.
    // A partially paid bill is therefore counted exactly once in total.
    final availableBalance =
        transferTotal - expenseTotal - billPaymentsThisMonth - outstandingBills;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(month.toString(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: Text(strings.totalExpenses)), Text(expenseTotal.toString())]),
            const SizedBox(height: 6),
            Row(children: [Expanded(child: Text(strings.receivedFromWork)), Text(transferTotal.toString())]),
            const SizedBox(height: 6),
            Row(children: [Expanded(child: Text(strings.totalBillsOutstanding)), Text(outstandingBills.toString())]),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text(strings.homeAvailableBalance)),
                Text(
                  availableBalance.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSwipeShell(AppLocalizations strings) {
    final pages = <HomeScreenMode>[
      HomeScreenMode.overview,
      HomeScreenMode.transfers,
      HomeScreenMode.dailyExpenses,
      HomeScreenMode.monthlyBills,
    ];
    final labels = [
      strings.homeSection,
      strings.receivedFromWork,
      strings.dailyExpenses,
      strings.monthlyBills,
    ];

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
                    key: Key('home-tab-$index'),
                    onTap: () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
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
            key: const Key('home-section-pages'),
            controller: _pageController,
            onPageChanged: (index) => setState(() => _activePage = index),
            children: [
              for (final mode in pages)
                HomeScreen(
                  mode: mode,
                  openManualEntry: mode == HomeScreenMode.overview && widget.openManualEntry,
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
    if (!widget.swipePage && widget.mode == HomeScreenMode.overview) {
      return _buildSwipeShell(strings);
    }
    final expenses = ref.watch(homeExpensesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final bills = ref.watch(homeBillsProvider);
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final billPayments = ref.watch(homeBillPaymentsForMonthProvider(selectedMonth));
    final availableMonths = <MonthKey>{
      currentMonth,
      selectedMonth,
      ...(expenses.value ?? const <HomeExpense>[]).map((item) => item.dueMonth),
      ...(expenses.value ?? const <HomeExpense>[]).map((item) {
        final date = item.expenseDate.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
      ...(bills.value ?? const <HomeBill>[]).map((item) => item.dueMonth),
      ...(transfers.value ?? const <WorkHomeTransfer>[]).map((item) {
        final date = item.transferredAt.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
    }.toList()..sort((a, b) => b.compareTo(a));
    final overview = widget.mode == HomeScreenMode.overview;
    final transferPage = widget.mode == HomeScreenMode.transfers;
    final expensePage = widget.mode == HomeScreenMode.dailyExpenses;
    final billsPage = widget.mode == HomeScreenMode.monthlyBills;
    final pageTitle = transferPage ? strings.receivedFromWork : expensePage ? strings.dailyExpenses : strings.monthlyBills;
    return Scaffold(
      appBar: overview || widget.swipePage ? null : AppBar(title: Text(pageTitle)),
      floatingActionButton: expensePage
          ? FloatingActionButton(onPressed: () => _editExpense(context, ref, strings), tooltip: strings.addExpense, child: const Icon(Icons.add))
          : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<MonthKey>(
          initialValue: selectedMonth,
          decoration: InputDecoration(labelText: strings.currentMonth),
          items: availableMonths.map((month) => DropdownMenuItem(value: month, child: Text(month.toString()))).toList(),
          onChanged: (month) {
            if (month != null) {
              ref.read(selectedMonthProvider.notifier).select(month);
            }
          },
        ),
        const SizedBox(height: 12),
        if (overview) ...[
          _homeSummaryCard(context, strings, expenses.value ?? const [], transfers.value ?? const [], bills.value ?? const [], selectedMonth, billPayments.value ?? 0),
          const SizedBox(height: 16),
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
                    leading: const Icon(Icons.swap_horiz), title: Text(strings.receivedFromWork),
                    subtitle: Text([
                      formatCalendarDate(transfer.transferredAt),
                      if (transfer.note != null && transfer.note!.isNotEmpty) transfer.note!,
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: Text(transfer.amount.minorUnits.toString()),
                  )),
              ]);
            },
          ),
        ],
        if (expensePage) ...[
          expenses.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (items) {
              final monthItems = items.where((expense) {
                final date = expense.expenseDate.toLocal();
                return date.year == selectedMonth.year && date.month == selectedMonth.month;
              }).toList();
              return monthItems.isEmpty ? Text(strings.noRecords) : Column(children: [
                for (final expense in monthItems)
                  Card(child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined), title: Text(expense.categoryId),
                    subtitle: Text([
                      '${strings.expenseDate}: ${formatCalendarDate(expense.expenseDate)}',
                      if (expense.note != null && expense.note!.isNotEmpty) expense.note!,
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(expense.amount.minorUnits.toString()),
                      IconButton(tooltip: strings.editRecord, icon: const Icon(Icons.edit_outlined), onPressed: () => _editExpense(context, ref, strings, existing: expense)),
                      IconButton(tooltip: strings.deleteRecord, icon: const Icon(Icons.delete_outline), onPressed: () => _deleteExpense(context, ref, strings, expense.id)),
                    ]),
                  )),
              ]);
            },
          ),
        ],
        if (billsPage) HomeBillsSection(selectedMonth: selectedMonth),
      ]),
    );
  }
}
