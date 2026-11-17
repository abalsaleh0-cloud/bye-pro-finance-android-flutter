import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the fixed BYE PRO light and dark themes have readable contrast', () {
    final light = AppTheme.light;
    final dark = AppTheme.dark;

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);

    for (final theme in [light, dark]) {
      expect(theme.extension<AppDesignTokens>(), isNotNull);
      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.onSurface,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.onPrimary,
          theme.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('component geometry is fixed across light and dark modes', () {
    final lightTokens = AppTheme.light.extension<AppDesignTokens>()!;
    final darkTokens = AppTheme.dark.extension<AppDesignTokens>()!;

    expect(darkTokens.pageHorizontalPadding, lightTokens.pageHorizontalPadding);
    expect(darkTokens.sectionSpacing, lightTokens.sectionSpacing);
    expect(darkTokens.inputVerticalPadding, lightTokens.inputVerticalPadding);
    expect(darkTokens.cardPadding, lightTokens.cardPadding);
    expect(lightTokens.cardRadius, 16);
    expect(lightTokens.controlRadius, 12);
    expect(lightTokens.dialogRadius, 20);
    expect(lightTokens.buttonHeight, 48);
    expect(lightTokens.touchTargetSize, 44);
    expect(lightTokens.navigationBarHeight, 68);
    expect(lightTokens.sectionTabHeight, 48);
    expect(lightTokens.metricTileMinHeight, 64);
    expect(lightTokens.recordIconBoxSize, 40);
    expect(lightTokens.standardIconSize, 20);
    expect(darkTokens.buttonHeight, lightTokens.buttonHeight);
    expect(darkTokens.touchTargetSize, lightTokens.touchTargetSize);
    expect(darkTokens.navigationBarHeight, lightTokens.navigationBarHeight);
    expect(darkTokens.sectionTabHeight, lightTokens.sectionTabHeight);
    expect(darkTokens.metricTileMinHeight, lightTokens.metricTileMinHeight);
    expect(darkTokens.recordIconBoxSize, lightTokens.recordIconBoxSize);
    expect(darkTokens.standardIconSize, lightTokens.standardIconSize);
  });

  test('gold accent adapts for contrast in both appearances', () {
    expect(
      AppTheme.light.colorScheme.secondary,
      isNot(AppTheme.dark.colorScheme.secondary),
    );
    expect(
      AppTheme.contrastRatio(
        AppTheme.light.colorScheme.onSecondary,
        AppTheme.light.colorScheme.secondary,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      AppTheme.contrastRatio(
        AppTheme.dark.colorScheme.onSecondary,
        AppTheme.dark.colorScheme.secondary,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
}
