import 'dart:async';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('ar'),
  });

  final ThemeMode themeMode;
  final Locale locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
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

  Future<void> _restore(dynamic database) async {
    try {
      final values = await Future.wait<String?>([
        database.readSetting('theme_mode') as Future<String?>,
        database.readSetting('locale') as Future<String?>,
      ]);
      if (_revision != 0) return;
      state = AppSettings(
        themeMode: values[0] == 'dark' ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(values[1] == 'en' ? 'en' : 'ar'),
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

  void setLocale(Locale locale) {
    _revision++;
    state = state.copyWith(locale: locale);
    unawaited(ref.read(appDatabaseProvider).writeSetting(
      'locale', locale.languageCode == 'en' ? 'en' : 'ar',
    ));
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
