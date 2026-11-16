import 'dart:async';

import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/router/app_router.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) {
        final brightness = switch (settings.themeMode) {
          ThemeMode.dark => Brightness.dark,
          ThemeMode.light => Brightness.light,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        if (defaultTargetPlatform == TargetPlatform.android) {
          unawaited(_LauncherIconSync.update(
            brightness == Brightness.dark ? 'dark' : 'light',
          ));
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}


/// Keeps the Android launcher artwork in sync with the actual app appearance.
class _LauncherIconSync {
  static const MethodChannel _channel =
      MethodChannel('com.byepro.finance/app_icon');
  static String? _lastApplied;

  static Future<void> update(String mode) async {
    if (_lastApplied == mode) return;
    _lastApplied = mode;
    try {
      await _channel.invokeMethod<void>('setAppIcon', {'mode': mode});
    } catch (_) {
      _lastApplied = null;
      // The Android bridge may be unavailable during early startup.
    }
  }
}
