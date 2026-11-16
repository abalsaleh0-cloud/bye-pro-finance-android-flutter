import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  test('appearance mode is applied immediately and saved locally', () async {
    final controller = container.read(appSettingsProvider.notifier);
    controller.setThemeMode(ThemeMode.dark);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    await database.readSetting('theme_mode');
    expect(await database.readSetting('theme_mode'), 'dark');

    controller.setThemeMode(ThemeMode.light);
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
    await database.readSetting('theme_mode');
    expect(await database.readSetting('theme_mode'), 'light');
  });
}
