import 'dart:async';

import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// User preferences shared by the complete application.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
    this.useGemma = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool useGemma;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? useGemma,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      useGemma: useGemma ?? this.useGemma,
    );
  }
}

class AppSettingsController extends Notifier<AppSettings> {
  int _revision = 0;

  @override
  AppSettings build() {
    final database = ref.watch(appDatabaseProvider);
    unawaited(_restore(database));
    return const AppSettings();
  }

  Future<void> _restore(AppDatabase database) async {
    try {
      final values = await Future.wait<String?>([
        database.readSetting('theme_mode'),
        database.readSetting('locale'),
        database.readSetting('ai_engine'),
      ]);
      if (_revision != 0) return;

      // Remove obsolete palette-engine preferences while preserving the
      // selected Light/Dark/System mode and all financial records.
      try {
        await database.customStatement(
          "DELETE FROM app_settings "
          "WHERE setting_key IN ('theme_id', 'custom_themes', 'appearance_preset')",
        );
      } catch (_) {
        // Theme cleanup must never prevent restoring language or app mode.
      }

      state = AppSettings(
        themeMode: switch (values[0]) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        },
        locale: Locale(values[1] == 'en' ? 'en' : 'ar'),
        useGemma: values[2] == 'gemma',
      );
    } catch (_) {
      // Keep safe defaults if the local settings table cannot be read.
    }
  }

  void setThemeMode(ThemeMode mode) {
    _revision++;
    state = state.copyWith(themeMode: mode);
    unawaited(_write('theme_mode', switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    }));
  }

  void setLocale(Locale locale) {
    _revision++;
    state = state.copyWith(locale: locale);
    unawaited(_write(
      'locale',
      locale.languageCode == 'en' ? 'en' : 'ar',
    ));
  }

  void setGemmaEnabled(bool enabled) {
    _revision++;
    state = state.copyWith(useGemma: enabled);
    unawaited(_write('ai_engine', enabled ? 'gemma' : 'fake'));
  }

  Future<void> _write(String key, String value) async {
    try {
      await ref.read(appDatabaseProvider).writeSetting(key, value);
    } catch (_) {
      // A preference write must not interrupt normal finance operations.
    }
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);
