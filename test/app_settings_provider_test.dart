import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AppThemePreset _customTheme({
  required String id,
  required String name,
  String effects = 'lgv',
}) {
  return AppThemePreset(
    id: id,
    nameAr: name,
    nameEn: name,
    hue: 210,
    accentHue: 190,
    chroma: .14,
    accentChroma: .14,
    hueOffset: 60,
    background: 'aurora',
    effects: effects,
    custom: true,
  );
}

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    container.read(appSettingsProvider);
    await database.readSetting('test-ready');
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('deleting selected custom theme persists fallback cinema effects', () async {
    final controller = container.read(appSettingsProvider.notifier);
    final customTheme = _customTheme(
      id: 'custom-effects-to-remove',
      name: 'Custom effects',
    );

    controller.addCustomTheme(customTheme);
    await database.readSetting('custom_themes');
    expect(
      await database.readSetting('theme_cinema_effects'),
      '["l","g","v"]',
    );

    controller.removeCustomTheme(customTheme.id);
    await database.readSetting('theme_id');

    expect(await database.readSetting('theme_id'), 'purple-pro');
    expect(await database.readSetting('theme_background'), 'aurora');
    expect(await database.readSetting('theme_cinema_effects'), '[]');
    expect(
      container.read(appSettingsProvider).cinemaEffects,
      isEmpty,
    );
  });

  test('replaces an existing custom theme when the 12-theme limit is reached', () async {
    final controller = container.read(appSettingsProvider.notifier);
    for (var index = 0; index < 12; index++) {
      controller.addCustomTheme(
        _customTheme(id: 'custom-$index', name: 'Theme $index'),
      );
    }

    controller.addCustomTheme(
      _customTheme(
        id: 'custom-0',
        name: 'Updated theme',
        effects: 'v',
      ),
    );

    final settings = container.read(appSettingsProvider);
    expect(settings.customThemes, hasLength(12));
    expect(
      settings.customThemes.singleWhere((theme) => theme.id == 'custom-0').nameEn,
      'Updated theme',
    );
    expect(settings.selectedTheme.id, 'custom-0');
  });
}
