import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('dark-mode-switch'),
            title: Text(strings.darkTheme),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: controller.setDarkMode,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(strings.language),
            trailing: DropdownButton<Locale>(
              key: const Key('language-selector'),
              value: settings.locale,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: const Locale('ar'),
                  child: Text(strings.arabic),
                ),
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(strings.english),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.setLocale(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
