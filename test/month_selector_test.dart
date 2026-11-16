import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('month is displayed as a plain title and chosen in a sheet', (
    tester,
  ) async {
    final selectedMonth = MonthKey(year: 2026, month: 11);
    final historicalMonth = MonthKey(year: 2024, month: 3);
    MonthKey? changedMonth;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MonthSelector(
            pickerKey: const Key('shared-month-picker'),
            selectedMonth: selectedMonth,
            availableMonths: [selectedMonth, historicalMonth],
            onChanged: (value) => changedMonth = value,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('shared-month-picker')), findsOneWidget);
    expect(find.byKey(const Key('month-selector-date-control')), findsNothing);
    expect(find.byKey(const Key('month-selector-official-calendar')), findsOneWidget);
    expect(find.text(selectedMonth.toString()), findsNothing);

    await tester.tap(find.byKey(const Key('shared-month-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('month-option-$historicalMonth')), findsOneWidget);

    await tester.tap(find.byKey(const Key('month-option-$historicalMonth')));
    await tester.pumpAndSettle();
    expect(changedMonth, historicalMonth);
  });

  testWidgets('summary metric grid presents labeled amounts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryMetricGrid(
            metrics: const [
              SummaryMetricData(
                title: 'Salary',
                value: '125000',
                icon: Icons.payments_outlined,
              ),
              SummaryMetricData(
                title: 'Remaining',
                value: '45000',
                icon: Icons.account_balance_wallet_outlined,
                emphasized: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('125000'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('45000'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('summary-metric-row-0'))).height,
      64,
    );
    expect(
      tester.getSize(find.byKey(const Key('summary-metric-row-1'))).height,
      64,
    );
  });
}
