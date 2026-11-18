import 'dart:async';

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

  test('persists explicit Gemma opt-in and opt-out', () async {
    final controller = container.read(appSettingsProvider.notifier);

    await controller.setGemmaEnabled(true);
    expect(container.read(appSettingsProvider).useGemma, isTrue);
    expect(await database.readSetting('ai_engine'), 'gemma');

    await controller.setGemmaEnabled(false);
    expect(container.read(appSettingsProvider).useGemma, isFalse);
    expect(await database.readSetting('ai_engine'), 'fake');
  });

  test('starts dark and persists light/dark selections before completing', () async {
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);

    final controller = container.read(appSettingsProvider.notifier);
    await controller.setThemeMode(ThemeMode.light);

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
    expect(await database.readSetting('theme_mode'), 'light');

    await controller.setThemeMode(ThemeMode.dark);
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    expect(await database.readSetting('theme_mode'), 'dark');

    await controller.setThemeMode(ThemeMode.light);
    expect(await database.readSetting('theme_mode'), 'light');

    // Simulate a process restart and make sure the saved choice is restored.
    container.dispose();
    final restored = Completer<void>();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    container.listen<AppSettings>(
      appSettingsProvider,
      (previous, next) {
        if (next.themeMode == ThemeMode.light && !restored.isCompleted) {
          restored.complete();
        }
      },
      fireImmediately: true,
    );
    await restored.future.timeout(const Duration(seconds: 2));
    expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
  });
}
