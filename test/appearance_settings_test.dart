import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('theme catalog and appearance mode update the app immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(5),
    );
    expect(find.byKey(const Key('theme-background-selector')), findsNothing);
    expect(find.byKey(const Key('theme-background-speed')), findsNothing);
    expect(find.byKey(const Key('theme-energy-saving')), findsNothing);
    expect(find.text('لوحات إضافية'), findsOneWidget);

    final emerald = find.byKey(const Key('theme-emerald'));
    await tester.ensureVisible(emerald);
    await tester.pumpAndSettle();
    await tester.tap(emerald);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(context, listen: false);
    final selectedTheme = container.read(appSettingsProvider).selectedTheme;
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme!.colorScheme.primary,
      AppTheme.lightFor(selectedTheme).colorScheme.primary,
    );

    final darkMode = find.text('الوضع الداكن');
    await tester.ensureVisible(find.byKey(const Key('theme-mode-selector')));
    await tester.pumpAndSettle();
    await tester.tap(darkMode);
    await tester.pumpAndSettle();

    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.dark);
    expect(
      updatedApp.darkTheme!.colorScheme.primary,
      AppTheme.darkFor(selectedTheme).colorScheme.primary,
    );
  });

  testWidgets('custom theme can be created from a seed color', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('create-theme-from-color'));
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seed-color-0')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MyApp));
    final settings = ProviderScope.containerOf(context, listen: false)
        .read(appSettingsProvider);
    expect(settings.customThemes, hasLength(1));
    expect(settings.selectedTheme.custom, isTrue);
  });

  testWidgets('imports theme JSON with a dialog-owned controller', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    final importButton = find.byKey(const Key('import-theme-json'));
    await tester.ensureVisible(importButton);
    await tester.pumpAndSettle();
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('theme-json-input')),
      '{"id":"imported-dialog-test","nameAr":"ثيم مستورد","nameEn":"Imported theme","hue":210,"accentHue":190,"chroma":0.14,"accentChroma":0.14,"hueOffset":60,"background":"aurora","effects":"v"}',
    );
    await tester.tap(find.text('استيراد'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MyApp));
    final settings = ProviderScope.containerOf(context, listen: false)
        .read(appSettingsProvider);
    expect(
      settings.customThemes.any((theme) => theme.id == 'imported-dialog-test'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

}
