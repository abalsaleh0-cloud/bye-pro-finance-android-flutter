import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/core/widgets/section_pill_tabs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final isDark in [false, true]) {
    testWidgets(
      'section tabs use rounded selected pills in ${isDark ? 'dark' : 'light'} mode',
      (tester) async {
        final theme = isDark ? AppTheme.dark : AppTheme.light;
        var selectedIndex = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Theme(
              data: theme,
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: SectionPillTabs(
                    keyPrefix: 'test-tab',
                    labels: const ['Overview', 'Transfers', 'History'],
                    selectedIndex: selectedIndex,
                    onSelected: (index) {
                      setState(() => selectedIndex = index);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        AnimatedContainer selectedPill() => tester.widget<AnimatedContainer>(
              find.byKey(const Key('test-tab-pill-1')),
            );
        BoxDecoration pillDecoration() =>
            selectedPill().decoration! as BoxDecoration;

        expect(
          pillDecoration().borderRadius,
          BorderRadius.circular(
            AppDesignTokens.standard().controlRadius,
          ),
        );
        expect(pillDecoration().color, theme.colorScheme.primaryContainer);
        expect(
          tester.widget<Text>(find.text('Transfers')).style!.color,
          theme.colorScheme.onPrimaryContainer,
        );

        await tester.tap(find.byKey(const Key('test-tab-0')));
        await tester.pumpAndSettle();

        expect(
          (tester.widget<AnimatedContainer>(
            find.byKey(const Key('test-tab-pill-0')),
          ).decoration! as BoxDecoration)
              .color,
          theme.colorScheme.primaryContainer,
        );
        expect(
          (tester.widget<AnimatedContainer>(
            find.byKey(const Key('test-tab-pill-1')),
          ).decoration! as BoxDecoration)
              .color,
          Colors.transparent,
        );
      },
    );
  }
}
