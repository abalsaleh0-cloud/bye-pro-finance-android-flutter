import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Telegram Blue light and Dark Blue palettes are fixed', () {
    final light = AppTheme.light.colorScheme;
    final dark = AppTheme.dark.colorScheme;

    expect(light.primary, const Color(0xFF229AF0));
    expect(light.onPrimary, const Color(0xFF102A3D));
    expect(light.surface, Colors.white);
    expect(light.onSurface, const Color(0xFF1A1D21));
    expect(light.onSurfaceVariant, const Color(0xFF757575));
    expect(light.surfaceDim, const Color(0xFFF1F1F3));
    expect(light.tertiaryContainer, const Color(0xFFEFFFDE));
    expect(light.outlineVariant, const Color(0xFFD9D9D9));

    expect(dark.primary, const Color(0xFF64B5EF));
    expect(dark.surface, const Color(0xFF1D2733));
    expect(dark.surfaceContainer, const Color(0xFF242D39));
    expect(dark.onSurface, const Color(0xFFFAFAFA));
    expect(dark.onSurfaceVariant, const Color(0xFF9AA8B6));
    expect(dark.surfaceDim, const Color(0xFF151E27));
    expect(dark.surfaceContainerHigh, const Color(0xFF232E3B));
    expect(dark.tertiaryContainer, const Color(0xFF3E618A));
  });

  test('light and dark themes retain readable text contrast', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(
        AppTheme.contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppTheme.contrastRatio(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppTheme.contrastRatio(
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('all component geometry stays identical across appearances', () {
    final light = AppTheme.light.extension<AppDesignTokens>()!;
    final dark = AppTheme.dark.extension<AppDesignTokens>()!;

    expect(dark.pageHorizontalPadding, light.pageHorizontalPadding);
    expect(dark.pageVerticalPadding, light.pageVerticalPadding);
    expect(dark.sectionSpacing, light.sectionSpacing);
    expect(dark.cardRadius, light.cardRadius);
    expect(dark.controlRadius, light.controlRadius);
    expect(dark.dialogRadius, light.dialogRadius);
    expect(dark.cardPadding, light.cardPadding);
    expect(dark.inputVerticalPadding, light.inputVerticalPadding);
    expect(dark.buttonHeight, light.buttonHeight);
    expect(dark.touchTargetSize, light.touchTargetSize);
    expect(dark.navigationBarHeight, light.navigationBarHeight);
    expect(dark.sectionTabHeight, light.sectionTabHeight);
    expect(dark.metricTileMinHeight, light.metricTileMinHeight);
    expect(dark.recordIconBoxSize, light.recordIconBoxSize);
    expect(dark.standardIconSize, light.standardIconSize);
  });

  test('error and success colors are semantic states, not brand accents', () {
    expect(AppTheme.light.colorScheme.error, const Color(0xFFCC4747));
    expect(AppTheme.dark.colorScheme.error, const Color(0xFFFF6D6D));
    expect(AppTheme.light.colorScheme.tertiary, const Color(0xFF26972C));
    expect(
      AppTheme.light.colorScheme.secondary,
      const Color(0xFF757575),
    );
    expect(
      AppTheme.dark.colorScheme.secondary,
      const Color(0xFF9AA8B6),
    );
  });
}
