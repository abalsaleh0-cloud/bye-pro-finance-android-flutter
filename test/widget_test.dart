import 'package:drift/native.dart';
import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';


/// Dispose each ProviderScope while still inside the widget test's fakeAsync
/// zone, then elapse Drift's zero-duration stream-close timer before the
/// test binding checks for pending timers.
void _testWidgetsWithDriftCleanup(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

void main() {
  late AppDatabase testDatabase;

  setUpAll(() async {
    // One in-memory test database per suite; no platform path plugin is needed.
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    await testDatabase.readSetting('test-suite-ready');
  });

  setUp(() async {
    await testDatabase.clearFinancialData();
    await testDatabase.customStatement('DELETE FROM app_settings');
  });

  tearDownAll(() async {
    await testDatabase.close();
  });

  _testWidgetsWithDriftCleanup('starts in Arabic with five primary navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-calculator')), findsOneWidget);
    expect(find.byKey(const Key('open-calendar')), findsOneWidget);
    expect(find.text('الذكاء الاصطناعي'), findsWidgets);
  });

  _testWidgetsWithDriftCleanup('global calculator evaluates expressions and returns a safe result', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('open-calculator')));
    await tester.pumpAndSettle();

    for (final key in ['(', '1', '2', '+', '3', '0', ')', '×', '2']) {
      final keypadButton = find.byKey(Key('calculator-key-$key'));
      await tester.ensureVisible(keypadButton);
      await tester.pumpAndSettle();
      await tester.tap(keypadButton);
      await tester.pumpAndSettle();
    }
    final equalsButton = find.byKey(const Key('calculator-key-equals'));
    await tester.ensureVisible(equalsButton);
    await tester.pumpAndSettle();
    await tester.tap(equalsButton);
    await tester.pumpAndSettle();

    expect(tester.widget<SelectableText>(find.byKey(const Key('calculator-result'))).data, '84');
    await tester.tap(find.text('استخدام النتيجة'));
    await tester.pumpAndSettle();
    expect(find.text('النتيجة: 84'), findsOneWidget);
  });

  _testWidgetsWithDriftCleanup('financial calculator calculates percentages in minor units', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('open-calculator')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calculator-financial-mode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calculator-financial-amount')),
      '75000',
    );
    await tester.enterText(
      find.byKey(const Key('calculator-financial-percentage')),
      '10',
    );
    final calculateButton = find.byKey(
      const Key('calculator-financial-calculate'),
    );
    await tester.ensureVisible(calculateButton);
    await tester.pumpAndSettle();
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();

    expect(tester.widget<SelectableText>(find.byKey(const Key('calculator-result'))).data, 'النتيجة: 7500');
    await tester.tap(find.text('استخدام النتيجة'));
    await tester.pumpAndSettle();
    expect(find.text('النتيجة: 7500'), findsOneWidget);
  });

  _testWidgetsWithDriftCleanup('global calendar opens the original date picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const Key('open-calendar')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });

  _testWidgetsWithDriftCleanup('settings can switch theme and language', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.text('الوضع الداكن'), findsOneWidget);
    await tester.tap(find.text('الوضع الداكن'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإنجليزية').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
      tester.widget<Directionality>(find.byType(Directionality).last).textDirection,
      TextDirection.rtl,
    );
  });

  _testWidgetsWithDriftCleanup('bottom navigation changes the active section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();

    expect(find.text('العمل'), findsWidgets);
    expect(find.byKey(const Key('work-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('work-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('work-tab-2')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('work-tab-2')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byKey(const Key('work-section-pages'))).controller!.page,
      2,
    );

    await tester.tap(find.text('الذكاء الاصطناعي').last);
    await tester.pumpAndSettle();
    expect(find.text('الذكاء الاصطناعي'), findsWidgets);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-2')), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      expect(find.byKey(Key('home-tab-$index')), findsOneWidget);
    }
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-tab-5')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byKey(const Key('home-section-pages'))).controller!.page,
      5,
    );
  });

  _testWidgetsWithDriftCleanup('selected month stays synchronized between work and home sections', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final previousDate = DateTime(now.year, now.month - 1, 10);
    final previousMonth = MonthKey(
      year: previousDate.year,
      month: previousDate.month,
    );
    final previousWorkEntry = WorkEntry(
      id: 'month-sync-work-entry',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(100),
      dueMonth: previousMonth,
      recordedAt: previousDate,
    );
    final previousTransfer = WorkHomeTransfer(
      id: 'month-sync-home-transfer',
      amount: Money.fromMinorUnits(100),
      transferredAt: previousDate,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith(
            (ref) => Stream.value([previousWorkEntry]),
          ),
          workTransfersProvider.overrideWith(
            (ref) => Stream.value([previousTransfer]),
          ),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith((ref) async => []),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(currentMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('العمل')));
    await tester.pumpAndSettle();

    // Mount both stateful navigation branches before changing the shared month.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('المنزل')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('العمل')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('work-selected-month-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('month-option-$previousMonth')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('المنزل')));
    await tester.pumpAndSettle();
    final homeMonthPicker = find.byKey(const Key('home-selected-month-picker'));
    final previousMonthLabel = MaterialLocalizations.of(
      tester.element(homeMonthPicker),
    ).formatMonthYear(DateTime(previousMonth.year, previousMonth.month, 1));
    expect(
      find.descendant(
        of: homeMonthPicker,
        matching: find.text(previousMonthLabel),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home-selected-month-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('month-option-$currentMonth')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('العمل')));
    await tester.pumpAndSettle();
    final workMonthPicker = find.byKey(const Key('work-selected-month-picker'));
    final currentMonthLabel = MaterialLocalizations.of(
      tester.element(workMonthPicker),
    ).formatMonthYear(DateTime(currentMonth.year, currentMonth.month, 1));
    expect(
      find.descendant(
        of: workMonthPicker,
        matching: find.text(currentMonthLabel),
      ),
      findsOneWidget,
    );
  });

  _testWidgetsWithDriftCleanup('work section removes action cards and keeps actions in the top add menu', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),
          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith((ref) async => []),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(currentMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('العمل'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-work-add')), findsOneWidget);
    expect(find.byKey(const Key('work-add-salary')), findsNothing);
    expect(find.byKey(const Key('work-add-payment')), findsNothing);
    expect(find.byKey(const Key('work-add-advance')), findsNothing);
    expect(find.byKey(const Key('work-add-transfer')), findsNothing);

    await tester.tap(find.byKey(const Key('open-work-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-add-action-salary')), findsOneWidget);
    expect(find.byKey(const Key('work-add-action-payment')), findsOneWidget);
    expect(find.byKey(const Key('work-add-action-advance')), findsOneWidget);
    expect(find.byKey(const Key('work-add-action-transfer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('work-add-action-payment')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('إضافة دفعة'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('work-entry-amount')), findsOneWidget);
    expect(find.byKey(const Key('work-entry-date')), findsOneWidget);
    expect(find.byKey(const Key('work-entry-note')), findsOneWidget);
    expect(find.text('المبلغ'), findsOneWidget);
    expect(find.text('التاريخ'), findsOneWidget);
    expect(find.text('ملاحظة'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<WorkEntryKind>), findsNothing);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-work-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-add-action-transfer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-transfer-amount')), findsOneWidget);
    expect(find.byKey(const Key('work-transfer-date')), findsOneWidget);
    expect(find.byKey(const Key('work-transfer-note')), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  _testWidgetsWithDriftCleanup('home top add opens bill, rent and categorized expense forms', (tester) async {
    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith((ref, selected) async => 0),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),
          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith((ref) async => HomeExpenseCategory.defaults),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith((ref, selected) async => 0),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(() => _FixedSelectedMonthNotifier(month)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-home-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-add-monthly-bill')), findsOneWidget);
    expect(find.byKey(const Key('home-add-rent')), findsOneWidget);
    expect(find.byKey(const Key('home-add-daily-expense')), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home_work_outlined), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-add-monthly-bill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-bill-name')), findsOneWidget);
    expect(find.byKey(const Key('home-bill-date')), findsOneWidget);
    expect(find.text('المبلغ'), findsOneWidget);
    expect(find.text('ملاحظة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-home-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-add-rent')));
    await tester.pumpAndSettle();
    expect(find.text('إضافة إيجار شهري'), findsOneWidget);
    expect(find.byKey(const Key('home-bill-name')), findsOneWidget);
    expect(find.byKey(const Key('home-bill-date')), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-home-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-add-daily-expense')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-expense-category')), findsOneWidget);
    expect(find.byKey(const Key('home-expense-date')), findsOneWidget);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
    expect(find.text('ملاحظة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  _testWidgetsWithDriftCleanup('debt add menu opens the selected creditor form', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith((ref) async => []),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(currentMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-debts-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debt-add-creditor')), findsOneWidget);
    expect(find.byKey(const Key('debt-add-debtor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('debt-add-creditor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt-person')), findsOneWidget);
    expect(find.byKey(const Key('debt-amount')), findsOneWidget);
    expect(find.byKey(const Key('debt-date')), findsOneWidget);
    expect(find.byKey(const Key('debt-note')), findsOneWidget);
    expect(find.text('إضافة دين لك (دائن)'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<DebtDirection>), findsNothing);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  _testWidgetsWithDriftCleanup('new debt form defaults to the globally selected month', (tester) async {
    final now = DateTime.now();
    final previousDate = DateTime(now.year, now.month - 1, 1);
    final previousMonth = MonthKey(
      year: previousDate.year,
      month: previousDate.month,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith(
            (ref) async => HomeExpenseCategory.defaults,
          ),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(previousMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-debts-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('debt-add-debtor')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('debt-date'))).controller!.text, startsWith('$previousMonth-'));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  _testWidgetsWithDriftCleanup('work records show their note in the records page', (tester) async {
    final now = DateTime.now();
    final entry = WorkEntry(
      id: 'widget-work-note',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(1500),
      dueMonth: MonthKey(year: now.year, month: now.month),
      recordedAt: now,
      note: 'ملاحظة الراتب',
    );
    final previousDate = DateTime(now.year, now.month - 1, 1);
    final previousMonthEntry = WorkEntry(
      id: 'widget-work-note-previous-month',
      kind: WorkEntryKind.advance,
      amount: Money.fromMinorUnits(90),
      dueMonth: MonthKey(year: previousDate.year, month: previousDate.month),
      recordedAt: previousDate,
      note: 'ملاحظة راتب قديم',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith(
            (ref) => Stream.value([entry, previousMonthEntry]),
          ),
          workTransfersProvider.overrideWith(
            (ref) => Stream.value([
              WorkHomeTransfer(
                id: 'widget-work-log-transfer',
                amount: Money.fromMinorUnits(275),
                transferredAt: DateTime(now.year, now.month, now.day - 1),
                note: 'ملاحظة التحويل',
              ),
            ]),
          ),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(
              MonthKey(year: now.year, month: now.month),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-tab-2')));
    await tester.pumpAndSettle();

    // The note is rendered inside the same multiline subtitle Text as its date.
    expect(find.textContaining('ملاحظة الراتب'), findsOneWidget);
    expect(find.textContaining('ملاحظة التحويل'), findsOneWidget);
    expect(find.textContaining('ملاحظة راتب قديم'), findsOneWidget);
    expect(find.text('تحويل إلى المنزل'), findsOneWidget);
  });
  _testWidgetsWithDriftCleanup('saved home bill note is visible on the monthly bills card', (tester) async {
    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    final bill = HomeBill(
      id: 'widget-home-bill-note',
      title: 'فاتورة اختبار',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(580),
      dueMonth: month,
      note: 'ملاحظة فاتورة مباشرة',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          homeBillsProvider.overrideWith((ref) async => [bill]),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-2')));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة اختبار'), findsOneWidget);
    expect(find.textContaining('ملاحظة فاتورة مباشرة'), findsOneWidget);
  });


  _testWidgetsWithDriftCleanup('home summary displays the exact remaining balance after rent and daily expenses', (tester) async {
    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    final expense = HomeExpense(
      id: 'widget-home-expense-balance',
      amount: Money.fromMinorUnits(150),
      categoryId: 'groceries',
      expenseDate: now,
      dueMonth: month,
    );
    final transfer = WorkHomeTransfer(
      id: 'widget-home-transfer-balance',
      amount: Money.fromMinorUnits(750),
      transferredAt: now,
    );
    final rent = HomeBill(
      id: 'widget-home-rent-balance',
      title: 'إيجار المنزل للاختبار',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(580),
      dueMonth: month,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 580,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          homeExpensesProvider.overrideWith((ref) => Stream.value([expense])),
          workTransfersProvider.overrideWith((ref) => Stream.value([transfer])),
          homeBillsProvider.overrideWith((ref) async => [rent]),
          homeBillPaymentsForMonthProvider.overrideWith((ref, selected) async => 0),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();

    expect(find.text('الرصيد المتاح في المنزل'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });


  _testWidgetsWithDriftCleanup('dashboard follows the globally selected historical month', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    final previousDate = DateTime(now.year, now.month - 1, 10);
    final previousMonth = MonthKey(year: previousDate.year, month: previousDate.month);
    final selectedSalary = WorkEntry(
      id: 'dashboard-selected-month-salary',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(321),
      dueMonth: previousMonth,
      recordedAt: previousDate,
    );
    final currentSalary = WorkEntry(
      id: 'dashboard-current-month-salary',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(999),
      dueMonth: currentMonth,
      recordedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith((ref) => Stream.value([selectedSalary, currentSalary])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith((ref, selected) async => 0),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(previousMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final dashboardMonthPicker =
        find.byKey(const Key('dashboard-month-picker'));
    final dashboardMonthLabel = MaterialLocalizations.of(
      tester.element(dashboardMonthPicker),
    ).formatMonthYear(
      DateTime(previousMonth.year, previousMonth.month, 1),
    );
    expect(
      find.descendant(
        of: dashboardMonthPicker,
        matching: find.text(dashboardMonthLabel),
      ),
      findsOneWidget,
    );
    expect(find.text('321'), findsWidgets);
    expect(find.text('999'), findsNothing);
  });


  _testWidgetsWithDriftCleanup('home bill menu exposes edit and delete and edit form is prefilled', (tester) async {
    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    final bill = HomeBill(
      id: 'widget-editable-bill',
      title: 'فاتورة قابلة للتعديل',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(420),
      dueMonth: month,
      note: 'ملاحظة موجودة',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          homeBillsProvider.overrideWith((ref) async => [bill]),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-2')));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة قابلة للتعديل'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('تعديل السجل'), findsOneWidget);
    expect(find.text('حذف السجل'), findsOneWidget);
    await tester.tap(find.text('تعديل السجل'));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة قابلة للتعديل'), findsWidgets);
    expect(find.text('420'), findsOneWidget);
    expect(find.text('ملاحظة موجودة'), findsOneWidget);
  });

  _testWidgetsWithDriftCleanup('new work and home forms default to the globally selected month', (tester) async {
    final now = DateTime.now();
    final previousDate = DateTime(now.year, now.month - 1, 1);
    final previousMonth = MonthKey(
      year: previousDate.year,
      month: previousDate.month,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith(
            (ref) async => HomeExpenseCategory.defaults,
          ),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(previousMonth),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    List<String> fieldValues() => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text ?? '')
        .toList();

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-work-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-add-action-salary')));
    await tester.pumpAndSettle();
    expect(fieldValues().any((value) => value.startsWith('$previousMonth-')), isTrue);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('work-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-work-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-add-action-transfer')));
    await tester.pumpAndSettle();
    expect(fieldValues().any((value) => value.startsWith('$previousMonth-')), isTrue);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-home-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-add-daily-expense')));
    await tester.pumpAndSettle();
    expect(fieldValues().any((value) => value.startsWith('$previousMonth-')), isTrue);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-home-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-add-monthly-bill')));
    await tester.pumpAndSettle();
    expect(fieldValues().any((value) => value.startsWith('$previousMonth-')), isTrue);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  _testWidgetsWithDriftCleanup('debt payment form exposes time selection and history shows time', (tester) async {
    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    final debt = DebtEntry(
      id: 'widget-debt-payment-time',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(500),
      outstandingAmount: Money.fromMinorUnits(400),
      dueMonth: month,
      createdAt: now,
      counterparty: 'دين اختبار الوقت',
    );
    final payment = DebtPayment(
      id: 'widget-debt-payment-time-record',
      debtId: debt.id,
      amount: Money.fromMinorUnits(100),
      paidAt: DateTime(now.year, now.month, now.day, 14, 35),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          homeBillOutstandingAsOfMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          allHomeBillPaymentsProvider.overrideWith((ref) async => []),
          allDebtPaymentsProvider.overrideWith((ref) => Stream.value([])),

          workEntriesProvider.overrideWith((ref) => Stream.value([])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          homeExpenseCategoriesProvider.overrideWith(
            (ref) async => HomeExpenseCategory.defaults,
          ),
          homeBillsProvider.overrideWith((ref) async => []),
          homeBillPaymentsForMonthProvider.overrideWith(
            (ref, selected) async => 0,
          ),
          debtsProvider.overrideWith((ref) => Stream.value([debt])),
          debtPaymentsProvider.overrideWith(
            (ref, debtId) => Stream.value(
              debtId == debt.id ? [payment] : const <DebtPayment>[],
            ),
          ),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('debts-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('سجل الدفعات'), findsOneWidget);
    expect(find.textContaining('الوقت:'), findsNothing);
    final paymentHistory = find.byKey(
      const Key('debt-payment-history-widget-debt-payment-time'),
    );
    await tester.ensureVisible(paymentHistory);
    await tester.pumpAndSettle();
    await tester.tap(paymentHistory);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('لا توجد سجلات'), findsNothing);
    expect(find.textContaining('الوقت:'), findsOneWidget);
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل دفعة').last);
    await tester.pumpAndSettle();
    expect(find.text('الوقت'), findsOneWidget);
    expect(find.byTooltip('الوقت'), findsOneWidget);
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();
  });

}

class _FixedSelectedMonthNotifier extends SelectedMonthNotifier {
  _FixedSelectedMonthNotifier(this.month);

  final MonthKey month;

  @override
  MonthKey build() => month;

  @override
  void select(MonthKey selected) {
    state = selected;
  }

}
