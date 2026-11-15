import 'dart:async';

import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('ar'),
    this.useGemma = false,
    this.themePreset = AppThemePreset.navyGold,
    this.density = AppDensity.comfortable,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool useGemma;
  final AppThemePreset themePreset;
  final AppDensity density;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? useGemma,
    AppThemePreset? themePreset,
    AppDensity? density,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      useGemma: useGemma ?? this.useGemma,
      themePreset: themePreset ?? this.themePreset,
      density: density ?? this.density,
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
        database.readSetting('appearance_preset'),
        database.readSetting('appearance_density'),
      ]);
      if (_revision != 0) return;
      state = AppSettings(
        themeMode: values[0] == 'dark' ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(values[1] == 'en' ? 'en' : 'ar'),
        useGemma: values[2] == 'gemma',
        themePreset: AppThemePreset.fromStorage(values[3]),
        density: AppDensity.fromStorage(values[4]),
      );
    } catch (_) {
      // Keep safe defaults if the local settings table cannot be read.
    }
  }

  void setDarkMode(bool enabled) {
    _revision++;
    state = state.copyWith(
      themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
    );
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'theme_mode', enabled ? 'dark' : 'light',
    ));
  }

  void setThemePreset(AppThemePreset preset) {
    _revision++;
    state = state.copyWith(themePreset: preset);
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'appearance_preset', preset.storageKey,
    ));
  }

  void setDensity(AppDensity density) {
    _revision++;
    state = state.copyWith(density: density);
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'appearance_density', density.storageKey,
    ));
  }

  void setLocale(Locale locale) {
    _revision++;
    state = state.copyWith(locale: locale);
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'locale', locale.languageCode == 'en' ? 'en' : 'ar',
    ));
  }

  void setGemmaEnabled(bool enabled) {
    _revision++;
    state = state.copyWith(useGemma: enabled);
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'ai_engine', enabled ? 'gemma' : 'fake',
    ));
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
