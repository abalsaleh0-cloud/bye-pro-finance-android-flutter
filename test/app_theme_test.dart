import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AppTheme', () {
    test('light and dark themes use the shared navy and gold identity', () {
      expect(AppTheme.dark.colorScheme.primary, const Color(0xFFD4A62A));
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF071326));
      expect(
        AppTheme.light.colorScheme.secondary,
        const Color(0xFF8A650E),
      );
    });

    test('shared surfaces and form fields have consistent styling', () {
      expect(AppTheme.light.cardTheme.elevation, 0);
      expect(AppTheme.dark.cardTheme.elevation, 0);
      expect(AppTheme.light.cardTheme.margin, EdgeInsets.zero);
      expect(AppTheme.light.inputDecorationTheme.filled, isTrue);
      expect(AppTheme.dark.inputDecorationTheme.filled, isTrue);
      expect(AppTheme.light.navigationBarTheme.height, 72);
      expect(AppTheme.dark.navigationBarTheme.height, 72);
    });

    test('buttons and dialogs use the common rounded component shapes', () {
      expect(AppTheme.light.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(AppTheme.dark.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(
        AppTheme.light.filledButtonTheme.style?.minimumSize,
        isNotNull,
      );
      expect(
        AppTheme.dark.outlinedButtonTheme.style?.minimumSize,
        isNotNull,
      );
    });
  });
}
