import 'package:drift/native.dart';
import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
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
    await testDatabase.writeSetting('welcome_seen', 'true');
  });

  tearDownAll(() async {
    await testDatabase.close();
  });


  _testWidgetsWithDriftCleanup('only the three app appearance modes are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    // Backup/restore and app-lock controls must be visible in the real
    // Settings screen, not merely implemented as unused widgets.
    expect(find.text('النسخ الاحتياطي والاستعادة'), findsOneWidget);
    expect(find.text('قفل التطبيق'), findsOneWidget);
    await tester.ensureVisible(find.text('إنشاء نسخة احتياطية'));
    expect(find.text('إنشاء نسخة احتياطية'), findsOneWidget);
    await tester.ensureVisible(find.text('تعيين رمز PIN'));
    expect(find.text('تعيين رمز PIN'), findsOneWidget);
    expect(find.text('فتح التطبيق بالبصمة'), findsOneWidget);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(5),
    );
    expect(find.text('لوحات إضافية'), findsNothing);
    expect(find.byKey(const Key('create-theme-from-color')), findsNothing);
    expect(find.byKey(const Key('import-theme-json')), findsNothing);
    expect(find.byKey(const Key('theme-mode-selector')), findsOneWidget);

    await tester.ensureVisible(find.text('الوضع الداكن'));
    await tester.tap(find.text('الوضع الداكن'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MyApp));
    final settings = ProviderScope.containerOf(context, listen: false)
        .read(appSettingsProvider);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(settings.themeMode, ThemeMode.dark);
    expect(app.themeMode, ThemeMode.dark);

    await tester.ensureVisible(find.text('الوضع الفاتح'));
    await tester.tap(find.text('الوضع الفاتح'));
    await tester.pumpAndSettle();

    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.light);
  });
}
