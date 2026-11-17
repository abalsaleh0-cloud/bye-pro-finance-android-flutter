import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  String _text(BuildContext context, String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _text(context, 'مظهر التطبيق', 'App appearance'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              key: const Key('theme-mode-selector'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: Text(_text(context, 'تلقائي', 'System')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(_text(context, 'الوضع الفاتح', 'Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(_text(context, 'الوضع الداكن', 'Dark')),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  controller.setThemeMode(selection.first);
                }
              },
            ),
            const SizedBox(height: 9),
            Text(
              _text(
                context,
                'تتغير أيقونة التطبيق تلقائياً لتناسب المظهر المختار.',
                'The app icon automatically matches the selected appearance.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
