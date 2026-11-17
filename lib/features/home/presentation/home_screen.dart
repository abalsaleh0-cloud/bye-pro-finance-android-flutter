import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
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
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum HomeScreenMode {
  overview,
  transfers,
  monthlyBills,
  monthlyRents,
  dailyExpenses,
  history,
}

enum HomeQuickAction { expense, invoice, rent }

final homeQuickActionProvider =
    NotifierProvider<HomeQuickActionNotifier, HomeQuickAction?>(
  HomeQuickActionNotifier.new,
);

class HomeQuickActionNotifier extends Notifier<HomeQuickAction?> {
  @override
  HomeQuickAction? build() => null;

  void request(HomeQuickAction action) => state = action;

  void clear() => state = null;
}

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
      'education' => strings.homeCategoryEducation,
      'communications' => strings.homeCategoryCommunications,
      'entertainment' => strings.homeCategoryEntertainment,
      'clothing' => strings.homeCategoryClothing,
      'gifts' => strings.homeCategoryGifts,
      'other' => strings.homeCategoryOther,
      _ => category.id,
    };
  }


  IconData _categoryIcon(String iconKey) => switch (iconKey) {
        'groceries' => Icons.shopping_basket_outlined,
        'utilities' => Icons.bolt_outlined,
        'housing' => Icons.home_work_outlined,
        'cleaning' => Icons.cleaning_services_outlined,
        'maintenance' => Icons.build_outlined,
        'transport' => Icons.directions_car_outlined,
        'personal' => Icons.person_outline_rounded,
        'health' => Icons.medical_services_outlined,
        'education' => Icons.school_outlined,
        'communications' => Icons.phone_android_outlined,
        'entertainment' => Icons.movie_outlined,
        'clothing' => Icons.checkroom_outlined,
        'gifts' => Icons.card_giftcard_outlined,
        'other' => Icons.category_outlined,
        _ => Icons.category_outlined,
      };

  static const _categoryIconOptions = <String>[
    'groceries',
    'utilities',
    'housing',
    'cleaning',
    'maintenance',
    'transport',
    'personal',
    'health',
    'education',
    'communications',
    'entertainment',
    'clothing',
    'gifts',
    'other',
  ];

  HomeExpenseCategory _categoryForExpense(
    List<HomeExpenseCategory> categories,
    String categoryId,
  ) {
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return HomeExpenseCategory(id: categoryId, name: categoryId);
  }

  Future<HomeExpenseCategory?> _askCategoryDetails(
    BuildContext context,
    AppLocalizations strings, {
    HomeExpenseCategory? existing,
  }) async {
    final controller = TextEditingController(
      text: existing == null
          ? ''
          : existing.name.isEmpty
              ? _categoryLabel(strings, existing)
              : existing.name,
    );
    final id = existing?.id ??
        'custom-\${DateTime.now().microsecondsSinceEpoch}';
    var selectedIcon = existing?.iconKey ?? 'category';
    try {
      return await showDialog<HomeExpenseCategory>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? strings.addCategory : strings.editCategory,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: strings.categoryName,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.category,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final iconKey in _categoryIconOptions)
                        IconButton(
                          tooltip: strings.categoryName,
                          style: IconButton.styleFrom(
                            backgroundColor: selectedIcon == iconKey
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                          ),
                          onPressed: () =>
                              setDialogState(() => selectedIcon = iconKey),
                          icon: Icon(_categoryIcon(iconKey)),
                        ),
                    ],
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
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    HomeExpenseCategory(
                      id: id,
                      name: name,
                      iconKey: selectedIcon,
                    ),
                  );
                },
                child: Text(strings.save),
              ),
            ],
          ),
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
        builder: (context, setDialogState) => AlertDialog(
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
                          leading: Icon(_categoryIcon(category.iconKey)),
                          title: Text(_categoryLabel(strings, category)),
                          trailing: IconButton(
                            tooltip: strings.editCategory,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final updated = await _askCategoryDetails(
                                context,
                                strings,
                                existing: category,
                              );
                              if (updated == null) return;
                              try {
                                await ref
                                    .read(homeExpenseCategoryRepositoryProvider)
                                    .save(updated);
                                ref.invalidate(homeExpenseCategoriesProvider);
                                final refreshed = await ref
                                    .read(homeExpenseCategoriesProvider.future);
                                setDialogState(() => categories = refreshed);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(strings.duplicateCategory),
                                    ),
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
                      final category = await _askCategoryDetails(
                        context,
                        strings,
                      );
                      if (category == null) return;
                      try {
                        await ref
                            .read(homeExpenseCategoryRepositoryProvider)
                            .save(category);
                        ref.invalidate(homeExpenseCategoriesProvider);
                        final refreshed = await ref
                            .read(homeExpenseCategoriesProvider.future);
                        setDialogState(() => categories = refreshed);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.duplicateCategory),
                            ),
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
    var categories = await ref.read(homeExpenseCategoriesProvider.future);
    if (!context.mounted) return;
    if (existing != null &&
        !categories.any((item) => item.id == existing.categoryId)) {
      categories = [
        ...categories,
        HomeExpenseCategory(
          id: existing.categoryId,
          name: existing.categoryId,
          iconKey: 'other',
        ),
      ];
    }
    var selectedCategoryId = existing?.categoryId ?? categories.first.id;
    final selectedMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final lastDay = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;
    final defaultDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      now.day > lastDay ? lastDay : now.day,
    );
    final amount = TextEditingController(
      text: existing?.amount.minorUnits.toString() ?? '',
    );
    final date = TextEditingController(
      text: formatCalendarDate(existing?.expenseDate ?? defaultDate),
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        final refreshed = await ref.refresh(
                          homeExpenseCategoriesProvider.future,
                        );
                        setDialogState(() {
                          categories = [
                            ...refreshed,
                            if (existing != null &&
                                !refreshed.any(
                                  (item) => item.id == existing.categoryId,
                                ))
                              HomeExpenseCategory(
                                id: existing.categoryId,
                                name: existing.categoryId,
                                iconKey: 'other',
                              ),
                          ];
                          if (!categories.any(
                            (item) => item.id == selectedCategoryId,
                          )) {
                            selectedCategoryId = categories.first.id;
                          }
                        });
                      },
                    ),
                  ),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Row(
                            children: [
                              Icon(_categoryIcon(item.iconKey)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(_categoryLabel(strings, item)),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategoryId = value);
                    }
                  },
                ),
                TextField(
                  key: const Key('home-expense-amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.amountMinorUnits,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  controller: date,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.expenseDate,
                    suffixIcon: calendarSuffix(
                      context,
                      date,
                      strings,
                      monthOnly: false,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: date,
                  builder: (context, value, child) {
                    final pickedDate = DateTime.tryParse(value.text);
                    if (pickedDate == null) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          top: 2,
                          bottom: 4,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(pickedDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  },
                ),
                TextField(
                  key: const Key('home-expense-note'),
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
                  final dueMonth = existing != null &&
                          formatCalendarDate(parsedDate) ==
                              formatCalendarDate(existing.expenseDate)
                      ? existing.dueMonth
                      : MonthKey(
                          year: parsedDate.year,
                          month: parsedDate.month,
                        );
                  try {
                    await ref.read(homeExpenseRepositoryProvider).save(
                          HomeExpense(
                            id: existing?.id ??
                                DateTime.now().microsecondsSinceEpoch.toString(),
                            amount: Money.fromMinorUnits(parsedAmount),
                            categoryId: selectedCategoryId,
                            expenseDate: parsedDate,
                            dueMonth: dueMonth,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
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
      await WidgetsBinding.instance.endOfFrame;
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


  Widget _buildHistory(
    BuildContext context,
    AppLocalizations strings,
    List<HomeExpense> expenses,
    List<WorkHomeTransfer> transfers,
    List<HomeBill> bills,
    List<HomeBillPayment> payments,
    List<HomeExpenseCategory> categories,
    MonthKey selectedMonth,
  ) {
    final billsById = <String, HomeBill>{
      for (final bill in bills) bill.id: bill,
    };
    final history = <_HomeHistoryRecord>[
      for (final transfer in transfers.where((item) {
        final date = item.transferredAt.toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _HomeHistoryRecord(
          date: transfer.transferredAt,
          title: strings.receivedFromWork,
          amount: transfer.amount.minorUnits,
          icon: Icons.swap_horiz_rounded,
          note: transfer.note,
        ),
      for (final expense in expenses.where((item) {
        final date = item.expenseDate.toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _HomeHistoryRecord(
          date: expense.expenseDate,
          title: _categoryLabel(
            strings,
            _categoryForExpense(categories, expense.categoryId),
          ),
          amount: expense.amount.minorUnits,
          icon: _categoryIcon(
            _categoryForExpense(categories, expense.categoryId).iconKey,
          ),
          note: expense.note,
        ),
      for (final bill in bills.where((item) {
        final date = (item.dueDate ??
                DateTime(item.dueMonth.year, item.dueMonth.month, 1))
            .toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _HomeHistoryRecord(
          date: bill.dueDate ??
              DateTime(bill.dueMonth.year, bill.dueMonth.month, 1),
          title: bill.title,
          amount: bill.amount.minorUnits,
          icon: bill.kind == HomeBillKind.rent
              ? Icons.home_work_outlined
              : Icons.receipt_long_outlined,
          note: bill.note,
          subtitle: bill.kind == HomeBillKind.rent
              ? strings.monthlyRents
              : strings.monthlyBills,
        ),
      for (final payment in payments.where((item) {
        final date = item.paidAt.toLocal();
        return date.year == selectedMonth.year &&
            date.month == selectedMonth.month;
      }))
        _HomeHistoryRecord(
          date: payment.paidAt,
          title: strings.addBillPayment,
          amount: payment.amount.minorUnits,
          icon: Icons.payments_outlined,
          note: payment.note,
          subtitle: billsById[payment.billId]?.title,
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
                if (record.subtitle != null && record.subtitle!.isNotEmpty)
                  record.subtitle!,
                MaterialLocalizations.of(context).formatFullDate(
                  record.date.toLocal(),
                ),
                if (record.note != null && record.note!.trim().isNotEmpty)
                  record.note!.trim(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeShell(AppLocalizations strings) {
    final pages = <HomeScreenMode>[
      HomeScreenMode.overview,
      HomeScreenMode.transfers,
      HomeScreenMode.monthlyBills,
      HomeScreenMode.monthlyRents,
      HomeScreenMode.dailyExpenses,
      HomeScreenMode.history,
    ];
    final labels = [
      strings.homeSection,
      strings.receivedFromWork,
      strings.monthlyBills,
      strings.monthlyRents,
      strings.expenses,
      strings.homeLedger,
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
    final tokens = AppDesignTokens.of(context);
    if (!widget.swipePage && widget.mode == HomeScreenMode.overview) {
      ref.listen<HomeQuickAction?>(homeQuickActionProvider, (previous, action) {
        if (action == null) return;
        ref.read(homeQuickActionProvider.notifier).clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (action) {
            case HomeQuickAction.expense:
              _editExpense(context, ref, strings);
              break;
            case HomeQuickAction.invoice:
              HomeBillsSection(
                selectedMonth: ref.read(selectedMonthProvider),
              ).showAddBill(context, ref, strings, HomeBillKind.monthly);
              break;
            case HomeQuickAction.rent:
              HomeBillsSection(
                selectedMonth: ref.read(selectedMonthProvider),
              ).showAddBill(context, ref, strings, HomeBillKind.rent);
              break;
          }
        });
      });
      return _buildSwipeShell(strings);
    }
    final expenses = ref.watch(homeExpensesProvider);
    final expenseCategories = ref.watch(homeExpenseCategoriesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final bills = ref.watch(homeBillsProvider);
    final allBillPayments = ref.watch(allHomeBillPaymentsProvider);
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
      ...(allBillPayments.value ?? const <HomeBillPayment>[]).map((item) {
        final date = item.paidAt.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
      ...(transfers.value ?? const <WorkHomeTransfer>[]).map((item) {
        final date = item.transferredAt.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
    }.toList()..sort((a, b) => b.compareTo(a));
    final overview = widget.mode == HomeScreenMode.overview;
    final transferPage = widget.mode == HomeScreenMode.transfers;
    final expensePage = widget.mode == HomeScreenMode.dailyExpenses;
    final billsPage = widget.mode == HomeScreenMode.monthlyBills;
    final rentsPage = widget.mode == HomeScreenMode.monthlyRents;
    final historyPage = widget.mode == HomeScreenMode.history;
    final pageTitle = switch (widget.mode) {
      HomeScreenMode.overview => strings.homeSection,
      HomeScreenMode.transfers => strings.receivedFromWork,
      HomeScreenMode.monthlyBills => strings.monthlyBills,
      HomeScreenMode.monthlyRents => strings.monthlyRents,
      HomeScreenMode.dailyExpenses => strings.expenses,
      HomeScreenMode.history => strings.homeLedger,
    };
    return Scaffold(
      appBar: overview || widget.swipePage ? null : AppBar(title: Text(pageTitle)),
      body: ListView(padding: tokens.pageInsets(), children: [
        MonthSelector(
          pickerKey: const Key('home-selected-month-picker'),
          selectedMonth: selectedMonth,
          availableMonths: availableMonths,
          onChanged: (month) =>
              ref.read(selectedMonthProvider.notifier).select(month),
        ),
        SizedBox(height: tokens.sectionSpacing * 0.67),
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
                          MaterialLocalizations.of(context).formatFullDate(
                            transfer.transferredAt.toLocal(),
                          ),
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
                        icon: _categoryIcon(
                          _categoryForExpense(
                            expenseCategories.value ??
                                const <HomeExpenseCategory>[],
                            expense.categoryId,
                          ).iconKey,
                        ),
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
                          MaterialLocalizations.of(context).formatFullDate(
                            expense.expenseDate.toLocal(),
                          ),
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
        if (billsPage)
          HomeBillsSection(
            selectedMonth: selectedMonth,
            kindFilter: HomeBillKind.monthly,
          ),
        if (rentsPage)
          HomeBillsSection(
            selectedMonth: selectedMonth,
            kindFilter: HomeBillKind.rent,
          ),
        if (historyPage) ...[
          expenses.when(
            loading: () => Text(strings.loading),
            error: (error, stackTrace) => Text(strings.dataError),
            data: (expenseItems) => transfers.when(
              loading: () => Text(strings.loading),
              error: (error, stackTrace) => Text(strings.dataError),
              data: (transferItems) => bills.when(
                loading: () => Text(strings.loading),
                error: (error, stackTrace) => Text(strings.dataError),
                data: (billItems) => allBillPayments.when(
                  loading: () => Text(strings.loading),
                  error: (error, stackTrace) => Text(strings.dataError),
                  data: (paymentItems) => _buildHistory(
                    context,
                    strings,
                    expenseItems,
                    transferItems,
                    billItems,
                    paymentItems,
                    expenseCategories.value ?? const [],
                    selectedMonth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}


final class _HomeHistoryRecord {
  const _HomeHistoryRecord({
    required this.date,
    required this.title,
    required this.amount,
    required this.icon,
    this.note,
    this.subtitle,
  });

  final DateTime date;
  final String title;
  final int amount;
  final IconData icon;
  final String? note;
  final String? subtitle;
}
