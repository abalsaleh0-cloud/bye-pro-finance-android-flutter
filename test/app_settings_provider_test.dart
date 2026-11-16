import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppThemePreset _customTheme({
  required String id,
  required String name,
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
    effects: 'lgv',
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

  test('deleting a selected custom palette persists the default fallback', () async {
    final controller = container.read(appSettingsProvider.notifier);
    final customTheme = _customTheme(
      id: 'custom-palette-to-remove',
      name: 'Custom palette',
    );

    controller.addCustomTheme(customTheme);
    await database.readSetting('custom_themes');
    expect(
      container.read(appSettingsProvider).selectedTheme.id,
      customTheme.id,
    );

    controller.removeCustomTheme(customTheme.id);
    await database.readSetting('theme_id');

    final settings = container.read(appSettingsProvider);
    expect(await database.readSetting('theme_id'), 'purple-pro');
    expect(settings.customThemes, isEmpty);
    expect(settings.selectedTheme.id, 'purple-pro');
  });

  test(
    'replaces an existing custom palette when the 12-theme limit is reached',
    () async {
      final controller = container.read(appSettingsProvider.notifier);
      for (var index = 0; index < 12; index++) {
        controller.addCustomTheme(
          _customTheme(id: 'custom-$index', name: 'Theme $index'),
        );
      }

      controller.addCustomTheme(
        _customTheme(id: 'custom-0', name: 'Updated theme'),
      );

      final settings = container.read(appSettingsProvider);
      expect(settings.customThemes, hasLength(12));
      expect(
        settings.customThemes
            .singleWhere((theme) => theme.id == 'custom-0')
            .nameEn,
        'Updated theme',
      );
      expect(settings.selectedTheme.id, 'custom-0');
    },
  );
}
