import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.location,
    required this.navigationShell,
    super.key,
  });

  final String location;
  final StatefulNavigationShell navigationShell;

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.work_outline,
    Icons.home_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.auto_awesome_outlined,
  ];
  static const _selectedIcons = [
    Icons.dashboard_rounded,
    Icons.work_rounded,
    Icons.home_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.auto_awesome_rounded,
  ];

  int get _selectedIndex {
    return switch (location) {
      '/work' => 1,
      '/home' => 2,
      '/debts' => 3,
      '/ai' => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final tokens = AppDesignTokens.of(context);
    final labels = [
      strings.dashboard,
      strings.work,
      strings.homeSection,
      strings.debts,
      strings.ai,
    ];

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(labels[_selectedIndex]),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            key: const Key('open-calculator'),
            tooltip: strings.calculator,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final value = await showAmountCalculator(context, strings);
              if (!context.mounted || value == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${strings.result}: $value')),
              );
            },
          ),
          IconButton(
            key: const Key('open-calendar'),
            tooltip: strings.calendar,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final current = ref.read(selectedMonthProvider);
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(current.year, current.month, 1),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked == null || !context.mounted) return;
              ref.read(selectedMonthProvider.notifier).select(
                    MonthKey(year: picked.year, month: picked.month),
                  );
            },
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 72,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(index),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                destinations: List.generate(
                  labels.length,
                  (index) => NavigationDestination(
                    icon: Icon(_icons[index]),
                    selectedIcon: Icon(_selectedIcons[index]),
                    label: labels[index],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
