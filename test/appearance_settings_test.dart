import 'package:expense_app/app/app.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('appearance settings update the active app theme immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appearance-preset-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('زمردي').last);
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme!.colorScheme.primary,
      AppTheme.lightFor(preset: AppThemePreset.emerald).colorScheme.primary,
    );

    await tester.tap(find.byKey(const Key('appearance-density-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مضغوط').last);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final tokens = app.theme!.extension<AppDesignTokens>()!;
    expect(tokens.pageHorizontalPadding, 12);
    expect(tokens.cardPadding, 12);
  });
}
