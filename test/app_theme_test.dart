import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('all 77 supplied presets build light and dark Material 3 themes', () {
    expect(builtInThemePresets, hasLength(77));
    for (final preset in builtInThemePresets) {
      final light = AppTheme.lightFor(preset);
      final dark = AppTheme.darkFor(preset);

      expect(light.useMaterial3, isTrue, reason: preset.id);
      expect(dark.useMaterial3, isTrue, reason: preset.id);
      expect(light.brightness, Brightness.light, reason: preset.id);
      expect(dark.brightness, Brightness.dark, reason: preset.id);
      expect(light.extension<AppDesignTokens>(), isNotNull);
      expect(dark.extension<AppDesignTokens>(), isNotNull);
      expect(
        AppTheme.contrastRatio(
          light.colorScheme.onSurface,
          light.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Light text contrast for ${preset.id}',
      );
      expect(
        AppTheme.contrastRatio(
          dark.colorScheme.onSurface,
          dark.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark text contrast for ${preset.id}',
      );
      expect(
        AppTheme.contrastRatio(
          light.colorScheme.onSurfaceVariant,
          light.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Light muted text contrast for ${preset.id}',
      );
      expect(
        AppTheme.contrastRatio(
          light.colorScheme.onPrimary,
          light.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Light button contrast for ${preset.id}',
      );
      expect(
        AppTheme.contrastRatio(
          dark.colorScheme.onSurfaceVariant,
          dark.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark muted text contrast for ${preset.id}',
      );
      expect(
        AppTheme.contrastRatio(
          dark.colorScheme.onPrimary,
          dark.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark button contrast for ${preset.id}',
      );
    }
  });

  test('component geometry is fixed independently of selected theme', () {
    final first = AppTheme.lightFor(builtInThemePresets.first);
    final second = AppTheme.darkFor(builtInThemePresets[36]);
    final firstTokens = first.extension<AppDesignTokens>()!;
    final secondTokens = second.extension<AppDesignTokens>()!;

    expect(secondTokens.pageHorizontalPadding,
        firstTokens.pageHorizontalPadding);
    expect(secondTokens.sectionSpacing, firstTokens.sectionSpacing);
    expect(secondTokens.inputVerticalPadding,
        firstTokens.inputVerticalPadding);
    expect(secondTokens.cardPadding, firstTokens.cardPadding);
    expect(firstTokens.cardRadius, 24);
    expect(firstTokens.controlRadius, 24);
    expect(firstTokens.dialogRadius, 24);
    expect(
      second.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
      48,
    );
  });

  test('custom seeds and unknown stored ids resolve safely', () {
    final custom = AppThemePreset.fromSeedColor(
      const Color(0xFFB326D8),
      id: 'custom-test',
      nameAr: 'ثيمي',
      nameEn: 'My theme',
    );
    expect(custom.custom, isTrue);
    expect(themePresetById(custom.id, customThemes: [custom]), custom);
    expect(themePresetById('unknown').id, 'purple-pro');
    expect(themePresetById('navy_gold').id, 'cobalt');
  });

  test('imports the JSON structure exported by the supplied HTML studio', () {
    final imported = AppThemePreset.fromJson({
      'name': 'ثيم مستورد',
      'seed': {
        'h': 300,
        'h2': 345,
        'c': .20,
        'ca': .21,
        'dh': 100,
      },
      'bg': 'stars',
      'fx': {'l': 1, 'g': true, 'v': 0, 'f': true},
    });

    expect(imported.nameAr, 'ثيم مستورد');
    expect(imported.hue, 300);
    expect(imported.accentHue, 345);
    expect(imported.chroma, .20);
    expect(imported.accentChroma, .21);
    expect(imported.hueOffset, 100);
    expect(imported.background, 'stars');
    expect(imported.effects, 'lgf');
    expect(imported.custom, isTrue);
  });
}
