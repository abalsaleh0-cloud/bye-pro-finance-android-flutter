import 'package:expense_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shared bottom navigation has exactly five main sections', (
    tester,
  ) async {
    var selected = -1;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('floating-bottom-navigation')), findsOneWidget);
    final floatingBar = tester.getRect(
      find.byKey(const Key('floating-bottom-navigation')),
    );
    expect(floatingBar.left, greaterThan(0));
    expect(floatingBar.right, lessThan(tester.view.physicalSize.width /
        tester.view.devicePixelRatio));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('العمل'), findsOneWidget);
    expect(find.text('المنزل'), findsOneWidget);
    expect(find.text('الديون'), findsOneWidget);
    expect(find.text('الذكاء الاصطناعي'), findsOneWidget);

    await tester.tap(find.text('المنزل'));
    expect(selected, 2);
  });
}
