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
  @override
  AppSettings build() => const AppSettings();

  void setDarkMode(bool enabled) {
    state = state.copyWith(
      themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
