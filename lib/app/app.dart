import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/router/app_router.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/core/theme/theme_backdrop.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
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
      theme: AppTheme.lightFor(settings.selectedTheme),
      darkTheme: AppTheme.darkFor(settings.selectedTheme),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ThemeBackdrop(
                backgroundId: settings.backgroundId,
                speed: settings.backgroundSpeed,
                energySaving: settings.energySaving,
                effects: settings.cinemaEffects,
                colorGrade: settings.colorGrade,
              ),
            ),
            Positioned.fill(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
      routerConfig: router,
    );
  }
}
