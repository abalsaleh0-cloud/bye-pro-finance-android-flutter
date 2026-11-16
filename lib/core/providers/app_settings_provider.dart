import 'dart:async';
import 'dart:convert';

import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Runtime appearance state is deliberately limited to useful app preferences.
/// Legacy animated-background keys remain untouched in storage for compatibility.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
    this.useGemma = false,
    this.themeId = 'purple-pro',
    this.customThemes = const [],
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool useGemma;
  final String themeId;
  final List<AppThemePreset> customThemes;

  AppThemePreset get selectedTheme =>
      themePresetById(themeId, customThemes: customThemes);

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? useGemma,
    String? themeId,
    List<AppThemePreset>? customThemes,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      useGemma: useGemma ?? this.useGemma,
      themeId: themeId ?? this.themeId,
      customThemes: customThemes ?? this.customThemes,
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
        database.readSetting('theme_id'),
        database.readSetting('custom_themes'),
        // Read the old palette preference for a graceful upgrade.
        database.readSetting('appearance_preset'),
      ]);
      if (_revision != 0) return;

      List<AppThemePreset> customThemes = [];
      try {
        final decoded = jsonDecode(values[4] ?? '[]');
        if (decoded is List) {
          customThemes = decoded
              .whereType<Map>()
              .map((item) => AppThemePreset.fromJson(
                    Map<String, Object?>.from(item),
                  ))
              .take(12)
              .toList();
        }
      } catch (_) {
        customThemes = [];
      }

      final oldPreset = values[5];
      final savedTheme = values[3] ??
          switch (oldPreset) {
            'navy_gold' => 'cobalt',
            'emerald' => 'emerald',
            'graphite' => 'charcoal',
            _ => 'purple-pro',
          };
      final selectedTheme =
          themePresetById(savedTheme, customThemes: customThemes);
      final mode = switch (values[0]) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

      state = AppSettings(
        themeMode: mode,
        locale: Locale(values[1] == 'en' ? 'en' : 'ar'),
        useGemma: values[2] == 'gemma',
        themeId: selectedTheme.id,
        customThemes: customThemes,
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

  void setTheme(AppThemePreset preset) {
    _revision++;
    state = state.copyWith(themeId: preset.id);
    unawaited(_write('theme_id', preset.id));
  }

  void addCustomTheme(AppThemePreset preset) {
    final replacesExisting = state.customThemes.any(
      (theme) => theme.id == preset.id,
    );
    if (state.customThemes.length >= 12 && !replacesExisting) return;
    _revision++;
    final themes = [
      ...state.customThemes.where((theme) => theme.id != preset.id),
      preset,
    ].take(12).toList();
    state = state.copyWith(customThemes: themes);
    _persistCustomThemes(themes);
    setTheme(preset);
  }

  void removeCustomTheme(String id) {
    _revision++;
    final themes =
        state.customThemes.where((theme) => theme.id != id).toList();
    final wasSelected = state.themeId == id;
    final fallback = builtInThemePresets.first;
    state = state.copyWith(
      customThemes: themes,
      themeId: wasSelected ? fallback.id : state.themeId,
    );
    _persistCustomThemes(themes);
    if (wasSelected) {
      unawaited(_write('theme_id', fallback.id));
    }
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

  void _persistCustomThemes(List<AppThemePreset> themes) {
    unawaited(_write(
      'custom_themes',
      jsonEncode(themes.map((theme) => theme.toJson()).toList()),
    ));
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);
