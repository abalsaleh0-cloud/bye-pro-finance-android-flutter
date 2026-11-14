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

void main() {
  testWidgets('starts in Arabic with five navigation destinations', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-calculator')), findsOneWidget);
  });

  testWidgets('global calculator evaluates expressions and returns a safe result', (tester) async {
    await _pumpApp(tester);
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

  testWidgets('financial calculator calculates percentages in minor units', (tester) async {
    await _pumpApp(tester);
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

  testWidgets('settings can switch theme and language', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.text('الوضع الداكن'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dark-mode-switch')));
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

  testWidgets('bottom navigation changes the active section', (tester) async {
    await _pumpApp(tester);

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

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-2')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-3')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-tab-3')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byKey(const Key('home-section-pages'))).controller!.page,
      3,
    );
  });

  testWidgets('selected month stays synchronized between work and home sections', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
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
    await tester.tap(find.text(previousMonth.toString()).last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('المنزل')));
    await tester.pumpAndSettle();
    expect(find.text(previousMonth.toString()), findsNWidgets(2));
    final homeMonthPicker = find.byKey(const Key('home-selected-month-picker'));
    expect(
      find.descendant(
        of: homeMonthPicker,
        matching: find.text(previousMonth.toString()),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home-selected-month-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentMonth.toString()).last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('العمل')));
    await tester.pumpAndSettle();
    final workMonthPicker = find.byKey(const Key('work-selected-month-picker'));
    expect(
      find.descendant(
        of: workMonthPicker,
        matching: find.text(currentMonth.toString()),
      ),
      findsOneWidget,
    );
  });

  testWidgets('work form offers salary advance and payment entry types', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    await _pumpApp(
      tester,
      overrides: [
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
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('العمل'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final kindField = find.byType(DropdownButtonFormField<WorkEntryKind>);
    expect(kindField, findsOneWidget);
    await tester.tap(kindField);
    await tester.pumpAndSettle();
    expect(find.text('راتب'), findsWidgets);
    expect(find.text('سلفة'), findsOneWidget);
    expect(find.text('دفعة'), findsOneWidget);
    await tester.tap(find.text('دفعة').last);
    await tester.pumpAndSettle();

    expect(find.text('دفعة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  testWidgets('debt form allows selecting creditor direction', (tester) async {
    final now = DateTime.now();
    final currentMonth = MonthKey(year: now.year, month: now.month);
    await _pumpApp(
      tester,
      overrides: [
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
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final directionField = find.byType(
      DropdownButtonFormField<DebtDirection>,
    );
    expect(directionField, findsOneWidget);
    await tester.tap(directionField);
    await tester.pumpAndSettle();
    expect(find.text('دائن'), findsOneWidget);
    expect(find.text('مدين'), findsWidgets);
    await tester.tap(find.text('دائن').last);
    await tester.pumpAndSettle();

    expect(find.text('دائن'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  testWidgets('new debt form defaults to the globally selected month', (tester) async {
    final now = DateTime.now();
    final previousDate = DateTime(now.year, now.month - 1, 1);
    final previousMonth = MonthKey(
      year: previousDate.year,
      month: previousDate.month,
    );

    await _pumpApp(
      tester,
      overrides: [
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
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text ?? '');
    expect(values, contains(previousMonth.toString()));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  testWidgets('work records show their note in the records page', (tester) async {
    final now = DateTime.now();
    final entry = WorkEntry(
      id: 'widget-work-note',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(1500),
      dueMonth: MonthKey(year: now.year, month: now.month),
      recordedAt: now,
      note: 'ملاحظة الراتب',
    );

    await _pumpApp(
      tester,
      overrides: [
          workEntriesProvider.overrideWith((ref) => Stream.value([entry])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(
              MonthKey(year: now.year, month: now.month),
            ),
          ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('work-tab-2')));
    await tester.pumpAndSettle();

    // The note is rendered inside the same multiline subtitle Text as its date.
    expect(find.textContaining('ملاحظة الراتب'), findsOneWidget);
  });
  testWidgets('saved home bill note is visible on the monthly bills card', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
          homeBillsProvider.overrideWith((ref) async => [bill]),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-3')));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة اختبار'), findsOneWidget);
    expect(find.textContaining('ملاحظة فاتورة مباشرة'), findsOneWidget);
  });


  testWidgets('home summary displays the exact remaining balance after rent and daily expenses', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
          homeExpensesProvider.overrideWith((ref) => Stream.value([expense])),
          workTransfersProvider.overrideWith((ref) => Stream.value([transfer])),
          homeBillsProvider.overrideWith((ref) async => [rent]),
          homeBillPaymentsForMonthProvider.overrideWith((ref, selected) async => 0),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();

    expect(find.text('الرصيد المتاح في المنزل'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });


  testWidgets('dashboard follows the globally selected historical month', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
          workEntriesProvider.overrideWith((ref) => Stream.value([selectedSalary, currentSalary])),
          workTransfersProvider.overrideWith((ref) => Stream.value([])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([])),
          debtsProvider.overrideWith((ref) => Stream.value([])),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(previousMonth),
          ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(previousMonth.toString()), findsOneWidget);
    expect(find.text('321'), findsWidgets);
    expect(find.text('999'), findsNothing);
  });


  testWidgets('home bill menu exposes edit and delete and edit form is prefilled', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
          homeBillsProvider.overrideWith((ref) async => [bill]),
          selectedMonthProvider.overrideWith(
            () => _FixedSelectedMonthNotifier(month),
          ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-3')));
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

  testWidgets('new work and home forms default to the globally selected month', (tester) async {
    final now = DateTime.now();
    final previousDate = DateTime(now.year, now.month - 1, 1);
    final previousMonth = MonthKey(
      year: previousDate.year,
      month: previousDate.month,
    );

    await _pumpApp(
      tester,
      overrides: [
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
    );
    await tester.pumpAndSettle();

    List<String> fieldValues() => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text ?? '')
        .toList();

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(fieldValues(), contains(previousMonth.toString()));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('work-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      fieldValues().any((value) => value.startsWith('$previousMonth-')),
      isTrue,
    );
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(fieldValues(), contains(previousMonth.toString()));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-tab-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إضافة فاتورة شهرية'));
    await tester.pumpAndSettle();
    expect(fieldValues(), contains(previousMonth.toString()));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });

  testWidgets('debt payment form exposes time selection and history shows time', (tester) async {
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

    await _pumpApp(
      tester,
      overrides: [
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
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('الوقت:'), findsOneWidget);

    await tester.tap(find.text('تسجيل دفعة').last);
    await tester.pumpAndSettle();
    expect(find.text('الوقت'), findsOneWidget);
    expect(find.byTooltip('الوقت'), findsOneWidget);
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();
  });

}


Future<void> _pumpApp(
  WidgetTester tester, {
  List<dynamic> overrides = const [],
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        ...overrides,
      ],
      child: const MyApp(),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
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
