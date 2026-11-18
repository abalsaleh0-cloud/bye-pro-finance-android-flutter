import 'dart:async';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:expense_app/features/settings/presentation/appearance_settings_section.dart';
import 'package:expense_app/features/settings/presentation/app_security_settings_section.dart';
import 'package:expense_app/features/settings/presentation/backup_restore_settings_section.dart';
import 'package:expense_app/features/settings/presentation/gemma_model_settings_section.dart';
import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
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

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: scheme.onPrimaryContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
        key: const Key('settings-list'),
        padding: tokens.pageInsets(
          bottom: tokens.pageVerticalPadding * 2,
        ),
        children: [
          _sectionHeader(
            context,
            title: strings.settingsAppearance,
            icon: Icons.palette_outlined,
          ),
          Card(
            child: ListTile(
              key: const Key('settings-language-tile'),
              minLeadingWidth: 40,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.language_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 19,
                ),
              ),
              title: Text(
                strings.language,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: DropdownButton<Locale>(
                key: const Key('language-selector'),
                value: settings.locale,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(tokens.dialogRadius),
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
          const SizedBox(height: 8),
          const AppearanceSettingsSection(),
          SizedBox(height: tokens.sectionSpacing + 4),
          _sectionHeader(
            context,
            title: strings.settingsAssistant,
            icon: Icons.auto_awesome_rounded,
          ),
          Card(
            child: SwitchListTile(
              key: const Key('settings-gemma-toggle'),
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16,
              ),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 19,
                ),
              ),
              title: Text(
                strings.gemmaEngine,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(strings.gemmaEngineDescription),
              value: settings.useGemma,
              onChanged: (enabled) {
                controller.setGemmaEnabled(enabled);
                if (!enabled) {
                  unawaited(
                    ref.read(gemmaModelManagerProvider.notifier).releaseModel(),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          const GemmaModelSettingsSection(),
          SizedBox(height: tokens.sectionSpacing + 4),
          _sectionHeader(
            context,
            title: strings.settingsData,
            icon: Icons.storage_rounded,
          ),
          const BackupRestoreSettingsSection(),
          SizedBox(height: tokens.sectionSpacing + 4),
          _sectionHeader(
            context,
            title: Localizations.localeOf(context).languageCode == 'en'
                ? 'Security'
                : 'الأمان',
            icon: Icons.shield_outlined,
          ),
          const AppSecuritySettingsSection(),
          SizedBox(height: tokens.sectionSpacing + 4),
          Card(
            child: ListTile(
              key: const Key('settings-clear-financial-data'),
              minLeadingWidth: 40,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 19,
                ),
              ),
              title: Text(
                strings.clearFinancialData,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(strings.clearFinancialDataWarning),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () => _clearFinancialData(context, ref, strings),
            ),
          ),
        ],
      ),
    );
  }
}
