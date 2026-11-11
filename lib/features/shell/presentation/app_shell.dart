import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _paths = ['/dashboard', '/work', '/home', '/debts', '/ai'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.work_outline,
    Icons.home_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.auto_awesome_outlined,
  ];

  int get _selectedIndex {
    final index = _paths.indexOf(location);
    return index < 0 ? 0 : index;
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
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: List.generate(
          _paths.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: labels[index],
          ),
        ),
      ),
    );
  }
}
