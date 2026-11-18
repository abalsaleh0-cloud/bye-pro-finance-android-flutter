import 'dart:async';

import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/router/app_router.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/features/settings/presentation/app_security_gate.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  String? _lastScheduledIconMode;

  @override
  Widget build(BuildContext context) {
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
        final iconMode = brightness == Brightness.dark ? 'dark' : 'light';

        // PackageManager updates are Android side effects. Run them after the
        // current frame, never in the middle of MaterialApp's build.
        if (defaultTargetPlatform == TargetPlatform.android &&
            _lastScheduledIconMode != iconMode) {
          _lastScheduledIconMode = iconMode;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_LauncherIconSync.update(iconMode));
          });
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AppSecurityGate(
            child: child ?? const SizedBox.shrink(),
          ),
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
  static String? _lastQueued;
  static Future<void> _pending = Future<void>.value();

  static Future<void> update(String mode) {
    _pending = _pending.then((_) async {
      if (_lastQueued == mode) return;
      try {
        await _channel.invokeMethod<void>('queueAppIcon', {'mode': mode});
        _lastQueued = mode;
      } catch (_) {
        // Launcher icon support must never interrupt the finance app.
      }
    });
    return _pending;
  }
}
