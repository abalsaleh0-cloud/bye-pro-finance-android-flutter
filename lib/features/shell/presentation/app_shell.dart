import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.navigationShell,
    super.key,
  });

  final String location;
  final StatefulNavigationShell navigationShell;

  static const _paths = ['/dashboard', '/work', '/home', '/debts', '/ai'];
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
    final index = _paths.indexOf(location);
    return index < 0 ? navigationShell.currentIndex : index;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final labels = [
      strings.dashboard,
      strings.work,
      strings.homeSection,
      strings.debts,
      strings.ai,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(labels[_selectedIndex]),
        actions: [
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
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: List.generate(
          _paths.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            selectedIcon: Icon(_selectedIcons[index]),
            label: labels[index],
          ),
        ),
      ),
    );
  }
}
