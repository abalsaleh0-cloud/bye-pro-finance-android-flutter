import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('dashboard shows selected month and reconciled home balance', (tester) async {
    final month = MonthKey(year: 2026, month: 10);
    final date = DateTime(2026, 10, 12);
    final salary = WorkEntry(
      id: 'dashboard-salary',
      kind: WorkEntryKind.salary,
      amount: Money.fromMinorUnits(1500),
      dueMonth: month,
      recordedAt: DateTime(2026, 10, 1),
    );
    final expense = HomeExpense(
      id: 'dashboard-expense',
      amount: Money.fromMinorUnits(150),
      categoryId: 'groceries',
      expenseDate: date,
      dueMonth: month,
    );
    final transfer = WorkHomeTransfer(
      id: 'dashboard-transfer',
      amount: Money.fromMinorUnits(750),
      transferredAt: DateTime(2026, 10, 10),
    );
    final bill = HomeBill(
      id: 'dashboard-rent',
      title: 'Rent',
      kind: HomeBillKind.rent,
      amount: Money.fromMinorUnits(580),
      dueMonth: month,
    );
    final debt = DebtEntry(
      id: 'dashboard-debt',
      direction: DebtDirection.creditor,
      originalAmount: Money.fromMinorUnits(300),
      outstandingAmount: Money.fromMinorUnits(200),
      dueMonth: month,
      createdAt: DateTime(2026, 10, 5),
      counterparty: 'Test',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workEntriesProvider.overrideWith((ref) => Stream.value([salary])),
          homeExpensesProvider.overrideWith((ref) => Stream.value([expense])),
          workTransfersProvider.overrideWith((ref) => Stream.value([transfer])),
          debtsProvider.overrideWith((ref) => Stream.value([debt])),
          homeBillsProvider.overrideWith((ref) async => [bill]),
          homeBillPaymentsForMonthProvider.overrideWith((ref, selected) async => 0),
          selectedMonthProvider.overrideWith(
            () => _FixedDashboardMonthNotifier(month),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-content')), findsOneWidget);
    expect(find.text(month.toString()), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-home-balance'))).data,
      '20',
    );
    expect(find.text('الصورة المالية'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('dashboard-content')),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();
    expect(find.text('آخر العمليات'), findsOneWidget);
  });
}

class _FixedDashboardMonthNotifier extends SelectedMonthNotifier {
  _FixedDashboardMonthNotifier(this.month);

  final MonthKey month;

  @override
  MonthKey build() => month;

  @override
  void select(MonthKey selected) => state = selected;
}
