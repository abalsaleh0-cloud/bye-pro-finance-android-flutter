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

      state = AppSettings(
        themeMode: switch (values[0]) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.system,
        },
        locale: Locale(values[1] == 'en' ? 'en' : 'ar'),
        useGemma: values[2] == 'gemma',
      );
    } catch (_) {
      // Keep safe defaults if the local settings table cannot be read.
    }
  }

  /// Applies the selection immediately and completes only after it is saved.
  Future<void> setThemeMode(ThemeMode mode) async {
    _revision++;
    state = state.copyWith(themeMode: mode);
    await _write('theme_mode', switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
  }

  void setLocale(Locale locale) {
    _revision++;
    state = state.copyWith(locale: locale);
    unawaited(_write(
      'locale',
      locale.languageCode == 'en' ? 'en' : 'ar',
    ));
  }

  Future<void> setGemmaEnabled(bool enabled) async {
    _revision++;
    state = state.copyWith(useGemma: enabled);
    await _write('ai_engine', enabled ? 'gemma' : 'fake');
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
