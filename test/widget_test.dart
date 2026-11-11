import 'package:expense_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts in Arabic with five navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
  });

  testWidgets('settings can switch theme and language', (tester) async {
    await tester.pumpWidget(const MyApp());

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
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('bottom navigation changes the active section', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('العمل').last);
    await tester.pumpAndSettle();

    expect(find.text('العمل'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
