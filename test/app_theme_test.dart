import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('all presets build light and dark Material 3 themes', () {
    for (final preset in AppThemePreset.values) {
      for (final density in AppDensity.values) {
        final light = AppTheme.lightFor(preset: preset, density: density);
        final dark = AppTheme.darkFor(preset: preset, density: density);

        expect(light.useMaterial3, isTrue);
        expect(dark.useMaterial3, isTrue);
        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
        expect(light.extension<AppDesignTokens>(), isNotNull);
        expect(dark.extension<AppDesignTokens>(), isNotNull);
      }
    }
  });

  test('all screens use identical dimensions in every saved density mode', () {
    final comfortable = AppTheme.lightFor(
      density: AppDensity.comfortable,
    );
    final compact = AppTheme.lightFor(
      density: AppDensity.compact,
    );

    final comfortableTokens = comfortable.extension<AppDesignTokens>()!;
    final compactTokens = compact.extension<AppDesignTokens>()!;

    expect(compactTokens.pageHorizontalPadding,
        comfortableTokens.pageHorizontalPadding);
    expect(compactTokens.sectionSpacing, comfortableTokens.sectionSpacing);
    expect(compactTokens.inputVerticalPadding,
        comfortableTokens.inputVerticalPadding);
    expect(compactTokens.cardPadding, comfortableTokens.cardPadding);
    expect(compactTokens.cardRadius, 24);
    expect(compactTokens.controlRadius, 24);
    expect(compactTokens.dialogRadius, 24);
    expect(
      compact.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
      48,
    );
  });
  test('unknown saved appearance values fall back to the safe defaults', () {
    expect(
      AppThemePreset.fromStorage('unknown'),
      AppThemePreset.navyGold,
    );
    expect(
      AppDensity.fromStorage('unknown'),
      AppDensity.comfortable,
    );
  });
}
