import 'package:drift/native.dart';
import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/home/data/home_bill_repository.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.readSetting('widget-test-ready');
    await database.writeSetting('welcome_seen', 'true');
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows only due unpaid household bills and debts, with working search', (tester) async {
    final now = DateTime.now();
    final previousDate = DateTime(now.year, now.month - 1, 10);
    final futureDate = DateTime(now.year, now.month + 1, 10);
    final previousMonth = MonthKey(year: previousDate.year, month: previousDate.month);
    final futureMonth = MonthKey(year: futureDate.year, month: futureDate.month);

    final bills = HomeBillRepository(database);
    await bills.saveBill(HomeBill(
      id: 'widget-arrears-household-old',
      title: 'فاتورة قديمة',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(500),
      dueMonth: previousMonth,
    ));
    await bills.saveBill(HomeBill(
      id: 'widget-arrears-household-future',
      title: 'فاتورة مستقبلية',
      kind: HomeBillKind.monthly,
      amount: Money.fromMinorUnits(700),
      dueMonth: futureMonth,
    ));

    final debts = DebtRepository(database);
    await debts.save(DebtEntry(
      id: 'widget-arrears-debt-old',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(900),
      outstandingAmount: Money.fromMinorUnits(400),
      dueMonth: previousMonth,
      createdAt: previousDate,
      counterparty: 'دين سابق',
    ));
    await debts.save(DebtEntry(
      id: 'widget-arrears-debt-future',
      direction: DebtDirection.debtor,
      originalAmount: Money.fromMinorUnits(1200),
      outstandingAmount: Money.fromMinorUnits(1200),
      dueMonth: futureMonth,
      createdAt: futureDate,
      counterparty: 'دين مستقبلي',
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MyApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المنزل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة قديمة'), findsOneWidget);
    expect(find.text('فاتورة مستقبلية'), findsNothing);

    await tester.enterText(find.byKey(const Key('home-record-search')), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('فاتورة قديمة'), findsNothing);

    await tester.tap(find.text('الديون').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('debts-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('دين سابق'), findsOneWidget);
    expect(find.text('دين مستقبلي'), findsNothing);

    await tester.enterText(find.byKey(const Key('debt-record-search')), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('دين سابق'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('main sections remain buildable on a compact 320dp viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MyApp(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final section in ['العمل', 'المنزل', 'الديون', 'الذكاء الاصطناعي']) {
      await tester.tap(find.text(section).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Compact layout failed in $section');
    }

    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
