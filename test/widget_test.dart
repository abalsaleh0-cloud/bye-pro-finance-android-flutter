import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('starts in Arabic with five navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-calculator')), findsOneWidget);
  });

  testWidgets('global calculator is available and returns a result', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.tap(find.byKey(const Key('open-calculator')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('احسب'));
    await tester.pumpAndSettle();

    expect(find.text('النتيجة: 42'), findsOneWidget);
    await tester.tap(find.text('استخدام النتيجة'));
    await tester.pumpAndSettle();
    expect(find.text('النتيجة: 42'), findsOneWidget);
  });

  testWidgets('settings can switch theme and language', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

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
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workEntriesProvider.overrideWith((ref) => Stream.value([entry])),
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    await tester.tap(find.byKey(const Key('home-tab-3')));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة اختبار'), findsOneWidget);
    expect(find.textContaining('ملاحظة فاتورة مباشرة'), findsOneWidget);
  });

}

class _FixedSelectedMonthNotifier extends SelectedMonthNotifier {
  _FixedSelectedMonthNotifier(this.month);

  final MonthKey month;

  @override
  MonthKey build() => month;
}
