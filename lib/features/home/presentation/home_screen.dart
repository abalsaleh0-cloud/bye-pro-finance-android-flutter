import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/widgets/entry_form_dialog.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';
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

  String _categoryLabel(AppLocalizations strings, HomeExpenseCategory category) {
    if (category.name.trim().isNotEmpty) return category.name;
    return switch (category.id) {
      'groceries' => strings.homeCategoryGroceries,
      'utilities' => strings.homeCategoryUtilities,
      'housing' => strings.homeCategoryHousing,
      'cleaning' => strings.homeCategoryCleaning,
      'maintenance' => strings.homeCategoryMaintenance,
      'transport' => strings.homeCategoryTransport,
      'personal' => strings.homeCategoryPersonal,
      'health' => strings.homeCategoryHealth,
      'other' => strings.homeCategoryOther,
      _ => category.id,
    };
  }


  HomeExpenseCategory _categoryForExpense(
    List<HomeExpenseCategory> categories,
    String categoryId,
  ) {
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return HomeExpenseCategory(id: categoryId, name: categoryId);
  }

  Future<String?> _askCategoryName(
    BuildContext context,
    AppLocalizations strings, {
    String initialName = '',
  }) async {
    final controller = TextEditingController(text: initialName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(initialName.isEmpty ? strings.addCategory : strings.editCategory),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: strings.categoryName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.pop(dialogContext, name);
              },
              child: Text(strings.save),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _manageCategories(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    var categories = await ref.read(homeExpenseCategoriesProvider.future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(strings.manageCategories),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final category in categories)
                        ListTile(
                          dense: true,
                          title: Text(_categoryLabel(strings, category)),
                          trailing: IconButton(
                            tooltip: strings.editCategory,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final name = await _askCategoryName(
                                context,
                                strings,
                                initialName: category.name.isEmpty
                                    ? _categoryLabel(strings, category)
                                    : category.name,
                              );
                              if (name == null) return;
                              try {
                                await ref.read(homeExpenseCategoryRepositoryProvider)
                                    .save(category.copyWith(name: name));
                                ref.invalidate(homeExpenseCategoriesProvider);
                                final refreshed = await ref.read(homeExpenseCategoriesProvider.future);
                                setState(() => categories = refreshed);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(strings.duplicateCategory)),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () async {
                      final name = await _askCategoryName(context, strings);
                      if (name == null) return;
                      final category = HomeExpenseCategory(
                        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                      );
                      try {
                        await ref.read(homeExpenseCategoryRepositoryProvider).save(category);
                        ref.invalidate(homeExpenseCategoriesProvider);
                        final refreshed = await ref.read(homeExpenseCategoriesProvider.future);
                        setState(() => categories = refreshed);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.duplicateCategory)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(strings.addCategory),
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
          ],
        ),
      ),
    );
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
    var categories = await ref.read(homeExpenseCategoriesProvider.future);
    if (!context.mounted) return;
    if (existing != null && !categories.any((item) => item.id == existing.categoryId)) {
      categories = [...categories, HomeExpenseCategory(id: existing.categoryId, name: existing.categoryId)];
    }
    String selectedCategoryId = existing?.categoryId ?? categories.first.id;
    final date = TextEditingController(
      text: formatCalendarDate(existing?.expenseDate ?? DateTime.now()),
    );
    final due = TextEditingController(
      text:
          existing?.dueMonth.toString() ?? ref.read(selectedMonthProvider).toString(),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => EntryFormDialog(
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
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: strings.category,
                      suffixIcon: IconButton(
                        tooltip: strings.manageCategories,
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          await _manageCategories(context, ref, strings);
                          if (!context.mounted) return;
                          final refreshed = await ref.refresh(homeExpenseCategoriesProvider.future);
                          setDialogState(() {
                            categories = [
                              ...refreshed,
                              if (existing != null &&
                                  !refreshed.any((item) => item.id == existing.categoryId))
                                HomeExpenseCategory(id: existing.categoryId, name: existing.categoryId),
                            ];
                            if (!categories.any((item) => item.id == selectedCategoryId)) {
                              selectedCategoryId = categories.first.id;
                            }
                          });
                        },
                      ),
                    ),
                    items: categories.map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(_categoryLabel(strings, item)),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategoryId = value);
                      }
                    },
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
                      selectedCategoryId.trim().isEmpty ||
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
                      categoryId: selectedCategoryId,
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
    MonthKey month,
    int outstandingBillsAtMonthEnd,
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
    // Use the unpaid amount at month end so later payments do not change
    // the balance shown when the user revisits a historical month.
    final availableBalance = transferTotal -
        expenseTotal -
        billPaymentsThisMonth -
        outstandingBillsAtMonthEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryMetricGrid(
          metrics: [
            SummaryMetricData(
              title: strings.totalExpenses,
              value: expenseTotal.toString(),
              icon: Icons.shopping_cart_outlined,
            ),
            SummaryMetricData(
              title: strings.receivedFromWork,
              value: transferTotal.toString(),
              icon: Icons.swap_horiz,
            ),
            SummaryMetricData(
              title: strings.totalBillsOutstanding,
              value: outstandingBillsAtMonthEnd.toString(),
              icon: Icons.receipt_outlined,
            ),
            SummaryMetricData(
              title: strings.billPaid,
              value: billPaymentsThisMonth.toString(),
              icon: Icons.task_alt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SummaryMetricGrid(
          metrics: [
            SummaryMetricData(
              title: strings.homeAvailableBalance,
              value: availableBalance.toString(),
              icon: Icons.account_balance_wallet_outlined,
              emphasized: true,
            ),
          ],
        ),
      ],
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
    final expenseCategories = ref.watch(homeExpenseCategoriesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final bills = ref.watch(homeBillsProvider);
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final billPayments = ref.watch(homeBillPaymentsForMonthProvider(selectedMonth));
    final billOutstandingAtMonthEnd =
        ref.watch(homeBillOutstandingAsOfMonthProvider(selectedMonth));
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
        MonthSelector(
          pickerKey: const Key('home-selected-month-picker'),
          selectedMonth: selectedMonth,
          availableMonths: availableMonths,
          onChanged: (month) =>
              ref.read(selectedMonthProvider.notifier).select(month),
        ),
        const SizedBox(height: 12),
        if (overview) ...[
          if (billPayments.isLoading || billOutstandingAtMonthEnd.isLoading)
            Text(strings.loading)
          else if (billPayments.hasError || billOutstandingAtMonthEnd.hasError)
            Text(strings.dataError)
          else
            _homeSummaryCard(
              context,
              strings,
              expenses.value ?? const [],
              transfers.value ?? const [],
              selectedMonth,
              billOutstandingAtMonthEnd.value ?? 0,
              billPayments.value ?? 0,
            ),
          const SizedBox(height: 16),
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
                        title: strings.receivedFromWork,
                        amount: transfer.amount.minorUnits.toString(),
                        details: [
                          formatCalendarDate(transfer.transferredAt),
                          if (transfer.note != null && transfer.note!.isNotEmpty)
                            transfer.note!,
                        ],
                      ),
                    ),
                ],
              );
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
                  for (final expense in monthItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FinancialRecordCard(
                        icon: Icons.receipt_long_outlined,
                        title: _categoryLabel(
                          strings,
                          _categoryForExpense(
                            expenseCategories.value ??
                                const <HomeExpenseCategory>[],
                            expense.categoryId,
                          ),
                        ),
                        amount: expense.amount.minorUnits.toString(),
                        details: [
                          '${strings.expenseDate}: ${formatCalendarDate(expense.expenseDate)}',
                          if (expense.note != null && expense.note!.isNotEmpty)
                            expense.note!,
                        ],
                        actions: [
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
                ],
              );
            },
          ),
        ],
        if (billsPage) HomeBillsSection(selectedMonth: selectedMonth),
      ]),
    );
  }
}
