import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/core/widgets/section_pill_tabs.dart';
import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/widgets/entry_form_dialog.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/presentation/home_bills_section.dart';
import 'package:expense_app/features/home/presentation/home_add_request_provider.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum HomeScreenMode { overview, transfers, monthlyBills, rent, dailyExpenses, history }

enum _HomeAddAction { dailyExpense, monthlyBill, rent }

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
          _editExpense(context, ref, AppLocalizations.of(context)!);
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
    final searchable = '$title ${note ?? ''} $amount ${formatMinorUnits(context, amount)} ${date.toIso8601String()}';
    return searchable.toLowerCase().contains(query);
  }

  Widget _searchField(AppLocalizations strings) => TextField(
        key: const Key('home-record-search'),
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
      'children' => strings.homeCategoryChildren,
      'education' => strings.homeCategoryEducation,
      'entertainment' => strings.homeCategoryEntertainment,
      'communication' => strings.homeCategoryCommunication,
      'subscriptions' => strings.homeCategorySubscriptions,
      'gifts' => strings.homeCategoryGifts,
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

  IconData _categoryIcon(HomeExpenseCategory category) => switch (category.id) {
    'groceries' => Icons.shopping_basket_outlined,
    'utilities' => Icons.electrical_services_outlined,
    'housing' => Icons.home_outlined,
    'cleaning' => Icons.cleaning_services_outlined,
    'maintenance' => Icons.build_outlined,
    'transport' => Icons.directions_car_outlined,
    'personal' => Icons.person_outline,
    'health' => Icons.local_hospital_outlined,
    'children' => Icons.child_care_outlined,
    'education' => Icons.school_outlined,
    'entertainment' => Icons.movie_outlined,
    'communication' => Icons.smartphone_outlined,
    'subscriptions' => Icons.subscriptions_outlined,
    'gifts' => Icons.card_giftcard_outlined,
    _ => Icons.category_outlined,
  };

  DateTime _defaultSelectedDate() {
    final month = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, now.day > lastDay ? lastDay : now.day);
  }

  Future<void> _showHomeAddOptions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final selected = await showModalBottomSheet<_HomeAddAction>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignTokens.of(context).dialogRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('home-add-daily-expense'),
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(strings.addExpense),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _HomeAddAction.dailyExpense,
                ),
              ),
              ListTile(
                key: const Key('home-add-monthly-bill'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(strings.addMonthlyBill),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _HomeAddAction.monthlyBill,
                ),
              ),
              ListTile(
                key: const Key('home-add-rent'),
                leading: const Icon(Icons.home_work_outlined),
                title: Text(strings.addMonthlyRent),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _HomeAddAction.rent,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case _HomeAddAction.dailyExpense:
        await _editExpense(context, ref, strings);
        break;
      case _HomeAddAction.monthlyBill:
        await HomeBillsSection(
          selectedMonth: ref.read(selectedMonthProvider),
        ).showAddBill(
          context,
          ref,
          strings,
          HomeBillKind.monthly,
        );
        break;
      case _HomeAddAction.rent:
        await HomeBillsSection(
          selectedMonth: ref.read(selectedMonthProvider),
        ).showAddBill(
          context,
          ref,
          strings,
          HomeBillKind.rent,
        );
        break;
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
    var categories = await ref.read(homeExpenseCategoriesProvider.future);
    if (!context.mounted) return;
    if (existing != null && !categories.any((item) => item.id == existing.categoryId)) {
      categories = [...categories, HomeExpenseCategory(id: existing.categoryId, name: existing.categoryId)];
    }
    String selectedCategoryId = existing?.categoryId ?? categories.first.id;
    final date = TextEditingController(
      text: formatCalendarDate(existing?.expenseDate ?? _defaultSelectedDate()),
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
                  DropdownButtonFormField<String>(
                    key: const Key('home-expense-category'),
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
                      child: Row(children: [Icon(_categoryIcon(item), size: 20), const SizedBox(width: 8), Text(_categoryLabel(strings, item))]),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategoryId = value);
                      }
                    },
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.calculatorAmount,
                      suffixIcon: calculatorSuffix(context, amount, strings),
                    ),
                  ),
                  TextField(
                    controller: date,
                    readOnly: true,
                    key: const Key('home-expense-date'),
                    decoration: InputDecoration(
                      labelText: strings.recordedAt,
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: calendarSuffix(context, date, strings, monthOnly: false),
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
                  if (parsedAmount == null ||
                      parsedAmount <= 0 ||
                      selectedCategoryId.trim().isEmpty ||
                      parsedDate == null) {
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
                      dueMonth: MonthKey(year: parsedDate.year, month: parsedDate.month),
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
              title: strings.homeIncomingFromWork,
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
      HomeScreenMode.monthlyBills,
      HomeScreenMode.rent,
      HomeScreenMode.dailyExpenses,
      HomeScreenMode.history,
    ];
    final labels = [
      strings.homeSection,
      strings.homeIncomingFromWork,
      strings.monthlyBills,
      strings.homeMonthlyRent,
      strings.homeExpenses,
      strings.homeHistory,
    ];

    return Column(
      children: [
        SectionPillTabs(
          keyPrefix: 'home-tab',
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
    ref.listen<int>(homeAddRequestProvider, (previous, next) {
      if (widget.swipePage || widget.mode != HomeScreenMode.overview || next <= (previous ?? 0)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showHomeAddOptions(context, ref, strings);
        }
      });
    });
    final tokens = AppDesignTokens.of(context);
    if (!widget.swipePage && widget.mode == HomeScreenMode.overview) {
      return _buildSwipeShell(strings);
    }
    final expenses = ref.watch(homeExpensesProvider);
    final expenseCategories = ref.watch(homeExpenseCategoriesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final bills = ref.watch(homeBillsProvider);
    final billPayments = ref.watch(allHomeBillPaymentsProvider);
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final billPaymentsForMonth = ref.watch(homeBillPaymentsForMonthProvider(selectedMonth));
    final billOutstandingAtMonthEnd =
        ref.watch(homeBillOutstandingThroughMonthAsOfMonthProvider(selectedMonth));
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
    final rentPage = widget.mode == HomeScreenMode.rent;
    final historyPage = widget.mode == HomeScreenMode.history;
    final pageTitle = transferPage ? strings.receivedFromWork : expensePage ? strings.dailyExpenses : strings.monthlyBills;
    return Scaffold(
      appBar: overview || widget.swipePage ? null : AppBar(title: Text(pageTitle)),

      body: ListView(padding: tokens.pageInsets(), children: [
        if (!historyPage) MonthSelector(
          pickerKey: const Key('home-selected-month-picker'),
          selectedMonth: selectedMonth,
          availableMonths: availableMonths,
          onChanged: (month) =>
              ref.read(selectedMonthProvider.notifier).select(month),
        ),
        SizedBox(height: tokens.sectionSpacing * 0.67),
        if (transferPage || expensePage || historyPage || billsPage || rentPage)
          _searchField(strings),
        if (overview) ...[
          if (billPaymentsForMonth.isLoading || billOutstandingAtMonthEnd.isLoading)
            Text(strings.loading)
          else if (billPaymentsForMonth.hasError || billOutstandingAtMonthEnd.hasError)
            Text(strings.dataError)
          else
            _homeSummaryCard(
              context,
              strings,
              expenses.value ?? const [],
              transfers.value ?? const [],
              selectedMonth,
              billOutstandingAtMonthEnd.value ?? 0,
              billPaymentsForMonth.value ?? 0,
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
              }).where((transfer) => _matchesSearch(
                title: strings.homeIncomingFromWork,
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
                        title: strings.homeIncomingFromWork,
                        amount: formatMinorUnits(context, transfer.amount.minorUnits),
                        details: [
                          toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(transfer.transferredAt)),
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
              }).where((expense) => _matchesSearch(
                title: _categoryLabel(strings, _categoryForExpense(
                  expenseCategories.value ?? const <HomeExpenseCategory>[], expense.categoryId,
                )),
                amount: expense.amount.minorUnits,
                date: expense.expenseDate,
                note: expense.note,
              )).toList();
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
                        icon: _categoryIcon(_categoryForExpense(expenseCategories.value ?? const <HomeExpenseCategory>[], expense.categoryId)),
                        title: _categoryLabel(
                          strings,
                          _categoryForExpense(
                            expenseCategories.value ?? const <HomeExpenseCategory>[],
                            expense.categoryId,
                          ),
                        ),
                        amount: formatMinorUnits(context, expense.amount.minorUnits),
                        details: [
                          toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(expense.expenseDate)),
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
        if (historyPage) ...[
          if (expenses.isLoading || transfers.isLoading || bills.isLoading || billPayments.isLoading || expenseCategories.isLoading)
            Text(strings.loading)
          else if (expenses.hasError || transfers.hasError || bills.hasError || billPayments.hasError || expenseCategories.hasError)
            Text(strings.dataError)
          else
            Builder(builder: (context) {
              final allBills = bills.value ?? const <HomeBill>[];
              final allExpenses = expenses.value ?? const <HomeExpense>[];
              final allTransfers = transfers.value ?? const <WorkHomeTransfer>[];
              final allPayments = billPayments.value ?? const <HomeBillPayment>[];
              final categories = expenseCategories.value ?? const <HomeExpenseCategory>[];
              final logItems = <_HomeLogItem>[
                for (final item in allExpenses)
                  _HomeLogItem(date: item.expenseDate, title: _categoryLabel(strings, _categoryForExpense(categories, item.categoryId)), amount: item.amount.minorUnits, icon: _categoryIcon(_categoryForExpense(categories, item.categoryId)), note: item.note),
                for (final item in allBills)
                  _HomeLogItem(date: item.calendarDate, title: item.kind == HomeBillKind.rent ? strings.addMonthlyRent : strings.addMonthlyBill, subtitle: item.title, amount: item.amount.minorUnits, icon: item.kind == HomeBillKind.rent ? Icons.home_work_outlined : Icons.receipt_long_outlined, note: item.note),
                for (final item in allTransfers)
                  _HomeLogItem(date: item.transferredAt, title: strings.homeIncomingFromWork, amount: item.amount.minorUnits, icon: Icons.swap_horiz, note: item.note),
                for (final item in allPayments)
                  _HomeLogItem(date: item.paidAt, title: strings.addBillPayment, subtitle: allBills.where((bill) => bill.id == item.billId).firstOrNull?.title, amount: item.amount.minorUnits, icon: Icons.payments_outlined, note: item.note),
              ]..sort((a, b) => b.date.compareTo(a.date));
              final filteredLogItems = logItems.where((item) => _matchesSearch(
                title: item.title, amount: item.amount, date: item.date,
                note: '${item.subtitle ?? ''} ${item.note ?? ''}',
              )).toList();
              if (filteredLogItems.isEmpty) {
                return Center(child: Text(strings.noRecords));
              }
              return Column(children: [
                for (final item in logItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FinancialRecordCard(
                      icon: item.icon,
                      title: item.title,
                      amount: formatMinorUnits(context, item.amount),
                      details: [
                        if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
                        toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(item.date)),
                        if (item.note != null && item.note!.isNotEmpty) item.note!,
                      ],
                    ),
                  ),
              ]);
            }),
        ],
        if (billsPage) HomeBillsSection(selectedMonth: selectedMonth, kind: HomeBillKind.monthly, searchQuery: _searchQuery),
        if (rentPage) HomeBillsSection(selectedMonth: selectedMonth, kind: HomeBillKind.rent, searchQuery: _searchQuery),
      ]),
    );
  }
}


class _HomeLogItem {
  const _HomeLogItem({required this.date, required this.title, required this.amount, required this.icon, this.subtitle, this.note});
  final DateTime date;
  final String title;
  final String? subtitle;
  final int amount;
  final IconData icon;
  final String? note;
}
