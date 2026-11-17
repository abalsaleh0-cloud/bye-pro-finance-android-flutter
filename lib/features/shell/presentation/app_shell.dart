import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/features/work/presentation/work_add_request_provider.dart';
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
        surfaceTintColor: Colors.transparent,
        title: Text(labels[_selectedIndex]),
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              key: const Key('open-work-add'),
              tooltip: strings.addEntry,
              icon: const Icon(Icons.add_rounded),
              onPressed: () =>
                  ref.read(workAddRequestProvider.notifier).request(),
            ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings?tab=$_selectedIndex'),
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
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: navigationShell.goBranch,
      ),
    );
  }
}
