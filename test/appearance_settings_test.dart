import 'package:drift/native.dart';
import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppDatabase testDatabase;

  setUp(() {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
  });


  testWidgets('only the three app appearance modes are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(() => testDatabase.close());
          return testDatabase;
        })],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

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
