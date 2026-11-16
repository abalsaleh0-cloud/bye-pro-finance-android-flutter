import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:expense_app/features/settings/presentation/appearance_settings_section.dart';
import 'package:expense_app/features/settings/presentation/gemma_model_settings_section.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearFinancialData(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.clearFinancialData),
        content: Text(strings.clearFinancialDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.clearFinancialData),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(appDatabaseProvider).clearFinancialData();
      ref.invalidate(homeBillsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.clearFinancialDataSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.dataError)),
        );
      }
    }
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final tokens = AppDesignTokens.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final requestedTab = int.tryParse(
      GoRouterState.of(context).uri.queryParameters['tab'] ?? '',
    );
    final activeTab =
        requestedTab != null && requestedTab >= 0 && requestedTab <= 4
            ? requestedTab
            : 0;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: activeTab,
        onDestinationSelected: (index) {
          const routes = ['/dashboard', '/work', '/home', '/debts', '/ai'];
          context.go(routes[index]);
        },
      ),
      body: ListView(
        padding: tokens.pageInsets(bottom: tokens.pageVerticalPadding * 2),
        children: [
          _sectionTitle(context, strings.settingsAppearance),
          const AppearanceSettingsSection(),
          SizedBox(height: tokens.sectionSpacing),
          Card(
            child: ListTile(
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
          ),
          SizedBox(height: tokens.sectionSpacing),
          _sectionTitle(context, strings.settingsAssistant),
          Card(
            child: SwitchListTile(
              key: const Key('gemma-engine-switch'),
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: Text(strings.gemmaEngine),
              subtitle: Text(strings.gemmaEngineDescription),
              value: settings.useGemma,
              onChanged: controller.setGemmaEnabled,
            ),
          ),
          const SizedBox(height: 10),
          const GemmaModelSettingsSection(),
          SizedBox(height: tokens.sectionSpacing),
          _sectionTitle(context, strings.settingsData),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(strings.clearFinancialData),
              subtitle: Text(strings.clearFinancialDataWarning),
              onTap: () => _clearFinancialData(context, ref, strings),
            ),
          ),
        ],
      ),
    );
  }
}
