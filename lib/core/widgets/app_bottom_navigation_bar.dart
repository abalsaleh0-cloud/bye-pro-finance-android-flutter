import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Shared, fixed-height five-destination navigation for every main section.
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final tokens = AppDesignTokens.of(context);
    final labels = [
      strings.dashboard,
      strings.work,
      strings.homeSection,
      strings.debts,
      strings.ai,
    ];
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: tokens.navigationBarHeight,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          indicatorColor: Colors.transparent,
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
    );
  }
}
