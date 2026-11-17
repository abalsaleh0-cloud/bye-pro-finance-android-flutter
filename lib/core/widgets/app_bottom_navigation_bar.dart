import 'dart:ui' show ImageFilter;

import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Telegram-inspired floating glass navigation with five fixed destinations.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(26);

    final navigationTheme = NavigationBarThemeData(
      height: tokens.navigationBarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          size: selected ? 24 : 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontSize: 10,
          height: 1.1,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 8),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              key: const Key('floating-bottom-navigation'),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.92 : 0.86,
                ),
                borderRadius: radius,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.42),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.10,
                    ),
                    blurRadius: 22,
                    spreadRadius: 0,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Theme(
                data: theme.copyWith(navigationBarTheme: navigationTheme),
                child: NavigationBar(
                  height: tokens.navigationBarHeight,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  indicatorColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
      ),
    );
  }
}
