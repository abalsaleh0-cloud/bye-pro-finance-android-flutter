import 'dart:async';
import 'dart:convert';

import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
    this.useGemma = false,
    this.themeId = 'purple-pro',
    this.customThemes = const [],
    this.backgroundId = 'aurora',
    this.backgroundSpeed = 1,
    this.energySaving = false,
    this.colorGrade = '',
    this.cinemaEffects = const {},
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool useGemma;
  final String themeId;
  final List<AppThemePreset> customThemes;
  final String backgroundId;
  final double backgroundSpeed;
  final bool energySaving;
  final String colorGrade;
  final Set<String> cinemaEffects;

  AppThemePreset get selectedTheme =>
      themePresetById(themeId, customThemes: customThemes);

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? useGemma,
    String? themeId,
    List<AppThemePreset>? customThemes,
    String? backgroundId,
    double? backgroundSpeed,
    bool? energySaving,
    String? colorGrade,
    Set<String>? cinemaEffects,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      useGemma: useGemma ?? this.useGemma,
      themeId: themeId ?? this.themeId,
      customThemes: customThemes ?? this.customThemes,
      backgroundId: backgroundId ?? this.backgroundId,
      backgroundSpeed: backgroundSpeed ?? this.backgroundSpeed,
      energySaving: energySaving ?? this.energySaving,
      colorGrade: colorGrade ?? this.colorGrade,
      cinemaEffects: cinemaEffects ?? this.cinemaEffects,
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
        database.readSetting('theme_background'),
        database.readSetting('theme_background_speed'),
        database.readSetting('theme_energy_saving'),
        database.readSetting('theme_color_grade'),
        database.readSetting('theme_cinema_effects'),
        // Read the old preference once for a graceful upgrade.
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

      final oldPreset = values[10];
      final savedTheme = values[3] ??
          switch (oldPreset) {
            'navy_gold' => 'cobalt',
            'emerald' => 'emerald',
            'graphite' => 'charcoal',
            _ => 'purple-pro',
          };
      final selectedTheme =
          themePresetById(savedTheme, customThemes: customThemes);

      Set<String> effects = selectedTheme.effects.split('').toSet();
      try {
        final decoded = jsonDecode(values[9] ?? 'null');
        if (decoded is List) {
          effects = decoded.whereType<String>().toSet();
        }
      } catch (_) {
        // Use the selected preset's default cinematic effects.
      }

      final speed = double.tryParse(values[6] ?? '') ?? 1;
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
        backgroundId: values[5] ?? selectedTheme.background,
        backgroundSpeed: speed.clamp(.3, 1.8).toDouble(),
        energySaving: values[7] == 'true',
        colorGrade: values[8] ?? '',
        cinemaEffects: effects,
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
    final effects = preset.effects.split('').toSet();
    state = state.copyWith(
      themeId: preset.id,
      backgroundId: preset.background,
      cinemaEffects: effects,
    );
    unawaited(_write('theme_id', preset.id));
    unawaited(_write('theme_background', preset.background));
    unawaited(_write('theme_cinema_effects', jsonEncode(effects.toList())));
  }

  void addCustomTheme(AppThemePreset preset) {
    if (state.customThemes.length >= 12) return;
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
      backgroundId: wasSelected ? fallback.background : state.backgroundId,
      cinemaEffects: wasSelected
          ? fallback.effects.split('').toSet()
          : state.cinemaEffects,
    );
    _persistCustomThemes(themes);
    if (wasSelected) {
      unawaited(_write('theme_id', fallback.id));
      unawaited(_write('theme_background', fallback.background));
    }
  }

  void setBackground(String id) {
    _revision++;
    state = state.copyWith(backgroundId: id);
    unawaited(_write('theme_background', id));
  }

  void setBackgroundSpeed(double value) {
    _revision++;
    final speed = value.clamp(.3, 1.8).toDouble();
    state = state.copyWith(backgroundSpeed: speed);
    unawaited(_write('theme_background_speed', speed.toStringAsFixed(1)));
  }

  void setEnergySaving(bool enabled) {
    _revision++;
    state = state.copyWith(energySaving: enabled);
    unawaited(_write('theme_energy_saving', enabled.toString()));
  }

  void toggleCinemaEffect(String id, bool enabled) {
    _revision++;
    final effects = Set<String>.from(state.cinemaEffects);
    if (enabled) {
      effects.add(id);
    } else {
      effects.remove(id);
    }
    state = state.copyWith(cinemaEffects: effects);
    unawaited(_write('theme_cinema_effects', jsonEncode(effects.toList())));
  }

  void setColorGrade(String value) {
    _revision++;
    state = state.copyWith(colorGrade: value);
    unawaited(_write('theme_color_grade', value));
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
